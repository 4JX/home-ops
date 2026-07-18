{
  coreutils,
  kubectl,
  kubernetes-helm,
  writeShellApplication,
  yq-go,
}:
let
  kubeconfig = "/etc/rancher/k3s/k3s.yaml";
  # Read bootstrap values from the manifests Flux will later reconcile.
  # Flux Instance chart docs: https://fluxoperator.dev/docs/charts/flux-instance/
  ciliumHelmRelease = ../kubernetes/apps/kube-system/cilium/app/helmrelease.yaml;
  ciliumOCIRepository = ../kubernetes/apps/kube-system/cilium/app/ocirepository.yaml;
  fluxInstanceHelmRelease = ../kubernetes/apps/flux-system/flux-instance/app/helmrelease.yaml;
in
writeShellApplication {
  name = "home-ops-bootstrap";
  runtimeInputs = [
    coreutils
    kubectl
    kubernetes-helm
    yq-go
  ];
  text = ''
    export KUBECONFIG=${kubeconfig}

    if [[ "$EUID" -ne 0 ]]; then
      echo "home-ops-bootstrap must be run as root" >&2
      exit 1
    fi

    # Wait for API readiness.
    until kubectl get --raw=/readyz >/dev/null 2>&1; do
      sleep 2
    done

    release_is_deployed() {
      helm status "$1" --namespace "$2" --output json 2>/dev/null \
        | yq --exit-status '.info.status == "deployed"' >/dev/null 2>&1
    }

    # Leave releases Flux already owns alone.
    if release_is_deployed cilium kube-system \
      && release_is_deployed flux-operator flux-system \
      && release_is_deployed flux-instance flux-system; then
      exit 0
    fi

    workdir="$(mktemp --directory)"
    trap 'rm -rf "$workdir"' EXIT

    yq '.spec.values' ${ciliumHelmRelease} > "$workdir/cilium-values.yaml"
    yq '.spec.values' ${fluxInstanceHelmRelease} > "$workdir/flux-instance-values.yaml"
    cilium_chart="$(yq --unwrapScalar '.spec.url' ${ciliumOCIRepository})"
    cilium_version="$(yq --unwrapScalar '.spec.ref.tag' ${ciliumOCIRepository})"
    flux_operator_artifact="$(yq --unwrapScalar '.spec.values.instance.distribution.artifact' ${fluxInstanceHelmRelease})"
    # The manifest bundle tag has a leading v; Helm expects the chart version.
    flux_operator_version="''${flux_operator_artifact##*:v}"

    # Flux cannot start until Cilium is ready.
    helm upgrade --install cilium "$cilium_chart" \
      --namespace kube-system \
      --version "$cilium_version" \
      --values "$workdir/cilium-values.yaml" \
      --wait \
      --timeout 10m

    kubectl wait node --all --for=condition=Ready --timeout=5m

    helm upgrade --install flux-operator \
      oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
      --namespace flux-system \
      --create-namespace \
      --version "$flux_operator_version" \
      --set web.networkPolicy.create=false \
      --wait \
      --timeout 5m

    kubectl wait \
      --for=condition=Established \
      crd/fluxinstances.fluxcd.controlplane.io \
      --timeout=2m

    # FluxInstance reconciles the controllers asynchronously.
    helm upgrade --install flux-instance \
      oci://ghcr.io/controlplaneio-fluxcd/charts/flux-instance \
      --namespace flux-system \
      --version "$flux_operator_version" \
      --values "$workdir/flux-instance-values.yaml" \
      --wait=false
  '';
}

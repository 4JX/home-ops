{
  coreutils,
  kubectl,
  kubernetes-helm,
  writeShellApplication,
  yq-go,
}:
let
  kubeconfig = "/etc/rancher/k3s/k3s.yaml";
  # Bootstrap reads the same declarative files that Flux will later reconcile,
  # avoiding a second, drifting set of Cilium and Flux values.
  ciliumHelmRelease = ../kubernetes/apps/kube-system/cilium/app/helmrelease.yaml;
  ciliumOCIRepository = ../kubernetes/apps/kube-system/cilium/app/ocirepository.yaml;
  # The FluxInstance HelmRelease is the source of truth after bootstrap. The
  # host reads its values once to break the initial networking/controller cycle.
  fluxInstanceHelmRelease = ../kubernetes/apps/flux-system/flux-instance/app/helmrelease.yaml;
in
writeShellApplication {
  name = "home-ops-bootstrap";
  # Pin every command used by the manual bootstrap command to the Nix store.
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

    # k3s may be active before its API discovery endpoint responds.
    until kubectl get --raw=/readyz >/dev/null 2>&1; do
      sleep 2
    done

    # A deployed status is a stronger idempotency check than the release Secret
    # merely existing after a failed or interrupted Helm operation.
    release_is_deployed() {
      helm status "$1" --namespace "$2" --output json 2>/dev/null \
        | yq --exit-status '.info.status == "deployed"' >/dev/null
    }

    # On ordinary boots Flux already owns these releases, so leave them alone.
    if release_is_deployed cilium kube-system \
      && release_is_deployed flux-operator flux-system \
      && release_is_deployed flux-instance flux-system; then
      exit 0
    fi

    workdir="$(mktemp --directory)"
    trap 'rm -rf "$workdir"' EXIT

    # Extract Cilium's chart reference and values from the Flux-owned manifests.
    yq '.spec.values' ${ciliumHelmRelease} > "$workdir/cilium-values.yaml"
    yq '.spec.values' ${fluxInstanceHelmRelease} > "$workdir/flux-instance-values.yaml"
    cilium_chart="$(yq --raw-output '.spec.url' ${ciliumOCIRepository})"
    cilium_version="$(yq --raw-output '.spec.ref.tag' ${ciliumOCIRepository})"
    flux_operator_artifact="$(yq --raw-output '.spec.values.instance.distribution.artifact' ${fluxInstanceHelmRelease})"
    # The Flux charts and manifest bundle use the same release, but the bundle
    # tag has a leading v. Derive the chart version so Renovate updates one
    # source of truth and bootstrap cannot drift from the FluxInstance.
    flux_operator_version="''${flux_operator_artifact##*:v}"

    # Networking blocks every other pod, so wait for the release to become ready.
    helm upgrade --install cilium "$cilium_chart" \
      --namespace kube-system \
      --version "$cilium_version" \
      --values "$workdir/cilium-values.yaml" \
      --wait \
      --timeout 10m

    # Flux controllers should not start until Cilium has made the node Ready.
    kubectl wait node --all --for=condition=Ready --timeout=5m

    # Network policy is intentionally deferred for the first-test cluster.
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

    # FluxInstance starts the controllers asynchronously. Avoid waiting in Helm
    # for resources that those newly-created controllers must reconcile.
    helm upgrade --install flux-instance \
      oci://ghcr.io/controlplaneio-fluxcd/charts/flux-instance \
      --namespace flux-system \
      --version "$flux_operator_version" \
      --values "$workdir/flux-instance-values.yaml" \
      --wait=false
  '';
}

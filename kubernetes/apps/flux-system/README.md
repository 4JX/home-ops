# Flux and Flux Operator

Flux is a set of Kubernetes controllers that continuously reconciles cluster
state from version-controlled sources. Rather than running a deployment command
for every change, an operator commits the desired state and Flux applies it,
reports its health, and corrects drift.

Flux Operator manages the lifecycle of those Flux controllers through a
`FluxInstance`. This project uses the operator so the controller installation
and Git synchronization settings can be expressed as one higher-level object.

## What runs in this cluster

The Flux Instance installs four controllers:

- **source-controller** fetches the Git repository and OCI Helm charts;
- **kustomize-controller** builds directories and applies Kubernetes objects;
- **helm-controller** turns `HelmRelease` objects into Helm installations;
- **notification-controller** records and routes reconciliation events.

The instance synchronizes the repository over unauthenticated HTTPS at branch
`main`, beginning at `./kubernetes/apps`, once per hour and immediately when it
observes a new source revision. This works only while the repository is public;
a private repository will require a Git credential secret.

## Why Flux is bootstrapped outside Flux

Flux cannot install the networking layer it needs in order to start its own
pods. The manually run host-side bootstrap command therefore installs Cilium
first and then installs the Flux Operator and Flux Instance charts. Unlike a
persistent k3s `HelmChart`, this bootstrap process exits; it does not compete
with Flux for ownership of the Cilium release.

The Flux Instance `HelmRelease` contains the values passed to the Flux Instance
chart. The Nix bootstrap reads that same manifest directly, so there is only one
copy of the Git URL, branch, path, controller list, and controller patches.

Once the controllers are running, Flux reconciles the Operator and Instance
HelmReleases from `apps/flux-system`. The host-side Helm install exists only to
break the initial cycle; the matching Flux resources adopt those releases and
own subsequent chart and values changes.

## Reconciliation model used by the apps tree

Each component contains:

- an `OCIRepository` describing where its Helm chart is found;
- a `HelmRelease` describing the desired chart installation;
- a Flux `Kustomization` in `ks.yaml` pointing at those files.

Dependencies in the `ks.yaml` files prevent higher layers from reconciling
before their prerequisites report Ready. `prune: true` means Flux also removes
objects that it previously applied when they disappear from Git.

Useful checks:

```sh
kubectl -n flux-system get fluxinstance
flux check
flux get sources all --all-namespaces
flux get kustomizations --all-namespaces
flux get helmreleases --all-namespaces
flux events --all-namespaces --for Kustomization/podinfo
```

## Documentation

- [Flux documentation](https://fluxcd.io/flux/)
- [Flux Kustomization reference](https://fluxcd.io/flux/components/kustomize/kustomizations/)
- [Flux HelmRelease guide](https://fluxcd.io/flux/components/helm/helmreleases/)
- [Flux Operator project](https://github.com/controlplaneio-fluxcd/flux-operator)
- [Flux Operator documentation](https://fluxcd.control-plane.io/operator/)

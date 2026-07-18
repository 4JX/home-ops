# Flux and Flux Operator

Flux Operator installs the Flux controllers. The Flux Instance then syncs the
public `main` branch from `./kubernetes/apps`; the host bootstrap installs the
initial Cilium, Operator, and Instance releases before Flux can reconcile them.

## Documentation

- [Flux documentation](https://fluxcd.io/flux/)
- [Flux Kustomization reference](https://fluxcd.io/flux/components/kustomize/kustomizations/)
- [Flux HelmRelease guide](https://fluxcd.io/flux/components/helm/helmreleases/)
- [Flux Operator project](https://github.com/controlplaneio-fluxcd/flux-operator)
- [Flux Operator documentation](https://fluxcd.control-plane.io/operator/)

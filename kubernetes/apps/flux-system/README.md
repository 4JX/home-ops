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

## SOPS age decryption

Flux is configured to use the `sops-age` Secret in `flux-system` as its global
age decryption key. The Secret is intentionally not stored in Git. Bootstrap it
from a runtime-only age private key file:

```sh
sudo home-ops-bootstrap --sops-age-key-file /path/to/home-ops.agekey
```

Use two age recipients for encrypted files:

- your personal age public key, so you can edit secrets locally;
- a dedicated cluster age public key, whose private key is supplied only to
  bootstrap and stored in the cluster Secret.

Generate the dedicated identity outside the repository, then copy only its
public recipient into `.sops.yaml`:

```sh
age-keygen -o /secure/path/home-ops.agekey
age-keygen -y /secure/path/home-ops.agekey
```

The repository-level `.sops.yaml` contains the encryption policy skeleton. Keep
private keys outside the repository and replace its cluster-recipient placeholder
before encrypting any Kubernetes Secret.

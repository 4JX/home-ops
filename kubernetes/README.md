# Kubernetes learning tour

This directory contains the smallest useful version of the cluster. It is meant
to be read in the same order that the cluster starts:

1. [NixOS and k3s](../nix/README.md) create the Kubernetes host; you then run
   the one-shot bootstrap command manually.
2. [Cilium](apps/kube-system/cilium/README.md) provides pod networking, replaces
   kube-proxy, allocates a LoadBalancer address, and announces it on the LAN.
3. [Flux](apps/flux-system/README.md) starts reconciling this Git
   repository into the cluster.
4. [Envoy Gateway](apps/network/envoy-gateway/README.md) implements Gateway API
   and creates the HTTP entry point.
5. [Podinfo](apps/test/podinfo/README.md) provides a small workload used to test
   the entire path.
6. [Storage smoke](apps/test/storage-smoke/README.md) demonstrates dynamic
   provisioning and node-local persistence independently of the request path.
7. [Media storage](apps/media/storage/README.md) exposes the existing HDD tree
   as one retained local volume for hardlink-capable workloads.

## How the repository is reconciled

The Flux instance points at `./kubernetes/apps`. Its top-level
`kustomization.yaml` creates four namespaces and eight Flux `Kustomization`
objects. The application objects form this dependency chain:

```text
media-storage

cilium
  ├─ local-path-provisioner
  │  └─ storage-smoke
  └─ cilium-config
       └─ envoy-gateway
            └─ envoy-gateway-gateway
                 └─ podinfo
```

The repeated use of the word “Kustomization” can be confusing:

- A `kustomization.yaml` file is consumed by the Kustomize build tool. It lists
  YAML resources that belong together.
- A Flux `Kustomization` is a Kubernetes object reconciled by Flux. It points to
  a directory, builds its `kustomization.yaml`, applies the result, and corrects
  later drift.

The `ks.yaml` files contain the second kind. The `kustomization.yaml` files
contain the first.

## End-to-end request path

After reconciliation, an HTTP request follows this path:

```text
client on 192.168.1.0/24
  → 192.168.1.120 (Cilium LoadBalancer VIP)
  → Envoy Service and proxy
  → Podinfo HTTPRoute
  → Podinfo Service
  → Podinfo pod on port 9898
```

Reserve `192.168.1.120` outside DHCP and make sure no other device uses it. The
router currently gives out addresses from `.128` through `.254`, so `.120` is
outside the dynamic range but still needs to be checked for a manual assignment.

## First verification

Inspect reconciliation from the bottom up:

```sh
flux get kustomizations --all-namespaces
kubectl get pods --all-namespaces
kubectl -n network get gateway envoy
kubectl -n test get httproute,service,pod
kubectl -n test get pvc
kubectl get pv media
kubectl -n media get pvc media
curl http://192.168.1.120
```

No DNS, TLS, secret management, certificate controller, or external exposure is
involved yet. A successful `curl` proves that the selected core technologies
work together. The separate [storage smoke test](apps/test/storage-smoke/README.md)
exercises Flux-managed local-path storage without changing Podinfo's known-good
request path. The static media volume represents the existing HDD filesystem
without letting the dynamic provisioner reorganize it.

## General references

- [Kubernetes documentation](https://kubernetes.io/docs/)
- [Flux documentation](https://fluxcd.io/flux/)
- [Kustomize documentation](https://kubectl.docs.kubernetes.io/references/kustomize/)
- [Gateway API overview](https://gateway-api.sigs.k8s.io/docs/concepts/api-overview/)

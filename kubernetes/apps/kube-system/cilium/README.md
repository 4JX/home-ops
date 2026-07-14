# Cilium

Cilium is a Kubernetes networking, security, and observability platform built
around eBPF. As a Container Network Interface (CNI), it creates pod interfaces
and makes pods reachable. It can also enforce network policies, replace
kube-proxy's Service implementation, provide load-balancer address management,
and expose flow visibility through Hubble.

This cluster currently uses only the networking and load-balancing portions.
There are no Cilium network policies, Hubble deployment, service mesh, BGP, or
multi-cluster features.

## Current configuration

The Helm release installs Cilium `1.19.5` with:

- Kubernetes host-scope IPAM and pod network `10.42.0.0/16`;
- native routing rather than an overlay tunnel;
- automatic direct node routes;
- full eBPF kube-proxy replacement;
- the local k3s API endpoint at `127.0.0.1:6443`;
- socket-level load balancing limited to the host namespace, leaving pod
  namespaces on Cilium's per-packet load-balancing path;
- L2 announcements enabled;
- one operator replica for the single-node cluster;
- Hubble and Cilium's embedded Envoy integration disabled.

NixOS disables Flannel and kube-proxy before Cilium starts. Cilium is initially
installed by the host bootstrap, then its existing Helm release is reconciled by
Flux from `app/helmrelease.yaml`.

## Files

```text
cilium/
├── app/
│   ├── ocirepository.yaml   # chart registry and version
│   ├── helmrelease.yaml     # Cilium Helm values
│   └── kustomization.yaml
├── config/
│   ├── lb-pool.yaml         # address Cilium may allocate
│   ├── l2-announcement-policy.yaml
│   └── kustomization.yaml
└── ks.yaml                  # Flux ordering and reconciliation
```

LB IPAM assigns `192.168.1.120` to the Envoy `LoadBalancer` Service. The L2
announcement policy makes one Cilium node answer ARP requests for that virtual
address. LAN clients therefore send packets to the elected node without the
router needing a static route.

The address must remain unused and outside DHCP. It is a LAN-facing virtual IP,
not a pod address and not a Kubernetes ClusterIP.

## What to inspect

```sh
kubectl -n kube-system get pods -l k8s-app=cilium
kubectl -n kube-system exec ds/cilium -- cilium-dbg status
kubectl get ciliumloadbalancerippool
kubectl get ciliuml2announcementpolicy
kubectl -n kube-system get lease | grep cilium-l2announce
kubectl -n network get service
```

If `192.168.1.120` is allocated but unreachable, first check that the node's LAN
interface was auto-detected by Cilium and use `arping 192.168.1.120` from another
LAN machine. L2 announcements require kube-proxy replacement, which is why those
two settings are paired.

## Documentation

- [Cilium documentation](https://docs.cilium.io/en/stable/)
- [Kubernetes without kube-proxy](https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/)
- [Native routing concepts](https://docs.cilium.io/en/stable/network/concepts/routing/)
- [LoadBalancer IP Address Management](https://docs.cilium.io/en/stable/network/lb-ipam/)
- [L2 announcements](https://docs.cilium.io/en/stable/network/l2-announcements/)

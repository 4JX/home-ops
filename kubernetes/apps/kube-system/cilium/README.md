# Cilium

Cilium provides pod networking, kube-proxy replacement, and LAN LoadBalancer
IP announcements. The current single-node configuration uses native routing,
the `10.42.0.0/16` pod CIDR, and `192.168.1.120` for the Envoy Gateway service.

## Documentation

- [Cilium documentation](https://docs.cilium.io/en/stable/)
- [Kubernetes without kube-proxy](https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/)
- [Native routing concepts](https://docs.cilium.io/en/stable/network/concepts/routing/)
- [LoadBalancer IP Address Management](https://docs.cilium.io/en/stable/network/lb-ipam/)
- [L2 announcements](https://docs.cilium.io/en/stable/network/l2-announcements/)

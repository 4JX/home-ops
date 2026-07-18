# NixOS and k3s

This module configures the single-node k3s host, its firewall and storage
mount requirements, and the one-shot bootstrap command that installs Cilium
and Flux. Enable it with `local.home-ops.enable = true;` and grant kubeconfig
access only to trusted local users.

## Documentation

- [k3s documentation](https://docs.k3s.io/)
- [k3s custom CNI configuration](https://docs.k3s.io/networking/basic-network-options#custom-cni)
- [k3s packaged components](https://docs.k3s.io/installation/packaged-components)
- [k3s server options](https://docs.k3s.io/cli/server)
- [NixOS k3s options](https://search.nixos.org/options?channel=unstable&query=services.k3s)

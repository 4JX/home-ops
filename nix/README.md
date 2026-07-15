# NixOS and k3s

NixOS describes the host operating system declaratively. k3s is a compact
Kubernetes distribution that packages the API server, controller manager,
scheduler, container runtime, kubelet, and several useful cluster services into
a straightforward installation.

In this project, NixOS owns everything that must exist before in-cluster GitOps
can work:

- starting the k3s server;
- choosing which bundled k3s components are disabled;
- configuring the host firewall and reverse-path filtering;
- running the initial Cilium and Flux bootstrap from the host.

The module is opt-in. Set `local.home-ops.enable = true;` in a host
configuration to enable the k3s service, host tools, firewall rules, and
bootstrap command.

After bootstrap, Flux owns the Kubernetes resources. NixOS does not continuously
manage the Cilium Helm release.

## Files

- `default.nix` is the public module entry point exported as
  `nixosModules.home-ops` by the flake.
- `k3s.nix` configures k3s, networking, and installs the bootstrap command.
- `bootstrap.nix` builds the manually run `home-ops-bootstrap` command with its
  exact Helm, kubectl, and yq dependencies.

## k3s choices

The module runs a single server that also schedules workloads. It enables
secrets encryption and graceful node shutdown, and disables:

- Flannel, because Cilium is the CNI;
- kube-proxy, because Cilium performs eBPF service load balancing;
- the bundled network-policy controller, because Cilium has its own policy
  engine if policies are introduced later;
- Traefik, because Envoy Gateway is the selected ingress implementation;
- ServiceLB, because Cilium LB IPAM and L2 announcements provide LoadBalancer
  addresses.

k3s still provides CoreDNS, metrics-server, and local-path-provisioner. Podinfo
does not require persistent storage, so local-path-provisioner is not exercised
by the first test.

## Bootstrap boundary

Run `sudo home-ops-bootstrap` after k3s is running. The command waits until the
Kubernetes API reports ready, then:

1. reads the Cilium chart URL, version, and `spec.values` from the eventual Flux
   manifests;
2. installs Cilium with host-side Helm;
3. waits for the node to become Ready;
4. installs Flux Operator and the Flux Instance chart.

This resolves the bootstrap cycle: Flux pods need Cilium networking, but Flux is
the eventual owner of Cilium. The bootstrap command is idempotent and exits
without running Helm when all three releases are already deployed.

## Host networking

The API server listens on TCP port `6443`. Reverse-path filtering remains
enabled globally, with exceptions for Cilium host and pod interfaces. On the
final host, the API firewall opening should be restricted to its management/LAN
interface.

Useful host checks:

```sh
systemctl status k3s
sudo home-ops-bootstrap
sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get nodes
```

## Documentation

- [k3s documentation](https://docs.k3s.io/)
- [k3s custom CNI configuration](https://docs.k3s.io/networking/basic-network-options#custom-cni)
- [k3s packaged components](https://docs.k3s.io/installation/packaged-components)
- [k3s server options](https://docs.k3s.io/cli/server)
- [NixOS k3s options](https://search.nixos.org/options?channel=unstable&query=services.k3s)

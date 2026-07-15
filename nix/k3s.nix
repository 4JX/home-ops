{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.local.home-ops;
  ciliumHelmRelease = ../kubernetes/apps/kube-system/cilium/app/helmrelease.yaml;
  # Nix does not evaluate YAML natively. The Cilium value is deliberately a
  # simple scalar, so extract that one line at evaluation time and fail loudly
  # if the manifest ever contains zero or multiple definitions.
  podCIDR =
    let
      lines = pkgs.lib.splitString "\n" (builtins.readFile ciliumHelmRelease);
      candidates = builtins.filter (
        line:
        builtins.match "^[[:space:]]*ipv4NativeRoutingCIDR:[[:space:]]*[^[:space:]#]+[[:space:]]*$" line
        != null
      ) lines;
    in
    if builtins.length candidates != 1 then
      throw "home-ops: expected exactly one ipv4NativeRoutingCIDR in ${toString ciliumHelmRelease}"
    else
      builtins.elemAt (builtins.match "^[[:space:]]*ipv4NativeRoutingCIDR:[[:space:]]*([^[:space:]#]+)[[:space:]]*$" (builtins.head candidates)) 0;
  # K3s writes the administrator kubeconfig here once its API server is ready.
  kubeconfig = "/etc/rancher/k3s/k3s.yaml";
  bootstrap = pkgs.callPackage ./bootstrap.nix { };
in
{
  options.local.home-ops = {
    enable = lib.mkEnableOption "home-ops k3s integration";

    kubeconfigUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users granted read access to the k3s admin kubeconfig.";
    };

    kubeconfigGroup = lib.mkOption {
      type = lib.types.str;
      default = "k3s";
      description = "Group granted read access to the k3s admin kubeconfig.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The k3s admin kubeconfig grants cluster-admin access; only list trusted
    # local users here. Keep the file root-owned while granting this group read
    # access so k3s can continue to refresh the file in place. The members
    # option only adds the names to /etc/group; it does not declare user accounts.
    users.groups = {
      "${cfg.kubeconfigGroup}".members = cfg.kubeconfigUsers;
    };

    services.k3s = {
      enable = true;
      # A server runs the control plane and, in this single-node setup, workloads.
      role = "server";

      # Give Kubernetes time to terminate pods cleanly during host shutdown.
      gracefulNodeShutdown.enable = true;

      # Cilium provides LoadBalancer IPs and Envoy Gateway replaces Traefik.
      disable = [
        "servicelb"
        "traefik"
      ];

      extraFlags = [
        # Use the same pod network that Cilium reads above for Kubernetes Node
        # PodCIDRs and for the native-routing firewall exception.
        "--cluster-cidr=${podCIDR}"
        # Encrypt Kubernetes Secret data before it reaches the local datastore.
        "--secrets-encryption"
        # Cilium is the CNI, so neither Flannel nor K3s' policy controller is used.
        "--flannel-backend=none"
        "--disable-network-policy"
        # Cilium's eBPF service handling replaces kube-proxy.
        "--disable-kube-proxy"
        # This file contains cluster-admin credentials; keep it root-readable.
        "--write-kubeconfig-mode=0640"
        "--write-kubeconfig-group=${cfg.kubeconfigGroup}"
      ];
    };

    # Make kubectl and Helm use the local K3s cluster by default on this host.
    environment.variables.KUBECONFIG = kubeconfig;

    environment.systemPackages = with pkgs; [
      # K3s administrative binary, useful for inspecting the local service.
      k3s
      # Core Kubernetes API client and Helm chart client.
      kubectl
      kubernetes-helm
      # Cilium and Flux-specific diagnostics and reconciliation commands.
      cilium-cli
      fluxcd
      # Manually run this once k3s is ready to install Cilium and Flux.
      bootstrap
      # Lightweight interactive inspection and structured-output helpers.
      k9s
      jq
      yq-go
    ];

    networking = {
      # The reverse-path exceptions below are expressed as native nftables rules.
      nftables.enable = true;
      firewall = {
        # Retain strict reverse-path filtering, but exempt Cilium-owned traffic.
        checkReversePath = true;
        logReversePathDrops = true;

        # Scope this to the management/LAN interface on the final host.
        allowedTCPPorts = [ 6443 ];

        extraReversePathFilterRules = ''
          # Cilium host devices carry traffic whose return route may differ from
          # the interface on which it arrived, which strict RPF would reject.
          iifname { "cilium_host", "cilium_net" } accept
          # Endpoint veth names start with lxc; constrain this exception to pods.
          iifname "lxc*" ip saddr ${podCIDR} accept
        '';
      };
    };

    warnings = [
      ''
        home-ops: TCP/6443 is currently open on every host interface; restrict it
        to the management interface when the final machine's interface is known.
      ''
    ];
  };
}

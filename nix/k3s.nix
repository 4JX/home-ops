{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.local.home-ops;
  ciliumHelmRelease = ../kubernetes/apps/kube-system/cilium/app/helmrelease.yaml;
  # Keep K3s' cluster CIDR in sync with Cilium's Helm values.
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
    # This kubeconfig grants cluster-admin access; list trusted users only.
    users.groups = {
      "${cfg.kubeconfigGroup}".members = cfg.kubeconfigUsers;
    };

    services.k3s = {
      # NixOS k3s options: https://search.nixos.org/options?channel=unstable&query=services.k3s
      enable = true;
      role = "server";

      gracefulNodeShutdown.enable = true;

      # Cilium, Envoy Gateway, and Flux-managed storage replace these addons.
      disable = [
        "local-storage"
        "servicelb"
        "traefik"
      ];

      extraFlags = [
        # Cilium supplies the CNI and uses the same pod CIDR for native routing.
        # https://docs.k3s.io/networking/basic-network-options#custom-cni
        "--cluster-cidr=${podCIDR}"
        # Keep Kubernetes Secret data encrypted in the local datastore.
        "--secrets-encryption"
        # Disable k3s networking and policy components replaced by Cilium.
        "--flannel-backend=none"
        "--disable-network-policy"
        # Cilium provides kube-proxy replacement with eBPF service handling.
        # https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/
        "--disable-kube-proxy"
        # Keep the admin kubeconfig root-owned while sharing group read access.
        "--write-kubeconfig-mode=0640"
        "--write-kubeconfig-group=${cfg.kubeconfigGroup}"
      ];
    };

    # Do not start k3s unless both backing filesystems are mounted.
    systemd.services.k3s.unitConfig.RequiresMountsFor = [
      "/containers/config"
      "/containers/mediaserver"
    ];

    # Dynamic config PVCs are allocated below this NVMe-backed path.
    systemd.tmpfiles.rules = [
      "d /containers/config/kubernetes 0755 root root -"
    ];

    environment.variables.KUBECONFIG = kubeconfig;

    environment.systemPackages = with pkgs; [
      k3s
      kubectl
      kubernetes-helm
      cilium-cli
      fluxcd
      bootstrap
      k9s
      jq
      yq-go
    ];

    # Native Cilium routing needs exceptions to strict reverse-path filtering.
    networking = {
      nftables.enable = true;
      firewall = {
        checkReversePath = true;
        logReversePathDrops = true;

        allowedTCPPorts = [ 6443 ];

        extraReversePathFilterRules = ''
          # Cilium host devices can receive traffic whose return route differs.
          iifname { "cilium_host", "cilium_net" } accept
          # Limit the pod exception to Cilium endpoint veths and the pod CIDR.
          iifname "lxc*" ip saddr ${podCIDR} accept
        '';

        extraInputRules = ''
          # Metrics Server runs in a pod and scrapes the kubelet.
          ip saddr ${podCIDR} tcp dport 10250 \
            accept comment "Pods to kubelet for metrics"
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

{
  description = "Home server";

  outputs =
    inputs@{
      parts,
      ...
    }:
    parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./fmt.nix
      ];

      systems = [ "x86_64-linux" ];

      flake = {
        nixosModules = {
          # Minimal host-side K3s and bootstrap module for the new cluster.
          home-ops = ./nix;
        };
      };
    };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    parts.url = "github:hercules-ci/flake-parts";

    # Project wide formatting
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };
}

# Project-wide formatting configuration for flake-parts.
{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    { ... }:
    {
      treefmt = {
        projectRootFile = "flake.nix";
        programs = {
          # https://github.com/numtide/treefmt-nix/blob/main/programs/nixfmt.nix
          nixfmt = {
            enable = true;
          };
          # https://github.com/numtide/treefmt-nix/blob/main/programs/deadnix.nix
          deadnix = {
            enable = true;
          };
          # https://github.com/numtide/treefmt-nix/blob/main/programs/statix.nix
          statix = {
            enable = true;
            disabled-lints = [
              "empty_pattern"
            ];
          };
          # https://github.com/numtide/treefmt-nix/blob/main/programs/yamlfmt.nix
          yamlfmt = {
            enable = true;
            settings = {
              formatter = {
                type = "basic";
                retain_line_breaks = true;
              };
            };
          };
        };
        settings = {
          global.excludes = [
            ".editorconfig"
            "LICENSE"
            "secrets/*"
          ];
        };
      };
    };
}

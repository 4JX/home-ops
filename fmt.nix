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
          # rfc-style
          # https://github.com/numtide/treefmt-nix/blob/main/programs/nixfmt.nix
          nixfmt = {
            enable = true;
            # strict = false;
            # width = 100;
          };
          # https://github.com/numtide/treefmt-nix/blob/main/programs/deadnix.nix
          deadnix = {
            enable = true;
            # Don't check lambda parameter arguments
            # no-lambda-arg = false;
            # Don't check lambda attrset pattern names (don't break nixpkgs callPackage)
            # no-lambda-pattern-names = false;
            # Don't check any bindings that start with a _
            # no-underscore = false;
          };
          # https://github.com/numtide/treefmt-nix/blob/main/programs/statix.nix
          statix = {
            enable = true;
            # List of ignored lints. Run `statix list` to see all available lints.
            disabled-lints = [
              # This changes { ... } to _, which is not wanted
              # deadnix handles this correctly
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
          # on-unmatched = "warn";
          # on-unmatched = "fatal";
          global.excludes = [
            ".editorconfig"
            "LICENSE"
            "secrets/*"
          ];
        };
      };
    };
}

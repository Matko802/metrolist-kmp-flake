{
  description = "Metrolist KMP nightly desktop music player from the upstream AppImage";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        metrolist-kmp-flake = pkgs.callPackage ./package.nix { };
        default = metrolist-kmp-flake;
      });

      apps = forAllSystems (pkgs: {
        update = {
          type = "app";
          program = "${pkgs.writeShellApplication {
            name = "metrolist-update";
            runtimeInputs = with pkgs; [
              bash
              coreutils
              curl
              nix
              python3
            ];
            text = ''
              exec ${./scripts/update.sh} "$@"
            '';
          }}/bin/metrolist-update";
        };
      });

      overlays.default = final: _prev: {
        metrolist-kmp-flake = final.callPackage ./package.nix { };
      };
    };
}

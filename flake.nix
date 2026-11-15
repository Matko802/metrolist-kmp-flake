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

      overlays.default = final: _prev: {
        metrolist-kmp-flake = final.callPackage ./package.nix { };
      };
    };
}

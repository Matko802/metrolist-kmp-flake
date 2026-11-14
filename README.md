# metrolist-kmp-flake

Metrolist desktop — a YouTube Music client built with Compose Multiplatform —
packaged from the upstream Linux AppImage.

- Source: `metrolist-desktop-linux-x64-<version>.AppImage` downloaded with
  `fetchurl` from the upstream GitHub release, pinned by URL and hash in
  `sources.nix`
- Binary: `metrolist-kmp-flake` (with `.desktop` launcher and the Metrolist icon)
- Extra runtime libraries: WebKitGTK 4.1 (`libwebkit2gtk-4.1.so.0`) for the
  embedded login / Last.fm web views, plus GLib-Networking wired into
  `GIO_EXTRA_MODULES` so GIO/WebKit has a TLS backend
  (fixes "TLS support is not available")
- System font: Compose Desktop resolves its "System" font option through the
  hardcoded aliases `Noto Sans`, `DejaVu Sans`, and `Arial`. The wrapper points
  `FONTCONFIG_FILE` at a generated config that remaps those names to the font
  passed as `systemFont` (default `sans-serif`)
- Wayland scale: the app auto-detects GNOME, KDE, Hyprland, Sway, and
  `wlr-randr` outputs, but niri does not expose `wlr-randr`. Pass
  `waylandScale = "1.2"` to set `METROLIST_FORCE_SCALE` so the UI matches the
  compositor's output scale from the first frame
- Platform: `x86_64-linux`

## Try it

```bash
nix run .
```

## Use in your NixOS flake

```nix
# flake.nix inputs
metrolist-kmp-flake = {
  url = "github:Matko802/metrolist-kmp-flake";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

```nix
# overlay
nixpkgs.overlays = [ inputs.metrolist-kmp-flake.overlays.default ];
```

```nix
users.users."you".packages = with pkgs; [
  (metrolist-kmp-flake.override {
    systemFont = "DepartureMono Nerd Font";
    waylandScale = "1.2";
  })
];
```

## Update

`sources.nix` is the only file that needs to change between releases.

Automatically: the `Update Metrolist` GitHub Actions workflow runs every day
and on manual dispatch. It reads the latest upstream release, prefetches the
x64 AppImage to compute the hash, rewrites `sources.nix`, commits, and tags the
release.

Manually:

```bash
./scripts/update.sh          # latest upstream release
./scripts/update.sh --force  # re-pin the current version
```

Then refresh consumers that lock this flake:

```bash
nix flake update metrolist-kmp-flake
```

Note that scheduled workflows are disabled by GitHub after 60 days without
repository activity; re-enable them from the Actions tab if that happens.

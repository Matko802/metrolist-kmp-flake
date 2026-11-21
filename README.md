# metrolist-kmp-flake

Metrolist desktop — a YouTube Music client built with Compose Multiplatform —
packaged from the upstream nightly Linux AppImage.

- Source: `Metrolist-Desktop-linux-x64.AppImage` downloaded with `fetchurl`
  from the upstream [`nightly` release](https://github.com/MetrolistGroup/Metrolist/releases/tag/nightly),
  pinned by URL and hash in `sources.nix`. The `nightly` release is a rolling
  tag, so `version` is `nightly-<release date>` (for example
  `nightly-2026-11-15`) and the hash changes with every upstream build
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

## Known issues

- **Floating search is broken upstream** ([#4699](https://github.com/MetrolistGroup/Metrolist/issues/4699),
  [#4739](https://github.com/MetrolistGroup/Metrolist/issues/4739)): with
  Appearance → *Floating search* enabled, clicking the search bar or pressing
  `Ctrl+K` opens an overlay that never receives keyboard focus, so search
  appears dead until `Escape` is pressed. Keep the setting off (the default) to
  use the inline search bar; the fix is pending in
  [PR #4762](https://github.com/MetrolistGroup/Metrolist/pull/4762) and will be
  picked up automatically once it lands in a nightly build.

## Update

`sources.nix` is the only file that needs to change between releases.

Automatically: the `Update Metrolist` GitHub Actions workflow runs every hour
and on manual dispatch. It reads the current `nightly` release from the GitHub
API, takes the asset's published SHA-256 digest (no 140 MB download), rewrites
`sources.nix`, builds the package to verify the hash, then commits and
force-updates the rolling `nightly` tag.

Manually:

```bash
nix run .#update              # re-pin the current nightly AppImage
nix run .#update -- --check   # exit 1 when sources.nix is stale
```

The `nightly` release is a rolling tag: its asset is replaced every day, so a
pinned hash goes stale. A pure Nix evaluation cannot fetch without a hash, so
the hash has to be refreshed out-of-band. Consumers should refresh their lock
regularly, for example from a systemd timer:

```bash
nix flake update metrolist-kmp-flake --flake /path/to/nixos
```

Note that scheduled workflows are disabled by GitHub after 60 days without
repository activity; re-enable them from the Actions tab if that happens.

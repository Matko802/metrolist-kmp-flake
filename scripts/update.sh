#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

repo="MetrolistGroup/Metrolist"
force=0

for arg in "$@"; do
  case "$arg" in
    -f|--force) force=1 ;;
    *)
      echo "usage: $0 [--force]" >&2
      exit 2
      ;;
  esac
done

tag="${METROLIST_TAG:-$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
  | python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"])')}"

version="${tag#v}"
url="https://github.com/${repo}/releases/download/${tag}/metrolist-desktop-linux-x64-${version}.AppImage"
current="$(sed -n 's/^  version = "\(.*\)";$/\1/p' sources.nix)"

if [ "${version}" = "${current}" ] && [ "${force}" -eq 0 ]; then
  echo "sources.nix is already at ${version}"
  exit 0
fi

echo "fetching ${url}"
hash="$(nix store prefetch-file --json --name "metrolist-desktop-linux-x64-${version}.AppImage" "${url}" \
  | python3 -c 'import json, sys; print(json.load(sys.stdin)["hash"])')"

cat > sources.nix <<EOF
{
  version = "${version}";
  url = "${url}";
  hash = "${hash}";
}
EOF

echo "updated sources.nix to ${version}"

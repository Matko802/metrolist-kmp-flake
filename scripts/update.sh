#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

repo="MetrolistGroup/Metrolist"
asset="Metrolist-Desktop-linux-x64.AppImage"
url="https://github.com/${repo}/releases/download/nightly/${asset}"

if [ "$#" -gt 0 ]; then
  echo "usage: $0" >&2
  exit 2
fi

release="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/tags/nightly")"
published="$(python3 -c 'import json, sys; print(json.load(sys.stdin)["published_at"][:10])' <<<"${release}")"
version="nightly-${published}"

current_version="$(sed -n 's/^  version = "\(.*\)";$/\1/p' sources.nix)"
current_hash="$(sed -n 's/^  hash = "\(.*\)";$/\1/p' sources.nix)"

echo "fetching ${url}"
hash="$(nix store prefetch-file --json --name "${asset}" "${url}" \
  | python3 -c 'import json, sys; print(json.load(sys.stdin)["hash"])')"

if [ "${version}" = "${current_version}" ] && [ "${hash}" = "${current_hash}" ]; then
  echo "sources.nix is already at ${version} (${hash})"
  exit 0
fi

cat > sources.nix <<EOF
{
  version = "${version}";
  url = "${url}";
  hash = "${hash}";
}
EOF

echo "updated sources.nix to ${version}"

#!/usr/bin/env bash
set -euo pipefail

repo="MetrolistGroup/Metrolist"
asset="Metrolist-Desktop-linux-x64.AppImage"
url="https://github.com/${repo}/releases/download/nightly/${asset}"

usage() {
  echo "usage: $0 [--check] [--repo-root DIR]" >&2
  exit 2
}

check=0
root="${METROLIST_REPO_ROOT:-$PWD}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) check=1; shift ;;
    --repo-root)
      [ "$#" -ge 2 ] || usage
      root="$2"
      shift 2
      ;;
    *) usage ;;
  esac
done

[ -f "${root}/sources.nix" ] || {
  echo "no sources.nix in ${root}; run from the repo or pass --repo-root" >&2
  exit 1
}

cd "${root}"

release="$(curl -fsSL -H 'Accept: application/vnd.github+json' \
  "https://api.github.com/repos/${repo}/releases/tags/nightly")"

read -r published digest <<<"$(
  python3 -c '
import json, sys
release = json.load(sys.stdin)
asset = next(a for a in release["assets"] if a["name"] == sys.argv[1])
print(release["published_at"][:10], asset.get("digest") or "")
' "${asset}" <<<"${release}"
)"

version="nightly-${published}"

if [ -n "${digest}" ]; then
  hash="${digest}"
else
  echo "release has no digest, prefetching ${url}" >&2
  hash="$(nix store prefetch-file --json --name "${asset}" "${url}" \
    | python3 -c 'import json, sys; print(json.load(sys.stdin)["hash"])')"
fi

current_version="$(sed -n 's/^  version = "\(.*\)";$/\1/p' sources.nix)"
current_hash="$(sed -n 's/^  hash = "\(.*\)";$/\1/p' sources.nix)"

if [ "${version}" = "${current_version}" ] && [ "${hash}" = "${current_hash}" ]; then
  echo "sources.nix is already at ${version} (${hash})"
  exit 0
fi

if [ "${check}" -eq 1 ]; then
  echo "sources.nix is stale: ${current_version} (${current_hash}) -> ${version} (${hash})" >&2
  exit 1
fi

cat > sources.nix <<EOF
{
  version = "${version}";
  url = "${url}";
  hash = "${hash}";
}
EOF

echo "updated sources.nix to ${version} (${hash})"

#!/usr/bin/env bash
set -euo pipefail

upstream_repo="MetrolistGroup/Metrolist"
asset="Metrolist-Desktop-linux-x64.AppImage"
download_url="https://github.com/${upstream_repo}/releases/download/nightly/${asset}"

mirror_repo="${MIRROR_REPO:-${GITHUB_REPOSITORY:-Matko802/metrolist-kmp-flake}}"
mirror_tag="${MIRROR_TAG:-mirror}"
token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"

usage() {
  echo "usage: $0 [--check] [--no-mirror] [--repo-root DIR]" >&2
  exit 2
}

check=0
mirror=1
root="${METROLIST_REPO_ROOT:-$PWD}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) check=1; shift ;;
    --no-mirror) mirror=0; shift ;;
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
  "https://api.github.com/repos/${upstream_repo}/releases/tags/nightly")"

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
  echo "release has no digest, prefetching ${download_url}" >&2
  hash="$(nix store prefetch-file --json --name "${asset}" "${download_url}" \
    | python3 -c 'import json, sys; print(json.load(sys.stdin)["hash"])')"
fi

case "${hash}" in
  sha256:*) hex="${hash#sha256:}" ;;
  sha256-*)
    hex="$(python3 -c 'import base64, sys; print(base64.b64decode(sys.argv[1].split("-", 1)[1]).hex())' "${hash}")"
    ;;
  *)
    echo "unsupported hash format: ${hash}" >&2
    exit 1
    ;;
esac
hash="sha256:${hex}"

url="${download_url}"
mirror_name=""

if [ "${mirror}" -eq 1 ] && [ -n "${token}" ]; then
  mirror_name="Metrolist-Desktop-linux-x64-${version}-${hex:0:12}.AppImage"
  url="https://github.com/${mirror_repo}/releases/download/${mirror_tag}/${mirror_name}"
fi

current_version="$(sed -n 's/^  version = "\(.*\)";$/\1/p' sources.nix)"
current_url="$(sed -n 's/^  url = "\(.*\)";$/\1/p' sources.nix)"
current_hash="$(sed -n 's/^  hash = "\(.*\)";$/\1/p' sources.nix)"

if [ "${version}" = "${current_version}" ] && [ "${url}" = "${current_url}" ] && [ "${hash}" = "${current_hash}" ]; then
  echo "sources.nix is already at ${version} (${hash})"
  exit 0
fi

if [ "${check}" -eq 1 ]; then
  echo "sources.nix is stale: ${current_version} (${current_hash}) -> ${version} (${hash})" >&2
  exit 1
fi

release_id=""
asset_digest=""

fetch_mirror_release() {
  release_id=""
  asset_digest=""
  local response
  if response="$(curl -fsSL \
    -H "Authorization: Bearer ${token}" \
    -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/repos/${mirror_repo}/releases/tags/${mirror_tag}" 2>/dev/null)"; then
    read -r release_id asset_digest <<<"$(
      python3 -c '
import json, sys
release = json.load(sys.stdin)
asset = next((a for a in release.get("assets", []) if a.get("name") == sys.argv[1]), None)
print(release.get("id", ""), (asset or {}).get("digest") or "")
' "${mirror_name}" <<<"${response}"
    )"
  fi
}

if [ -n "${mirror_name}" ]; then
  fetch_mirror_release

  if [ -n "${asset_digest}" ] && [ "${asset_digest}" != "${hash}" ]; then
    echo "mirror asset ${mirror_name} exists with digest ${asset_digest}, expected ${hash}" >&2
    exit 1
  fi

  if [ -z "${asset_digest}" ]; then
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "${tmpdir}"' EXIT

    echo "downloading ${download_url}" >&2
    curl -fL --retry 3 --retry-delay 2 -o "${tmpdir}/${mirror_name}" "${download_url}"

    actual="sha256:$(sha256sum "${tmpdir}/${mirror_name}" | cut -d' ' -f1)"
    if [ "${actual}" != "${hash}" ]; then
      echo "digest changed while downloading: expected ${hash}, got ${actual}" >&2
      exit 1
    fi

    if [ -z "${release_id}" ]; then
      payload="$(python3 -c '
import json, sys
print(json.dumps({
    "tag_name": sys.argv[1],
    "name": "Nightly AppImage mirrors",
    "body": "Immutable mirrors of the upstream nightly AppImage.",
}))
' "${mirror_tag}")"
      release_id="$(curl -fsSL -X POST \
        -H "Authorization: Bearer ${token}" \
        -H 'Accept: application/vnd.github+json' \
        -H 'Content-Type: application/json' \
        -d "${payload}" \
        "https://api.github.com/repos/${mirror_repo}/releases" \
        | python3 -c 'import json, sys; print(json.load(sys.stdin)["id"])')"
    fi

    echo "uploading ${mirror_name} to ${mirror_repo}@${mirror_tag}" >&2
    if ! curl -fsSL -X POST \
      -H "Authorization: Bearer ${token}" \
      -H 'Accept: application/vnd.github+json' \
      -H 'Content-Type: application/octet-stream' \
      --upload-file "${tmpdir}/${mirror_name}" \
      "https://uploads.github.com/repos/${mirror_repo}/releases/${release_id}/assets?name=${mirror_name}" >/dev/null; then
      echo "upload failed; checking whether the asset already exists" >&2
    fi

    for _ in 1 2 3 4 5 6 7 8 9 10; do
      fetch_mirror_release
      [ "${asset_digest}" = "${hash}" ] && break
      sleep 2
    done

    if [ "${asset_digest}" != "${hash}" ]; then
      echo "mirror asset ${mirror_name} is not available with digest ${hash}" >&2
      exit 1
    fi
  fi
fi

cat > sources.nix <<EOF
{
  version = "${version}";
  url = "${url}";
  hash = "${hash}";
}
EOF

echo "updated sources.nix to ${version} (${hash})"

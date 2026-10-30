#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
app=".theos/_/Applications/IPTV.app"
if [[ ! -d "$app" ]]; then echo "Run make package FINALPACKAGE=1 first." >&2; exit 1; fi
python3 scripts/check-public-resources.py "$app"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/Payload" dist
COPYFILE_DISABLE=1 cp -R "$app" "$stage/Payload/"
version=$(awk '/^Version:/ {print $2}' control)
output="$PWD/dist/IPTV-$version.ipa"
rm -f "$output"
(cd "$stage" && COPYFILE_DISABLE=1 zip -qr "$output" Payload -x '*/._*' '*/.DS_Store')
echo "$output"
# Keep checksums usable with `cd dist && shasum -a 256 -c SHA256SUMS`.
(cd dist && shasum -a 256 ./*.ipa ../packages/*.deb > SHA256SUMS)

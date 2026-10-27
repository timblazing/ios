#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
app=".theos/_/Applications/T3Mini.app"
[[ -d "$app" ]] || { echo "Run make package FINALPACKAGE=1 first." >&2; exit 1; }
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/Payload" dist
cp -R "$app" "$stage/Payload/"
rm -f "$stage/Payload/T3Mini.app/Pairing.local.plist"
version=$(awk '/^Version:/ {print $2}' control)
output="$PWD/dist/T3Code-$version.ipa"
rm -f "$output"
(cd "$stage" && zip -qr "$output" Payload)
(cd dist && shasum -a 256 ./*.ipa ../packages/*.deb > SHA256SUMS)
echo "$output"

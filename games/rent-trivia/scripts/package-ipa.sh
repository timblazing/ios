#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
app=".theos/_/Applications/RentTrivia.app"
if [[ ! -d "$app" ]]; then echo "Run make package FINALPACKAGE=1 first." >&2; exit 1; fi
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/Payload" dist
cp -R "$app" "$stage/Payload/"
version=$(awk '/^Version:/ {print $2}' control)
output="$PWD/dist/RentTrivia-$version.ipa"
rm -f "$output"
(cd "$stage" && zip -qr "$output" Payload)
echo "$output"

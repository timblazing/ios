#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
output="${1:-/tmp/tv-simulator/IPTV.app}"
mkdir -p "$output"
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun clang -target arm64-apple-ios10.0-simulator -isysroot "$sdk" \
  -fobjc-arc -fno-exceptions -fno-objc-exceptions -Wall -Wextra -Wno-unused-parameter \
  -framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore \
  -framework AVFoundation -framework AVKit -framework CoreMedia -framework MediaPlayer \
  Application/*.m Application/*/*.m -o "$output/IPTV"
cp Resources/Info.plist Resources/Icon*.png "$output/"
# Only the modern simulator needs this; the release targets the home-button mini 2.
/usr/libexec/PlistBuddy -c 'Add :UILaunchScreen dict' "$output/Info.plist"
echo "$output"

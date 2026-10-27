#!/usr/bin/env bash
# Builds the macOS harness for Application/Stream/ (plain clang, Foundation only).
set -euo pipefail
cd "$(dirname "$0")/.."
clang -fobjc-arc -fno-objc-exceptions -Wall -Wextra -framework Foundation Application/Stream/*.m Tests/StreamTests.m -o Tests/stream-tests

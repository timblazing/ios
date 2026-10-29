#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
clang -fobjc-arc -fno-exceptions -fno-objc-exceptions -Wall -Wextra -Werror -framework Foundation \
  Application/Guide/IPTVGuide.m Tests/GuideTests.m -o "$work/guide-tests"
"$work/guide-tests" Tests/fixtures/guide.json

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
clang -fobjc-arc -fno-exceptions -fno-objc-exceptions -Wall -Wextra -Werror -framework Foundation \
  Application/Guide/IPTVGuide.m Application/Guide/IPTVGuideClient.m Tests/GatewayTests.m -o "$work/gateway-tests"
python3 Tests/run-gateway-fixture.py "$work/gateway-tests"

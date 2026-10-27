#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
clang -fobjc-arc -Wall -Wextra -framework Foundation Application/Game/*.m Tests/RulesTests.m -o Tests/rules-tests
Tests/rules-tests
for tz in America/Chicago Pacific/Auckland; do TZ=$tz Tests/rules-tests >/dev/null; done

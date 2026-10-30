#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
clang -fobjc-arc -fno-exceptions -fno-objc-exceptions -Wall -Wextra -Werror -framework Foundation \
  Application/Configuration/IPTVConfiguration.m Tests/ConfigurationTests.m -o "$work/configuration-tests"
"$work/configuration-tests"

#!/usr/bin/env bash
# Builds and runs the Foundation-only model tests on macOS.
set -euo pipefail
cd "$(dirname "$0")/.."
clang -fobjc-arc -Wall -Wextra -framework Foundation Application/Model/*.m Tests/PaintModelTests.m -o Tests/rules-tests
Tests/rules-tests

#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TESTING_PLUGIN="$(dirname "$(xcrun --find swiftc)")/../lib/swift/host/plugins/testing/libTestingMacros.dylib"
FLAGS=(--disable-xctest)
if [[ -f "$TESTING_PLUGIN" ]]; then
    FLAGS+=(-Xswiftc -load-plugin-library -Xswiftc "$TESTING_PLUGIN")
fi
swift test "${FLAGS[@]}" "$@"

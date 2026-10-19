#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="$ROOT/dist/Altdock.app"
if pgrep -f "^$APP/Contents/MacOS/Altdock( |$)" >/dev/null; then
    printf 'Quit Altdock and wait for its recovery helper to exit before rebuilding.\n' >&2
    exit 1
fi
swift build -c release "$@"
BIN_DIR="$(swift build -c release --show-bin-path "$@")"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Altdock" "$APP/Contents/MacOS/Altdock"
cp Resources/Info.plist "$APP/Contents/Info.plist"
swift scripts/create-icon.swift "$ROOT/.build/Altdock.iconset"
iconutil --convert icns "$ROOT/.build/Altdock.iconset" --output "$APP/Contents/Resources/Altdock.icns"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" "$APP"
printf '\nBuilt %s\nRun: open "%s"\n' "$APP" "$APP"

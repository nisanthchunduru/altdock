#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release "$@"
BIN_DIR="$(swift build -c release --show-bin-path "$@")"
APP="$ROOT/dist/Altdock.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Altdock" "$APP/Contents/MacOS/Altdock"
cp Resources/Info.plist "$APP/Contents/Info.plist"
swift scripts/create-icon.swift "$ROOT/.build/Altdock.iconset"
iconutil --convert icns "$ROOT/.build/Altdock.iconset" --output "$APP/Contents/Resources/Altdock.icns"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" "$APP"
printf '\nBuilt %s\nRun: open "%s"\n' "$APP" "$APP"

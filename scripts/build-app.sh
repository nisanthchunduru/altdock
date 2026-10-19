#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="$ROOT/dist/Altdock.app"
SIGNING_IDENTITY="${CODE_SIGN_IDENTITY:-Altdock}"
SIGNING_KEYCHAIN="${CODE_SIGN_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    printf 'Warning: explicitly using ad-hoc signing; Accessibility grants may not survive rebuilding.\n' >&2
else
    IDENTITIES="$(security find-identity -v -p codesigning "$SIGNING_KEYCHAIN")"
    MATCH_COUNT=0
    MATCHED_FINGERPRINT=""
    PATTERN='([[:xdigit:]]{40})[[:space:]]+"([^"]+)"'
    while IFS= read -r line; do
        if [[ "$line" =~ $PATTERN ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$SIGNING_IDENTITY" || "${BASH_REMATCH[2]}" == "$SIGNING_IDENTITY" ]]; then
                MATCH_COUNT=$((MATCH_COUNT + 1))
                MATCHED_FINGERPRINT="${BASH_REMATCH[1]}"
            fi
        fi
    done <<< "$IDENTITIES"
    if [[ "$MATCH_COUNT" -ne 1 ]]; then
        printf 'Expected one valid signing identity named %s in %s.\nRun: swift -suppress-warnings scripts/create-signing-identity.swift --create\n' "$SIGNING_IDENTITY" "$SIGNING_KEYCHAIN" >&2
        exit 1
    fi
    SIGNING_IDENTITY="$MATCHED_FINGERPRINT"
fi
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
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$APP"
else
    codesign --force --keychain "$SIGNING_KEYCHAIN" --sign "$SIGNING_IDENTITY" "$APP"
fi
codesign --verify --strict "$APP"
printf '\nBuilt %s\nRun: open "%s"\n' "$APP" "$APP"

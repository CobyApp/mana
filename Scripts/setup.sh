#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

tuist install

PATCH_TARGET="Tuist/.build/checkouts/UnrarKit-Swift-Package/Package.swift"
PATCH_SOURCE="Patches/UnrarKit-Package-fixed.swift"

if [ -f "$PATCH_TARGET" ] && [ -f "$PATCH_SOURCE" ]; then
    if ! diff -q "$PATCH_TARGET" "$PATCH_SOURCE" > /dev/null 2>&1; then
        echo "Applying UnrarKit Package.swift fix…"
        cp "$PATCH_SOURCE" "$PATCH_TARGET"
    else
        echo "UnrarKit Package.swift already up to date."
    fi
fi

tuist generate --no-open

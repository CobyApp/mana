#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

tuist install

PATCH_TARGET="Tuist/.build/checkouts/UnrarKit-Swift-Package/Package.swift"
PATCH_SOURCE="Patches/UnrarKit-Package-fixed.swift"

if [ -f "$PATCH_TARGET" ] && [ -f "$PATCH_SOURCE" ]; then
    if ! diff -q "$PATCH_TARGET" "$PATCH_SOURCE" > /dev/null 2>&1; then
        echo "Applying UnrarKit Package.swift fix…"
        chmod u+w "$PATCH_TARGET"
        cp "$PATCH_SOURCE" "$PATCH_TARGET"
        rm -rf Tuist/.build/tuist-derived/UnrarKit Tuist/.build/tuist-derived/UnrarKitCategories
    else
        echo "UnrarKit Package.swift already up to date."
    fi
fi

tuist generate --no-open

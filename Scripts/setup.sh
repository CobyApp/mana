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

# ComposableArchitecture needs an iOS 17 deployment target (its UIKit
# NavigationStackController uses iOS 17-only APIs), but the rest of the
# Point-Free ecosystem must stay at 16 — swift-perception's `Bindable`
# backport is `obsoleted: 17` and won't compile at 17. Tuist derives external
# package deployment targets from PackageSettings.baseSettings (16, set in
# Tuist/Package.swift), so bump only TCA's generated project to 17 here.
TCA_PBXPROJ="Tuist/.build/tuist-derived/Projects/swift-composable-architecture/swift-composable-architecture.xcodeproj/project.pbxproj"
if [ -f "$TCA_PBXPROJ" ]; then
    echo "Bumping ComposableArchitecture deployment target to iOS 17…"
    perl -i -pe 's/(IPHONEOS_DEPLOYMENT_TARGET = )\d+(?:\.\d+)?;/${1}17.0;/' "$TCA_PBXPROJ"
fi

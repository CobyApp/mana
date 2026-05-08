# Mana

iPad comic reader (TCA + SwiftUI + Tuist + SwiftData).

## Setup

After cloning:

```bash
./Scripts/setup.sh
```

This runs `tuist install`, applies a fix to UnrarKit's bundled `Package.swift` (the upstream
fork `ZHK1024/UnrarKit-Swift-Package` 2.10.1 ships an incomplete manifest — see
`Patches/UnrarKit-Package-fixed.swift` for the corrected version), then runs `tuist generate`.

Once the workspace is generated, open `Mana.xcworkspace`.

## Architecture

- **TCA** (The Composable Architecture) for state management
- **Tuist** for project generation
- **SwiftData** for persistence
- Feature modules: `LibraryFeature`, `ReaderFeature`, `BookmarksFeature`, `SettingsFeature`, `AppFeature`

import SwiftUI

/// Low-spec / e-ink friendly mode: when true, decorative effects (halftone backdrop, scanlines,
/// speed lines, glitch shudder, chromatic aberration) render flat. Set once at the app root from
/// the user's setting; every effect reads it, so feature views need no changes.
private struct ManaLiteModeKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    var manaLiteMode: Bool {
        get { self[ManaLiteModeKey.self] }
        set { self[ManaLiteModeKey.self] = newValue }
    }
}

public enum LiteMode {
    /// UserDefaults key shared by Settings (writer) and the app root (reader).
    public static let storageKey = "mana.liteMode"
}

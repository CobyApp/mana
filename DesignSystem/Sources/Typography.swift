import SwiftUI

public extension Tokens {
    /// Typography for the manga-glitch tone.
    /// We rely on system fonts so Korean and Japanese render correctly without bundling face files.
    /// `display` is a heavy condensed-feel hit using rounded design at black weight.
    /// `mono` is for HUD/page-counter style readouts.
    enum Typography {
        // Display — for screen titles, sound-effect text, splash
        public static func display(_ size: CGFloat) -> Font {
            .system(size: size, weight: .black, design: .rounded)
        }

        public static let displayXL: Font = .system(size: 64, weight: .black, design: .rounded)
        public static let displayL: Font = .system(size: 44, weight: .black, design: .rounded)
        public static let displayM: Font = .system(size: 32, weight: .black, design: .rounded)
        public static let displayS: Font = .system(size: 22, weight: .heavy, design: .rounded)

        // Headings & labels
        public static let title: Font = .system(size: 20, weight: .heavy, design: .rounded)
        public static let subtitle: Font = .system(size: 15, weight: .bold, design: .rounded)
        public static let body: Font = .system(size: 15, weight: .medium, design: .default)
        public static let caption: Font = .system(size: 12, weight: .semibold, design: .rounded)

        // Mono / HUD
        public static let mono: Font = .system(size: 13, weight: .bold, design: .monospaced)
        public static let monoLarge: Font = .system(size: 18, weight: .heavy, design: .monospaced)
    }
}

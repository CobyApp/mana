import SwiftUI

public extension Tokens {
    enum Colors {
        // Surface
        public static var backgroundPrimary: Color { Color("BackgroundPrimary", bundle: .module) }
        public static var backgroundSecondary: Color { Color("BackgroundSecondary", bundle: .module) }

        // Manga base — semantic, do not adapt across light/dark on their own.
        // `paper` = warm off-white surface, `ink` = deep near-black.
        // Their xcassets entries flip in dark mode so backgrounds stay readable.
        public static var paper: Color { Color("Paper", bundle: .module) }
        public static var ink: Color { Color("Ink", bundle: .module) }

        // Accents
        public static var accent: Color { Color("Accent", bundle: .module) }
        public static var accentSecondary: Color { Color("AccentSecondary", bundle: .module) }

        // CMY split — fixed across light/dark; meant to bleed against ink/paper
        public static var glitchRed: Color { Color("GlitchRed", bundle: .module) }
        public static var glitchCyan: Color { Color("GlitchCyan", bundle: .module) }
        public static var glitchYellow: Color { Color("GlitchYellow", bundle: .module) }

        // Halftone fill (low-alpha dot color)
        public static var halftone: Color { Color("Halftone", bundle: .module) }

        // Glass overlay (legacy)
        public static var onGlassPrimary: Color { Color("OnGlassPrimary", bundle: .module) }
        public static var onGlassSecondary: Color { Color("OnGlassSecondary", bundle: .module) }
    }
}

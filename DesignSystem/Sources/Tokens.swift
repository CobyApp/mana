import SwiftUI

public enum Tokens {
    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 16
        public static let l: CGFloat = 24
        public static let xl: CGFloat = 32
    }

    public enum Radius {
        public static let card: CGFloat = 12
        public static let pill: CGFloat = 999
        // Manga panels are sharp — almost no radius
        public static let panel: CGFloat = 2
    }

    /// Stroke widths for the inked panel look.
    public enum Stroke {
        public static let hair: CGFloat = 1
        public static let regular: CGFloat = 2
        public static let bold: CGFloat = 3
        public static let panel: CGFloat = 4
    }

    /// Static rotations to give each panel a hand-drawn vibe.
    /// Cycle through these by index (e.g. `panelTilt(at: i)`) rather than randomising.
    public enum Tilt {
        public static let angles: [Double] = [-1.4, 0.8, -0.6, 1.2, -1.0, 0.5, -1.8, 1.6]

        public static func angle(at index: Int) -> Angle {
            .degrees(angles[abs(index) % angles.count])
        }
    }

    /// Halftone dot rendering parameters.
    public enum Halftone {
        public static let dotSpacing: CGFloat = 6
        public static let dotRadius: CGFloat = 1.0
        public static let denseDotSpacing: CGFloat = 4
        public static let denseDotRadius: CGFloat = 1.4
    }

    /// Animation curves used across the manga UI.
    public enum Motion {
        public static let snap: Animation = .interpolatingSpring(stiffness: 500, damping: 28)
        public static let panel: Animation = .spring(response: 0.32, dampingFraction: 0.62)
        public static let glitch: Animation = .easeInOut(duration: 0.08)
        public static let pulse: Animation = .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
    }
}

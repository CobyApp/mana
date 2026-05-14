import SwiftUI

public extension Color {
    /// Unpacks an ARGB-packed UInt32 (alpha in the high byte) into a SwiftUI Color.
    /// The translation overlay uses this to recreate sampled page background colors.
    init(argb value: UInt32) {
        let a = Double((value >> 24) & 0xFF) / 255.0
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >>  8) & 0xFF) / 255.0
        let b = Double(value        & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Packs the receiver into an ARGB UInt32. Conversion happens via UIColor so
    /// alternative color spaces resolve to sRGB components.
    static func packARGB(red: Double, green: Double, blue: Double, alpha: Double) -> UInt32 {
        let a = UInt32(max(0, min(255, alpha * 255)))
        let r = UInt32(max(0, min(255, red * 255)))
        let g = UInt32(max(0, min(255, green * 255)))
        let b = UInt32(max(0, min(255, blue * 255)))
        return (a << 24) | (r << 16) | (g << 8) | b
    }
}

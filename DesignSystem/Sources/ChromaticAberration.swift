import SwiftUI

/// Static chromatic aberration: clones the content twice in red and cyan,
/// offsets them slightly, and blends. Cheap; safe to apply broadly.
public struct ChromaticAberration: ViewModifier {
    private let offset: CGFloat
    private let intensity: Double

    public init(offset: CGFloat = 1.5, intensity: Double = 0.55) {
        self.offset = offset
        self.intensity = intensity
    }

    public func body(content: Content) -> some View {
        content
            .background(
                content
                    .foregroundStyle(Tokens.Colors.glitchRed)
                    .blendMode(.plusLighter)
                    .opacity(intensity)
                    .offset(x: -offset, y: 0)
            )
            .background(
                content
                    .foregroundStyle(Tokens.Colors.glitchCyan)
                    .blendMode(.plusLighter)
                    .opacity(intensity)
                    .offset(x: offset, y: 0)
            )
    }
}

public extension View {
    /// Adds a permanent RGB-split halo behind the content.
    func chromaticAberration(offset: CGFloat = 1.5, intensity: Double = 0.55) -> some View {
        modifier(ChromaticAberration(offset: offset, intensity: intensity))
    }
}

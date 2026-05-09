import SwiftUI

/// CRT-style horizontal scanline overlay.
public struct Scanlines: View {
    private let lineColor: Color
    private let spacing: CGFloat
    private let thickness: CGFloat
    private let drift: Bool

    @State private var phase: CGFloat = 0

    public init(
        color: Color = Tokens.Colors.ink.opacity(0.10),
        spacing: CGFloat = 3,
        thickness: CGFloat = 1,
        drift: Bool = true
    ) {
        self.lineColor = color
        self.spacing = spacing
        self.thickness = thickness
        self.drift = drift
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: drift ? 1.0 / 30.0 : 1.0)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let drifting: CGFloat = drift ? CGFloat(t.truncatingRemainder(dividingBy: 1.0)) * spacing : 0
                var y: CGFloat = -spacing + drifting
                while y < size.height {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: thickness)
                    ctx.fill(Path(rect), with: .color(lineColor))
                    y += spacing
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

public extension View {
    /// Overlays a CRT scanline pattern.
    func scanlines(
        color: Color = Tokens.Colors.ink.opacity(0.10),
        spacing: CGFloat = 3,
        thickness: CGFloat = 1,
        drift: Bool = true
    ) -> some View {
        overlay(Scanlines(color: color, spacing: spacing, thickness: thickness, drift: drift))
    }
}

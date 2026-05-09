import SwiftUI

/// Comic-book halftone dot pattern, drawn with Canvas so it scales freely.
public struct HalftoneBackground: View {
    private let dotColor: Color
    private let spacing: CGFloat
    private let radius: CGFloat
    private let stagger: Bool

    public init(
        color: Color = Tokens.Colors.halftone,
        spacing: CGFloat = Tokens.Halftone.dotSpacing,
        radius: CGFloat = Tokens.Halftone.dotRadius,
        stagger: Bool = true
    ) {
        self.dotColor = color
        self.spacing = spacing
        self.radius = radius
        self.stagger = stagger
    }

    public var body: some View {
        Canvas { ctx, size in
            let cols = Int(ceil(size.width / spacing)) + 2
            let rows = Int(ceil(size.height / spacing)) + 2
            for row in 0..<rows {
                for col in 0..<cols {
                    let xOffset: CGFloat = (stagger && row.isMultiple(of: 2)) ? spacing / 2 : 0
                    let x = CGFloat(col) * spacing + xOffset
                    let y = CGFloat(row) * spacing
                    let rect = CGRect(x: x - radius, y: y - radius,
                                      width: radius * 2, height: radius * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(dotColor))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

public extension View {
    /// Lays a halftone dot pattern behind the receiver.
    func halftoneBackground(
        color: Color = Tokens.Colors.halftone,
        spacing: CGFloat = Tokens.Halftone.dotSpacing,
        radius: CGFloat = Tokens.Halftone.dotRadius
    ) -> some View {
        background(HalftoneBackground(color: color, spacing: spacing, radius: radius))
    }

    /// Overlays a halftone dot pattern on the receiver.
    func halftoneOverlay(
        color: Color = Tokens.Colors.halftone,
        spacing: CGFloat = Tokens.Halftone.dotSpacing,
        radius: CGFloat = Tokens.Halftone.dotRadius
    ) -> some View {
        overlay(HalftoneBackground(color: color, spacing: spacing, radius: radius))
    }
}

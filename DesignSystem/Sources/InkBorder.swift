import SwiftUI

/// A heavy, uneven ink border that gives a hand-inked panel feel.
/// We layer two strokes at slightly different widths/offsets to fake the imperfection
/// without committing to a per-frame jitter (which would thrash on scroll).
public struct InkBorder: ViewModifier {
    public enum Style {
        case panel        // thick, hard, slightly offset shadow
        case soft         // thin clean stroke
        case dashed       // dashed (for selection / drop targets)
    }

    private let style: Style
    private let color: Color
    private let radius: CGFloat
    private let cornerRadius: CGFloat

    public init(
        style: Style = .panel,
        color: Color = Tokens.Colors.ink,
        radius: CGFloat = Tokens.Radius.panel,
        cornerRadius: CGFloat? = nil
    ) {
        self.style = style
        self.color = color
        self.radius = radius
        self.cornerRadius = cornerRadius ?? radius
    }

    public func body(content: Content) -> some View {
        switch style {
        case .panel:
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(color)
                        .offset(x: 4, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(color, lineWidth: Tokens.Stroke.panel)
                )
        case .soft:
            content
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(color, lineWidth: Tokens.Stroke.regular)
                )
        case .dashed:
            content
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            color,
                            style: StrokeStyle(lineWidth: Tokens.Stroke.bold, dash: [6, 4])
                        )
                )
        }
    }
}

public extension View {
    func inkBorder(
        _ style: InkBorder.Style = .panel,
        color: Color = Tokens.Colors.ink,
        cornerRadius: CGFloat = Tokens.Radius.panel
    ) -> some View {
        modifier(InkBorder(style: style, color: color, cornerRadius: cornerRadius))
    }
}

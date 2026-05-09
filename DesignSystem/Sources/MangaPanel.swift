import SwiftUI

/// Manga-panel container: hard ink border, offset shadow, optional tilt.
/// Wrap any view in this to make it look like a frame torn from a comic page.
public struct MangaPanel<Content: View>: View {
    public enum Surface {
        case paper
        case ink
        case clear   // pass-through; just border + shadow
    }

    private let content: Content
    private let surface: Surface
    private let tiltIndex: Int?
    private let cornerRadius: CGFloat
    private let strokeWidth: CGFloat
    private let shadowOffset: CGSize
    private let halftone: Bool

    public init(
        surface: Surface = .paper,
        tiltIndex: Int? = nil,
        cornerRadius: CGFloat = Tokens.Radius.panel,
        strokeWidth: CGFloat = Tokens.Stroke.panel,
        shadowOffset: CGSize = .init(width: 4, height: 5),
        halftone: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.surface = surface
        self.tiltIndex = tiltIndex
        self.cornerRadius = cornerRadius
        self.strokeWidth = strokeWidth
        self.shadowOffset = shadowOffset
        self.halftone = halftone
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let inkColor = Tokens.Colors.ink

        return content
            .background {
                if halftone {
                    HalftoneBackground()
                        .clipShape(shape)
                }
            }
            .background(surfaceFill.clipShape(shape))
            .clipShape(shape)
            .overlay(shape.strokeBorder(inkColor, lineWidth: strokeWidth))
            .background(
                shape
                    .fill(inkColor)
                    .offset(x: shadowOffset.width, y: shadowOffset.height)
            )
            .rotationEffect(tiltIndex.map { Tokens.Tilt.angle(at: $0) } ?? .zero)
    }

    @ViewBuilder
    private var surfaceFill: some View {
        switch surface {
        case .paper: Tokens.Colors.paper
        case .ink: Tokens.Colors.ink
        case .clear: Color.clear
        }
    }
}

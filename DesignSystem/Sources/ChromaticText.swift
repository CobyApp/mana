import SwiftUI

/// Text rendered with permanent RGB-split halos. Static (no animation), cheap.
public struct ChromaticText: View {
    private let text: String
    private let font: Font
    private let baseColor: Color
    private let offset: CGFloat

    public init(
        _ text: String,
        font: Font = Tokens.Typography.displayM,
        color: Color = Tokens.Colors.ink,
        offset: CGFloat = 2.0
    ) {
        self.text = text
        self.font = font
        self.baseColor = color
        self.offset = offset
    }

    public var body: some View {
        ZStack {
            Text(text)
                .font(font)
                .foregroundStyle(Tokens.Colors.glitchRed)
                .offset(x: -offset, y: 0)
                .blendMode(.plusDarker)

            Text(text)
                .font(font)
                .foregroundStyle(Tokens.Colors.glitchCyan)
                .offset(x: offset, y: 0)
                .blendMode(.plusDarker)

            Text(text)
                .font(font)
                .foregroundStyle(baseColor)
        }
        .accessibilityLabel(text)
    }
}

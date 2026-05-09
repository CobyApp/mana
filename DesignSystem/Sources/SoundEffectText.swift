import SwiftUI

/// Onomatopoeia-style sound effect text — heavy weight, outlined, slightly tilted.
/// Use for transient bursts ("BAM!", "DOKI!", "起動") and for screen titles you want to feel loud.
public struct SoundEffectText: View {
    private let text: String
    private let font: Font
    private let fillColor: Color
    private let strokeColor: Color
    private let strokeWidth: CGFloat
    private let tiltDegrees: Double
    private let shadowOffset: CGSize

    public init(
        _ text: String,
        font: Font = Tokens.Typography.displayL,
        fill: Color = Tokens.Colors.accent,
        stroke: Color = Tokens.Colors.ink,
        strokeWidth: CGFloat = 4,
        tilt: Double = -6,
        shadowOffset: CGSize = .init(width: 3, height: 4)
    ) {
        self.text = text
        self.font = font
        self.fillColor = fill
        self.strokeColor = stroke
        self.strokeWidth = strokeWidth
        self.tiltDegrees = tilt
        self.shadowOffset = shadowOffset
    }

    public var body: some View {
        ZStack {
            // Shadow
            Text(text)
                .font(font)
                .foregroundStyle(strokeColor)
                .offset(x: shadowOffset.width, y: shadowOffset.height)

            // Outline (8-direction stroke faked via shadow trick)
            ZStack {
                ForEach(strokeOffsets, id: \.self) { dx in
                    ForEach(strokeOffsets, id: \.self) { dy in
                        if dx != 0 || dy != 0 {
                            Text(text)
                                .font(font)
                                .foregroundStyle(strokeColor)
                                .offset(x: CGFloat(dx) * strokeWidth / 2,
                                        y: CGFloat(dy) * strokeWidth / 2)
                        }
                    }
                }
            }

            // Fill
            Text(text)
                .font(font)
                .foregroundStyle(fillColor)
        }
        .rotationEffect(.degrees(tiltDegrees))
        .accessibilityLabel(text)
    }

    private var strokeOffsets: [Int] { [-1, 0, 1] }
}

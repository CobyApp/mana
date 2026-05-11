import SwiftUI

/// Manga-tone draggable progress bar. Replaces the system `Slider` so
/// reader controls match the rest of the design.
/// - track: low-opacity paper bar
/// - fill: hot-pink (accent) up to current value
/// - thumb: paper square with ink border
/// `reversed: true` mirrors the bar so the thumb starts on the right
/// (for right-to-left page progression).
public struct MangaProgressBar: View {
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let reversed: Bool

    public init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        reversed: Bool = false
    ) {
        self._value = value
        self.range = range
        self.reversed = reversed
    }

    public var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            let span = max(0.0001, range.upperBound - range.lowerBound)
            let normalized = max(0, min(1, (value - range.lowerBound) / span))
            let displayed = reversed ? 1 - normalized : normalized
            let thumbX = width * CGFloat(displayed)

            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                    .fill(Tokens.Colors.paper.opacity(0.18))
                    .frame(height: 6)
                    .overlay(
                        Rectangle().strokeBorder(Tokens.Colors.paper.opacity(0.35), lineWidth: 1)
                    )

                // Fill — anchored to whichever side the thumb starts from
                if reversed {
                    Rectangle()
                        .fill(Tokens.Colors.accent)
                        .frame(width: width - thumbX, height: 6)
                        .offset(x: thumbX)
                } else {
                    Rectangle()
                        .fill(Tokens.Colors.accent)
                        .frame(width: thumbX, height: 6)
                }

                // Thumb
                Rectangle()
                    .fill(Tokens.Colors.paper)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: 2)
                    )
                    .offset(x: thumbX - 11)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let x = max(0, min(width, drag.location.x))
                        let ratio = Double(x / width)
                        let logical = reversed ? 1 - ratio : ratio
                        value = range.lowerBound + span * logical
                    }
            )
        }
        .frame(height: 28)
    }
}

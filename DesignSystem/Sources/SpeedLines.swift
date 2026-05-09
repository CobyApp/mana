import SwiftUI

/// Manga-style radial speed lines (集中線). Draws lines from the edges toward the center,
/// fading to transparent. Used as a transient page-turn flair or hover effect.
public struct SpeedLines: View {
    private let color: Color
    private let lineCount: Int
    private let centerHole: CGFloat
    private let lineWidth: CGFloat
    private let intensity: Double

    public init(
        color: Color = Tokens.Colors.ink,
        lineCount: Int = 64,
        centerHole: CGFloat = 0.35,
        lineWidth: CGFloat = 1.6,
        intensity: Double = 1.0
    ) {
        self.color = color
        self.lineCount = lineCount
        self.centerHole = centerHole
        self.lineWidth = lineWidth
        self.intensity = intensity
    }

    public var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerRadius = max(size.width, size.height)
            let holeRadius = min(size.width, size.height) * 0.5 * centerHole

            for i in 0..<lineCount {
                let baseAngle = (Double(i) / Double(lineCount)) * .pi * 2
                // Pseudo-random jitter per index (deterministic, no randomness per frame)
                let jitter = sin(Double(i) * 12.9898) * 0.08
                let angle = baseAngle + jitter
                // Vary line length so the burst feels organic
                let lengthFactor = 0.55 + (sin(Double(i) * 78.233) + 1) / 2 * 0.45
                let inner = CGPoint(
                    x: center.x + cos(angle) * holeRadius,
                    y: center.y + sin(angle) * holeRadius
                )
                let outer = CGPoint(
                    x: center.x + cos(angle) * outerRadius * lengthFactor,
                    y: center.y + sin(angle) * outerRadius * lengthFactor
                )
                var path = Path()
                path.move(to: inner)
                path.addLine(to: outer)
                ctx.stroke(
                    path,
                    with: .color(color.opacity(intensity)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

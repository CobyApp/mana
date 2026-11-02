import SwiftUI

/// On-brand loader: three ink-bordered 16pt panels with hard offset shadows (middle one accent)
/// bouncing in sequence, over a pulsing mono "LOADING" caption. Static in lite mode.
/// Ported from Android `ManaLoader`.
public struct ManaLoader: View {
    private let caption: String?
    private let panelSize: CGFloat
    @Environment(\.manaLiteMode) private var liteMode

    public init(caption: String? = "LOADING", panelSize: CGFloat = 16) {
        self.caption = caption
        self.panelSize = panelSize
    }

    public var body: some View {
        VStack(spacing: panelSize * 1.1) {
            if liteMode {
                content(time: 0, animated: false)
            } else {
                TimelineView(.animation) { context in
                    content(time: context.date.timeIntervalSinceReferenceDate, animated: true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: caption ?? "Loading"))
    }

    @ViewBuilder
    private func content(time: TimeInterval, animated: Bool) -> some View {
        HStack(spacing: panelSize * 0.6) {
            ForEach(0..<3, id: \.self) { i in
                panel(accent: i == 1)
                    .offset(y: animated ? -lift(time: time, index: i) : 0)
            }
        }
        .padding(.top, panelSize)
        if let caption {
            Text(verbatim: caption)
                .font(Tokens.Typography.mono)
                .foregroundStyle(Tokens.Colors.ink)
                .opacity(animated ? 0.45 + 0.55 * (0.5 + 0.5 * sin(time * 2 * .pi / 1.2)) : 1)
        }
    }

    private func panel(accent: Bool) -> some View {
        Rectangle()
            .fill(accent ? Tokens.Colors.accent : Tokens.Colors.paper)
            .frame(width: panelSize, height: panelSize)
            .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: 2))
            .background(Rectangle().fill(Tokens.Colors.ink).offset(x: 2, y: 3))
    }

    /// 900ms cycle: 0 → 1 at 300ms → 0 at 600ms, rest; staggered 150ms per panel.
    private func lift(time: TimeInterval, index: Int) -> CGFloat {
        let cycle = 0.9
        let t = (time - Double(index) * 0.15).truncatingRemainder(dividingBy: cycle)
        let phase = t < 0 ? t + cycle : t
        let v: Double
        if phase < 0.3 { v = phase / 0.3 }
        else if phase < 0.6 { v = 1 - (phase - 0.3) / 0.3 }
        else { v = 0 }
        let eased = sin(v * .pi / 2)
        return CGFloat(eased) * panelSize * 0.9
    }
}

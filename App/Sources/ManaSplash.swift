import SwiftUI
import DesignSystem

/// Boot intro: glitchy onomatopoeia title that hangs for a beat then fades.
/// Self-driving — fires once on appear and notifies completion via `onFinish`.
struct ManaSplash: View {
    let onFinish: () -> Void

    @State private var glitchTick: Int = 0
    @State private var titleVisible: Bool = false
    @State private var subtitleVisible: Bool = false
    @State private var fadingOut: Bool = false

    var body: some View {
        ZStack {
            Tokens.Colors.paper.ignoresSafeArea()
            HalftoneBackground().ignoresSafeArea()
            Scanlines(color: Tokens.Colors.ink.opacity(0.06), spacing: 4).ignoresSafeArea()

            VStack(spacing: Tokens.Spacing.l) {
                if titleVisible {
                    SoundEffectText(
                        "MANA",
                        font: Tokens.Typography.displayXL,
                        fill: Tokens.Colors.accent,
                        stroke: Tokens.Colors.ink,
                        strokeWidth: 8,
                        tilt: -7,
                        shadowOffset: .init(width: 6, height: 8)
                    )
                    .glitch(trigger: glitchTick, intensity: 5, duration: 0.32)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                }

                if subtitleVisible {
                    Text("コミックリーダー / COMIC READER")
                        .font(Tokens.Typography.mono)
                        .foregroundStyle(Tokens.Colors.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Tokens.Colors.paper)
                        .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: 1.5))
                        .transition(.opacity)
                }
            }
        }
        .opacity(fadingOut ? 0 : 1)
        .task { await runIntro() }
    }

    @MainActor
    private func runIntro() async {
        try? await Task.sleep(nanoseconds: 60_000_000)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
            titleVisible = true
        }
        try? await Task.sleep(nanoseconds: 250_000_000)
        glitchTick &+= 1
        try? await Task.sleep(nanoseconds: 200_000_000)
        withAnimation(.easeOut(duration: 0.25)) {
            subtitleVisible = true
        }
        try? await Task.sleep(nanoseconds: 350_000_000)
        glitchTick &+= 1
        try? await Task.sleep(nanoseconds: 450_000_000)
        withAnimation(.easeIn(duration: 0.45)) { fadingOut = true }
        try? await Task.sleep(nanoseconds: 460_000_000)
        onFinish()
    }
}

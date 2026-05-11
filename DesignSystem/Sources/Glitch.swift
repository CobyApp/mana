import SwiftUI

/// Trigger-driven glitch burst: when `trigger` changes, the content briefly
/// splits into red/cyan halves, shudders horizontally, and snaps back.
/// Designed to be cheap — only animates while a burst is in flight.
public struct Glitch<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    let intensity: CGFloat
    let duration: Double

    @State private var phase: CGFloat = 0
    @State private var isBursting: Bool = false

    public func body(content: Content) -> some View {
        ZStack {
            // Red ghost — `allowsHitTesting(false)` so the duplicated views
            // never interfere with the original's gestures/scroll.
            // NOTE: do not apply this modifier to heavy stateful views
            // (UIViewRepresentable, UIScrollView wrappers).
            // No blend mode — `.plusLighter` left a bright halo on light
            // (paper) backgrounds when the burst played.
            content
                .foregroundStyle(Tokens.Colors.glitchRed)
                .offset(x: isBursting ? -intensity * 1.6 - phase : 0,
                        y: isBursting ? -phase * 0.6 : 0)
                .opacity(isBursting ? 0.7 : 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            content
                .foregroundStyle(Tokens.Colors.glitchCyan)
                .offset(x: isBursting ? intensity * 1.6 + phase : 0,
                        y: isBursting ? phase * 0.6 : 0)
                .opacity(isBursting ? 0.7 : 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            content
                .offset(x: isBursting ? phase : 0)
        }
        .onChange(of: trigger) { _, _ in burst() }
    }

    private func burst() {
        guard !isBursting else { return }
        isBursting = true
        let steps: [CGFloat] = [intensity, -intensity * 0.8, intensity * 0.5, -intensity * 0.3, 0]
        let stepDuration = duration / Double(steps.count)
        for (i, value) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                withAnimation(.linear(duration: stepDuration)) { phase = value }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            isBursting = false
            phase = 0
        }
    }
}

/// Continuously runs a low-intensity glitch on a fixed cadence. Use sparingly.
public struct GlitchPulse: ViewModifier {
    let interval: Double
    let intensity: CGFloat

    @State private var tick: Int = 0
    @State private var phase: CGFloat = 0
    @State private var splitOpacity: Double = 0

    public func body(content: Content) -> some View {
        ZStack {
            content
                .foregroundStyle(Tokens.Colors.glitchRed)
                .blendMode(.plusLighter)
                .offset(x: -intensity - phase)
                .opacity(splitOpacity)
            content
                .foregroundStyle(Tokens.Colors.glitchCyan)
                .blendMode(.plusLighter)
                .offset(x: intensity + phase)
                .opacity(splitOpacity)
            content.offset(x: phase)
        }
        .task(id: tick) {
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            await MainActor.run {
                withAnimation(.linear(duration: 0.05)) {
                    phase = intensity
                    splitOpacity = 0.85
                }
            }
            try? await Task.sleep(nanoseconds: 60_000_000)
            await MainActor.run {
                withAnimation(.linear(duration: 0.05)) {
                    phase = -intensity * 0.6
                }
            }
            try? await Task.sleep(nanoseconds: 60_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.12)) {
                    phase = 0
                    splitOpacity = 0
                }
                tick &+= 1
            }
        }
    }
}

public extension View {
    /// Plays a glitch burst whenever `trigger` changes.
    func glitch<T: Equatable>(trigger: T, intensity: CGFloat = 4, duration: Double = 0.32) -> some View {
        modifier(Glitch(trigger: trigger, intensity: intensity, duration: duration))
    }

    /// Plays a low-intensity glitch on a recurring cadence. Use sparingly.
    func glitchPulse(every interval: Double = 4.5, intensity: CGFloat = 2.5) -> some View {
        modifier(GlitchPulse(interval: interval, intensity: intensity))
    }
}

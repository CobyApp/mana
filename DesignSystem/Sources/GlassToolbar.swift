import SwiftUI

// Liquid Glass API confirmed in iOS 26 SDK (iPhoneSimulator26.4.sdk / SwiftUICore):
//   func glassEffect(_ glass: Glass = .regular, in shape: some Shape = DefaultGlassEffectShape()) -> some View
// Using variant: .glassEffect(in: .capsule) — default .regular glass, explicit capsule shape.
public struct GlassToolbar<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: Tokens.Spacing.m) {
            content
        }
        .padding(.horizontal, Tokens.Spacing.m)
        .padding(.vertical, Tokens.Spacing.s)
        .modifier(GlassEffectModifier())
    }
}

private struct GlassEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
        }
    }
}

import SwiftUI

// NOTE: glassEffect(in:) was not found in iOS 26.4 SDK (iPhoneSimulator26.4.sdk).
// iOS 26 exposes GlassButtonStyle and Glass types instead of a generic glassEffect view modifier.
// Substituted with .background(.thinMaterial, in: .capsule) to preserve the capsule shape.
// Full Liquid Glass polish targeting the correct API lands in Plan 4 / DesignSystem v2.
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
        .background(.thinMaterial, in: .capsule)
    }
}

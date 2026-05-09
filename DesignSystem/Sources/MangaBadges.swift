import SwiftUI

/// Small ink-bordered icon chip for navigation bar / toolbar buttons.
/// Wrap inside `Button { ... } label: { MangaIconBadge(...) }` and apply
/// `.buttonStyle(.plain)` to keep the system's tint/highlight from leaking through.
public struct MangaIconBadge: View {
    private let systemName: String
    private let isAccent: Bool
    private let size: CGFloat

    public init(systemName: String, isAccent: Bool = false, size: CGFloat = 32) {
        self.systemName = systemName
        self.isAccent = isAccent
        self.size = size
    }

    public var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.45, weight: .black))
            .foregroundStyle(isAccent ? Tokens.Colors.paper : Tokens.Colors.ink)
            .frame(width: size, height: size)
            .background(isAccent ? Tokens.Colors.accent : Tokens.Colors.paper)
            .overlay(
                Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular)
            )
            .contentShape(Rectangle())
    }
}

/// Pill-style action chip with icon + label, ink border + offset shadow.
/// Use as the label of a `Button` or `Menu` for primary screen actions.
public struct MangaActionChip: View {
    private let systemName: String
    private let title: Text
    private let isAccent: Bool

    public init(systemName: String, title: Text, isAccent: Bool = false) {
        self.systemName = systemName
        self.title = title
        self.isAccent = isAccent
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .black))
            title
                .font(Tokens.Typography.subtitle)
                .lineLimit(1)
        }
        .foregroundStyle(isAccent ? Tokens.Colors.paper : Tokens.Colors.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isAccent ? Tokens.Colors.accent : Tokens.Colors.paper)
        .overlay(
            Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular)
        )
        .background(
            Rectangle()
                .fill(Tokens.Colors.ink)
                .offset(x: 3, y: 3)
        )
        .contentShape(Rectangle())
    }
}

/// Text chip for toolbar buttons (Select/Done, etc).
/// Active state fills with hot-pink and inverts the foreground.
public struct MangaTextBadge: View {
    private let text: Text
    private let isActive: Bool

    public init(text: Text, isActive: Bool = false) {
        self.text = text
        self.isActive = isActive
    }

    public var body: some View {
        text
            .font(Tokens.Typography.subtitle)
            .foregroundStyle(isActive ? Tokens.Colors.paper : Tokens.Colors.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? Tokens.Colors.accent : Tokens.Colors.paper)
            .overlay(
                Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular)
            )
            .contentShape(Rectangle())
    }
}

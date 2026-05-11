import SwiftUI
import UIKit

/// Manga-style segmented toggle: ink-bordered cells with a hot-pink active fill,
/// matching the rest of the panel design. Drop-in replacement for `Picker(.segmented)`.
public struct MangaToggle<Value: Hashable>: View {
    @Binding private var selection: Value
    private let options: [(value: Value, label: Text)]
    private let showShadow: Bool

    public init(
        selection: Binding<Value>,
        options: [(Value, Text)],
        showShadow: Bool = true
    ) {
        self._selection = selection
        self.options = options.map { (value: $0.0, label: $0.1) }
        self.showShadow = showShadow
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                cell(for: option)
                if index < options.count - 1 {
                    Rectangle()
                        .fill(Tokens.Colors.ink)
                        .frame(width: Tokens.Stroke.regular)
                }
            }
        }
        .overlay(
            Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular)
        )
        .background(
            Group {
                if showShadow {
                    Rectangle()
                        .fill(Tokens.Colors.ink)
                        .offset(x: 3, y: 4)
                }
            }
        )
    }

    @ViewBuilder
    private func cell(for option: (value: Value, label: Text)) -> some View {
        let isSelected = selection == option.value
        Button {
            guard selection != option.value else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selection = option.value
        } label: {
            option.label
                .font(Tokens.Typography.subtitle)
                .foregroundStyle(isSelected ? Tokens.Colors.ink : Tokens.Colors.ink.opacity(0.55))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(isSelected ? Tokens.Colors.accent : Tokens.Colors.paper)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

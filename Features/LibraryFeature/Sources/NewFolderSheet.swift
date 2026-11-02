import SwiftUI
import DesignSystem

extension Bundle {
    /// Looks up a localized string honoring a SwiftUI environment `Locale`,
    /// independent of `Bundle.preferredLocalizations`.
    func localized(_ key: String, for locale: Locale) -> String {
        let langCode = locale.language.languageCode?.identifier ?? "en"
        if let path = path(forResource: langCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return localizedString(forKey: key, value: nil, table: nil)
    }
}

/// Text-entry dialog (new folder / rename folder / rename comic) shown in a `MangaDialogHost`.
/// Field label + inked text field + optional "SUGGESTED" quick-fill chips.
/// Ported from Android `ManaDialogs.NewFolderDialog`.
struct NameEntryDialog: View {
    @Binding var name: String
    let titleKey: String
    let submitKey: String
    let fieldLabelKey: String
    let placeholderKey: String
    var suggestions: [String] = []
    var onSubmit: () -> Void
    var onCancel: () -> Void

    @FocusState private var fieldFocused: Bool
    @Environment(\.locale) private var locale

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        MangaDialogPanel(
            title: Bundle.module.localized(titleKey, for: locale),
            cancelTitle: Bundle.module.localized("library.cancel", for: locale),
            confirmTitle: Bundle.module.localized(submitKey, for: locale),
            confirmIsAccent: canSubmit,
            onCancel: onCancel,
            onConfirm: { if canSubmit { onSubmit() } }
        ) {
            fieldBlock
        }
        .onAppear { fieldFocused = true }
    }

    private var fieldBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: Bundle.module.localized(fieldLabelKey, for: locale).uppercased())
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Colors.ink.opacity(0.7))

            TextField(
                Bundle.module.localized(placeholderKey, for: locale),
                text: $name
            )
            .focused($fieldFocused)
            .submitLabel(.done)
            .onSubmit { if canSubmit { onSubmit() } }
            .font(Tokens.Typography.title)
            .foregroundStyle(Tokens.Colors.ink)
            .tint(Tokens.Colors.accent)
            .padding(.horizontal, Tokens.Spacing.m)
            .padding(.vertical, Tokens.Spacing.s)
            .background(Tokens.Colors.paper)
            .overlay(
                Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular)
            )
            .background(
                Rectangle()
                    .fill(Tokens.Colors.ink)
                    .offset(x: 4, y: 5)
            )

            if !suggestions.isEmpty {
                Text(verbatim: Bundle.module.localized("library.suggested", for: locale).uppercased())
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Colors.ink.opacity(0.5))
                    .padding(.top, 9) // 4pt gap + clear the field's 5pt ink shadow
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Tokens.Spacing.s) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button { name = suggestion } label: {
                                Text(verbatim: suggestion)
                                    .font(Tokens.Typography.caption)
                                    .foregroundStyle(Tokens.Colors.ink)
                                    .lineLimit(1)
                                    .padding(.horizontal, Tokens.Spacing.s)
                                    .padding(.vertical, 6)
                                    .background(Tokens.Colors.paper)
                                    .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(MangaPressStyle(haptic: .tick, pressedScale: 0.97))
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

/// Manga dialog panel without the bottom button row (move-to / folder-cover pickers):
/// tilted title, then content. Same paper card, ink stroke and (6,7) shadow as `MangaDialogPanel`.
struct BareMangaDialogPanel<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.m) {
            SoundEffectText(
                title.uppercased(),
                font: Tokens.Typography.displayM,
                fill: Tokens.Colors.accent,
                stroke: Tokens.Colors.ink,
                strokeWidth: 4,
                tilt: -3,
                shadowOffset: .init(width: 3, height: 4)
            )
            content
        }
        .padding(Tokens.Spacing.l)
        .frame(maxWidth: 420)
        .background(Tokens.Colors.paper)
        .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular))
        .background(Rectangle().fill(Tokens.Colors.ink).offset(x: 6, y: 7))
    }
}

/// Vertical scroll view that hugs its content height up to `maxHeight`, then scrolls
/// (Compose `Modifier.heightIn(max =).verticalScroll()`).
struct CappedScrollView<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder var content: Content
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            content
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { contentHeight = proxy.size.height }
                            .onChange(of: proxy.size.height) { _, h in contentHeight = h }
                    }
                )
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: contentHeight > 0 ? min(contentHeight, maxHeight) : nil)
        .frame(maxHeight: maxHeight)
    }
}

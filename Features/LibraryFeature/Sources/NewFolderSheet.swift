import SwiftUI
import DesignSystem

public struct NewFolderSheetView: View {
    @Binding var name: String
    let titleKey: String
    let submitKey: String
    let placeholderKey: String
    var onSubmit: () -> Void
    var onCancel: () -> Void

    @FocusState private var fieldFocused: Bool

    public init(
        name: Binding<String>,
        titleKey: String = "library.new_folder",
        submitKey: String = "library.create",
        placeholderKey: String = "library.folder_name_placeholder",
        onSubmit: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._name = name
        self.titleKey = titleKey
        self.submitKey = submitKey
        self.placeholderKey = placeholderKey
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            Tokens.Colors.paper.ignoresSafeArea()
            HalftoneBackground().opacity(0.6).ignoresSafeArea()

            VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
                header
                fieldBlock
                Spacer(minLength: 0)
                buttonRow
            }
            .padding(Tokens.Spacing.l)
        }
        .presentationDetents([.medium])
        .presentationBackground(Tokens.Colors.paper)
        .presentationDragIndicator(.hidden)
        .onAppear { fieldFocused = true }
    }

    private var header: some View {
        SoundEffectText(
            sheetTitle.uppercased(),
            font: Tokens.Typography.displayM,
            fill: Tokens.Colors.accent,
            stroke: Tokens.Colors.ink,
            strokeWidth: 4,
            tilt: -3,
            shadowOffset: .init(width: 3, height: 4)
        )
    }

    private var sheetTitle: String {
        Bundle.module.localizedString(forKey: titleKey, value: nil, table: nil)
    }

    private var fieldBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "library.folder_name", bundle: .module))
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Colors.ink.opacity(0.7))
                .textCase(.uppercase)

            TextField(
                Bundle.module.localizedString(forKey: placeholderKey, value: nil, table: nil),
                text: $name
            )
            .focused($fieldFocused)
            .submitLabel(.done)
            .onSubmit {
                if !name.isEmpty { onSubmit() }
            }
            .font(Tokens.Typography.title)
            .foregroundStyle(Tokens.Colors.ink)
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
        }
    }

    private var buttonRow: some View {
        HStack(spacing: Tokens.Spacing.m) {
            Button(action: onCancel) {
                Text("library.cancel", bundle: .module)
                    .font(Tokens.Typography.title)
                    .foregroundStyle(Tokens.Colors.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Tokens.Colors.paper)
                    .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onSubmit) {
                Text(LocalizedStringKey(submitKey), bundle: .module)
                    .font(Tokens.Typography.title)
                    .foregroundStyle(name.isEmpty ? Tokens.Colors.ink.opacity(0.45) : Tokens.Colors.paper)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(name.isEmpty ? Tokens.Colors.paper : Tokens.Colors.accent)
                    .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular))
                    .background(
                        Rectangle()
                            .fill(Tokens.Colors.ink)
                            .offset(x: 4, y: 5)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(name.isEmpty)
        }
    }
}

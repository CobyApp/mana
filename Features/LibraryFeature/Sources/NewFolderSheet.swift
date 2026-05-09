import SwiftUI

public struct NewFolderSheetView: View {
    @Binding var name: String
    let titleKey: String
    let submitKey: String
    let placeholderKey: String
    var onSubmit: () -> Void
    var onCancel: () -> Void

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
        NavigationStack {
            Form {
                Section {
                    TextField(
                        Bundle.module.localizedString(forKey: placeholderKey, value: nil, table: nil),
                        text: $name
                    )
                } header: { Text("library.folder_name", bundle: .module) }
            }
            .navigationTitle(Text(LocalizedStringKey(titleKey), bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "library.cancel", bundle: .module), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onSubmit) {
                        Text(LocalizedStringKey(submitKey), bundle: .module)
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

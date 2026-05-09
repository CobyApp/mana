import SwiftUI

public struct NewFolderSheetView: View {
    @Binding var name: String
    var onSubmit: () -> Void
    var onCancel: () -> Void

    public init(name: Binding<String>, onSubmit: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self._name = name
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "library.folder_name_placeholder", bundle: .module), text: $name)
                } header: { Text("library.folder_name", bundle: .module) }
            }
            .navigationTitle(Text("library.new_folder", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "library.cancel", bundle: .module), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "library.create", bundle: .module), action: onSubmit).disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

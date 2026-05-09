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
                Section("Folder Name") {
                    TextField("e.g. Manga", text: $name)
                }
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: onSubmit).disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

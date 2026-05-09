import SwiftUI

public struct BookmarkSheet: View {
    let pageIndex: Int
    @Binding var note: String
    var onSubmit: () -> Void
    var onCancel: () -> Void

    public init(pageIndex: Int, note: Binding<String>, onSubmit: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.pageIndex = pageIndex
        self._note = note
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Page") {
                    Text("Page \(pageIndex + 1)")
                }
                Section("Note (optional)") {
                    TextField("e.g. great panel", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Add Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSubmit)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

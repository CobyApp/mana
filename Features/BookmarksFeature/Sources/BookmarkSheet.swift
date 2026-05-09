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
                Section {
                    Text("\(String(localized: "bookmarks.page", bundle: .module)) \(pageIndex + 1)")
                } header: { Text("bookmarks.page", bundle: .module) }
                Section {
                    TextField(String(localized: "bookmarks.note_placeholder", bundle: .module), text: $note, axis: .vertical)
                        .lineLimit(2...5)
                } header: { Text("bookmarks.note", bundle: .module) }
            }
            .navigationTitle(Text("bookmarks.add", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "bookmarks.cancel", bundle: .module), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "bookmarks.save", bundle: .module), action: onSubmit)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

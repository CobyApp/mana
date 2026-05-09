import SwiftUI
import ComposableArchitecture
import Domain

public struct BookmarksView: View {
    @Bindable public var store: StoreOf<BookmarksFeature>

    public init(store: StoreOf<BookmarksFeature>) { self.store = store }

    public var body: some View {
        List {
            if store.bookmarks.isEmpty {
                ContentUnavailableView {
                    Label { Text("bookmarks.empty", bundle: .module) } icon: { Image(systemName: "bookmark") }
                }
            } else {
                ForEach(store.bookmarks) { bm in
                    Button {
                        store.send(.tapped(bm))
                    } label: {
                        VStack(alignment: .leading) {
                            Text("\(String(localized: "bookmarks.page", bundle: .module)) \(bm.pageIndex + 1)").font(.headline)
                            if let note = bm.note, !note.isEmpty {
                                Text(note).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            store.send(.removeRequested(bm.id))
                        } label: { Label { Text("bookmarks.delete", bundle: .module) } icon: { Image(systemName: "trash") } }
                    }
                }
            }
        }
        .navigationTitle(Text("bookmarks.title", bundle: .module))
        .toolbar {
            if store.currentPageIndex != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.addSheetRequested)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { store.addSheet != nil },
                set: { if !$0 { store.send(.addSheetDismissed) } }
            )
        ) {
            if let sheet = store.addSheet {
                BookmarkSheet(
                    pageIndex: sheet.pageIndex,
                    note: Binding(
                        get: { sheet.note },
                        set: { store.send(.addSheetNoteChanged($0)) }
                    ),
                    onSubmit: { store.send(.addSheetSubmitted) },
                    onCancel: { store.send(.addSheetDismissed) }
                )
            }
        }
        .task { await store.send(.task).finish() }
    }
}

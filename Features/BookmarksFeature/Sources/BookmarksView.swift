import SwiftUI
import ComposableArchitecture
import Domain

public struct BookmarksView: View {
    @Bindable public var store: StoreOf<BookmarksFeature>

    public init(store: StoreOf<BookmarksFeature>) { self.store = store }

    public var body: some View {
        List {
            if store.bookmarks.isEmpty {
                ContentUnavailableView("No bookmarks", systemImage: "bookmark")
            } else {
                ForEach(store.bookmarks) { bm in
                    Button {
                        store.send(.tapped(bm))
                    } label: {
                        VStack(alignment: .leading) {
                            Text("Page \(bm.pageIndex + 1)").font(.headline)
                            if let note = bm.note, !note.isEmpty {
                                Text(note).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            store.send(.removeRequested(bm.id))
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .navigationTitle("Bookmarks")
        .task { await store.send(.task).finish() }
    }
}

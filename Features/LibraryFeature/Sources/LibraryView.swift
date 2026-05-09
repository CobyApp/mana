import SwiftUI
import ComposableArchitecture
import Domain
import UniformTypeIdentifiers

public struct LibraryView: View {
    @Bindable public var store: StoreOf<LibraryFeature>
    @State private var showImporter = false

    public init(store: StoreOf<LibraryFeature>) {
        self.store = store
    }

    public var body: some View {
        List {
            ForEach(store.displayedComics) { comic in
                Button {
                    store.send(.comicTapped(comic))
                } label: {
                    LibraryRow(comic: comic)
                }
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in
                // Map displayed index back to original index in `comics`.
                let ids = indexSet.map { store.displayedComics[$0].id }
                let originalIndices = ids.compactMap { id in store.comics.firstIndex(where: { $0.id == id }) }
                store.send(.delete(IndexSet(originalIndices)))
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    store.send(.settingsTapped)
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Sort", selection: Binding(
                        get: { store.sort },
                        set: { store.send(.sortChanged($0)) }
                    )) {
                        ForEach(LibrarySortOrder.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    Picker("Filter", selection: Binding(
                        get: { store.filter },
                        set: { store.send(.filterChanged($0)) }
                    )) {
                        ForEach(LibraryFilter.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showImporter = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(store.isImporting)
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [
                UTType(filenameExtension: "cbz") ?? .archive,
                UTType(filenameExtension: "cbr") ?? .archive,
                UTType(filenameExtension: "rar") ?? .archive,
                .zip,
                .pdf
            ],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls): store.send(.importPicked(urls))
            case .failure: break
            }
        }
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .overlay {
            if store.isImporting { ProgressView("Importing…") }
        }
    }
}

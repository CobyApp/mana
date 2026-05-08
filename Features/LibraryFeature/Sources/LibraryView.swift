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
            ForEach(store.comics) { comic in
                Button {
                    store.send(.comicTapped(comic))
                } label: {
                    LibraryRow(comic: comic)
                }
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in store.send(.delete(indexSet)) }
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

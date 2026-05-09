import SwiftUI
import ComposableArchitecture
import Domain
import DesignSystem
import UniformTypeIdentifiers

public struct LibraryView: View {
    @Bindable public var store: StoreOf<LibraryFeature>
    @State private var showImporter = false

    public init(store: StoreOf<LibraryFeature>) {
        self.store = store
    }

    public var body: some View {
        List {
            if store.currentFolderId == nil, !store.displayedFolders.isEmpty {
                foldersSection
            }

            if let folder = store.currentFolder {
                Section {
                    EmptyView()
                } header: {
                    HStack {
                        Button { store.send(.backToRoot) } label: {
                            Label {
                                Text("library.title", bundle: .module)
                            } icon: {
                                Image(systemName: "chevron.left")
                            }
                        }
                        Text("/").foregroundStyle(.secondary)
                        Text(folder.name).fontWeight(.semibold)
                    }
                    .dropDestination(for: ComicDragPayload.self) { payloads, _ in
                        for payload in payloads {
                            store.send(.comicMoveToFolderRequested(comicId: payload.comicId, folderId: nil))
                        }
                        return !payloads.isEmpty
                    }
                }
            }

            ForEach(store.displayedComics) { comic in
                Button {
                    store.send(.comicTapped(comic))
                } label: {
                    LibraryRow(comic: comic)
                }
                .buttonStyle(.plain)
                .draggable(ComicDragPayload(comicId: comic.id))
                .contextMenu {
                    moveMenu(for: comic)
                }
            }
            .onDelete { indexSet in store.send(.delete(indexSet)) }
        }
        .navigationTitle(store.currentFolder?.name ?? String(localized: "library.title", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { store.send(.settingsTapped) } label: { Image(systemName: "gearshape") }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { store.send(.newFolderRequested) } label: {
                        newFolderLabel
                    }
                    Button { showImporter = true } label: {
                        importLabel
                    }
                    Picker(selection: Binding(
                        get: { store.sort },
                        set: { store.send(.sortChanged($0)) }
                    ), label: Text("library.sort", bundle: .module)) {
                        ForEach(LibrarySortOrder.allCases, id: \.self) {
                            Text(LocalizedStringKey($0.localizationKey), bundle: .module).tag($0)
                        }
                    }
                    Picker(selection: Binding(
                        get: { store.filter },
                        set: { store.send(.filterChanged($0)) }
                    ), label: Text("library.filter", bundle: .module)) {
                        ForEach(LibraryFilter.allCases, id: \.self) {
                            Text(LocalizedStringKey($0.localizationKey), bundle: .module).tag($0)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [
                UTType(filenameExtension: "cbz") ?? .archive,
                UTType(filenameExtension: "cbr") ?? .archive,
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
        .dropDestination(for: URL.self) { urls, _ in
            store.send(.droppedURLs(urls))
            return true
        }
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .alert($store.scope(state: \.folderDeleteAlert, action: \.folderDeleteAlert))
        .overlay {
            if store.isImporting { ProgressView { Text("library.importing", bundle: .module) } }
        }
        .sheet(
            isPresented: Binding(
                get: { store.newFolderSheet != nil },
                set: { if !$0 { store.send(.newFolderSheetDismissed) } }
            )
        ) {
            if let sheet = store.newFolderSheet {
                NewFolderSheetView(
                    name: Binding(
                        get: { sheet.name },
                        set: { store.send(.newFolderNameChanged($0)) }
                    ),
                    onSubmit: { store.send(.newFolderSubmitted) },
                    onCancel: { store.send(.newFolderSheetDismissed) }
                )
            }
        }
    }

    private var newFolderLabel: some View {
        Label(title: { Text("library.new_folder", bundle: .module) }, icon: { Image(systemName: "folder.badge.plus") })
    }

    private var importLabel: some View {
        Label(title: { Text("library.import_dotdotdot", bundle: .module) }, icon: { Image(systemName: "doc.badge.plus") })
    }

    @ViewBuilder
    private var foldersSection: some View {
        let comics = store.comics
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Tokens.Spacing.m) {
                    ForEach(store.displayedFolders) { folder in
                        FolderCard(
                            folder: folder,
                            comicsInFolder: comics.filter { $0.folderId == folder.id },
                            onTap: { store.send(.folderTapped(folder)) },
                            onDelete: { store.send(.folderDeleteConfirmationRequested(folder.id)) },
                            onDropComic: { comicId in
                                store.send(.comicMoveToFolderRequested(comicId: comicId, folderId: folder.id))
                            }
                        )
                    }
                }
                .padding(.vertical, Tokens.Spacing.s)
            }
        } header: { Text("library.folders", bundle: .module) }
    }

    @ViewBuilder
    private func moveMenu(for comic: ComicItem) -> some View {
        Menu {
            Button {
                store.send(.comicMoveToFolderRequested(comicId: comic.id, folderId: nil))
            } label: { Text("library.move_to_root", bundle: .module) }
            ForEach(store.folders.elements) { folder in
                Button(folder.name) {
                    store.send(.comicMoveToFolderRequested(comicId: comic.id, folderId: folder.id))
                }
            }
        } label: {
            Label(title: { Text("library.move_to", bundle: .module) }, icon: { Image(systemName: "folder") })
        }
    }
}

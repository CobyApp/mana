import SwiftUI
import ComposableArchitecture
import Domain
import DesignSystem
import UniformTypeIdentifiers

public struct LibraryView: View {
    @Bindable public var store: StoreOf<LibraryFeature>
    @State private var showImporter = false

    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 16, alignment: .top)
    ]

    public init(store: StoreOf<LibraryFeature>) {
        self.store = store
    }

    public var body: some View {
        contentBody
            .overlay {
                if store.isImporting {
                    ProgressView { Text("library.importing", bundle: .module) }
                        .padding(Tokens.Spacing.l)
                        .background(.regularMaterial, in: .rect(cornerRadius: 12))
                }
            }
            .navigationTitle(store.currentFolder?.name ?? String(localized: "library.title", bundle: .module))
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    if store.currentFolderId != nil {
                        Button { store.send(.backToRoot) } label: {
                            Image(systemName: "chevron.left")
                        }
                    } else {
                        Button { store.send(.settingsTapped) } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }

                // Select / Done button — shows when there are comics
                if !store.displayedComics.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            store.send(.selectionModeToggled)
                        } label: {
                            Text(store.isSelecting
                                ? Bundle.module.localizedString(forKey: "library.done", value: nil, table: nil)
                                : Bundle.module.localizedString(forKey: "library.select", value: nil, table: nil)
                            )
                        }
                    }
                }

                if let folderId = store.currentFolderId {
                    if !store.isSelecting {
                        ToolbarItem(placement: .primaryAction) {
                            Button { store.send(.renameFolderRequested(folderId)) } label: {
                                Image(systemName: "pencil")
                            }
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button(role: .destructive) {
                                store.send(.folderDeleteConfirmationRequested(folderId))
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                } else {
                    if !store.isSelecting {
                        ToolbarItem(placement: .primaryAction) {
                            Menu {
                                Button { store.send(.newFolderRequested) } label: { newFolderLabel }
                                Button { showImporter = true } label: { importLabel }
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
            .alert($store.scope(state: \.bulkDeleteAlert, action: \.bulkDeleteAlert))
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
            .sheet(
                isPresented: Binding(
                    get: { store.renameFolderSheet != nil },
                    set: { if !$0 { store.send(.renameFolderSheetDismissed) } }
                )
            ) {
                if let sheet = store.renameFolderSheet {
                    NewFolderSheetView(
                        name: Binding(
                            get: { sheet.name },
                            set: { store.send(.renameFolderNameChanged($0)) }
                        ),
                        titleKey: "library.rename_folder",
                        submitKey: "library.save",
                        onSubmit: { store.send(.renameFolderSubmitted) },
                        onCancel: { store.send(.renameFolderSheetDismissed) }
                    )
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { store.renameComicSheet != nil },
                    set: { if !$0 { store.send(.renameComicSheetDismissed) } }
                )
            ) {
                if let sheet = store.renameComicSheet {
                    NewFolderSheetView(
                        name: Binding(
                            get: { sheet.title },
                            set: { store.send(.renameComicTitleChanged($0)) }
                        ),
                        titleKey: "library.rename_comic",
                        submitKey: "library.save",
                        placeholderKey: "library.comic_title_placeholder",
                        onSubmit: { store.send(.renameComicSubmitted) },
                        onCancel: { store.send(.renameComicSheetDismissed) }
                    )
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { store.bulkMoveSheet != nil },
                    set: { if !$0 { store.send(.bulkMoveSheetDismissed) } }
                )
            ) {
                if store.bulkMoveSheet != nil {
                    NavigationStack {
                        List {
                            Button {
                                store.send(.bulkMoveDestinationChosen(folderId: nil))
                            } label: {
                                Label {
                                    Text("library.move_to_root", bundle: .module)
                                } icon: {
                                    Image(systemName: "tray")
                                }
                            }
                            ForEach(store.folders.elements) { folder in
                                Button {
                                    store.send(.bulkMoveDestinationChosen(folderId: folder.id))
                                } label: {
                                    Label {
                                        Text(folder.name)
                                    } icon: {
                                        Image(systemName: "folder")
                                    }
                                }
                            }
                        }
                        .navigationTitle(Text("library.move_to", bundle: .module))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button {
                                    store.send(.bulkMoveSheetDismissed)
                                } label: {
                                    Text("library.cancel", bundle: .module)
                                }
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                }
            }
            .safeAreaInset(edge: .bottom) {
                if store.isSelecting && !store.selectedComicIds.isEmpty {
                    HStack(spacing: 16) {
                        Text(verbatim: String(
                            format: Bundle.module.localizedString(forKey: "library.selected_count", value: nil, table: nil),
                            store.selectedComicIds.count
                        ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            store.send(.bulkMoveRequested)
                        } label: {
                            Label {
                                Text("library.move_to", bundle: .module)
                            } icon: {
                                Image(systemName: "folder")
                            }
                        }

                        Button(role: .destructive) {
                            store.send(.bulkDeleteRequested)
                        } label: {
                            Label {
                                Text("library.delete", bundle: .module)
                            } icon: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                }
            }
    }

    private var isLibraryEmpty: Bool {
        store.currentFolderId == nil
            && store.displayedFolders.isEmpty
            && store.displayedComics.isEmpty
    }

    private var isFolderEmpty: Bool {
        store.currentFolderId != nil && store.displayedComics.isEmpty
    }

    @ViewBuilder
    private var contentBody: some View {
        if isLibraryEmpty {
            ContentUnavailableView {
                Label {
                    Text("library.empty.title", bundle: .module)
                } icon: {
                    Image(systemName: "books.vertical")
                }
            } description: {
                Text("library.empty.description", bundle: .module)
            } actions: {
                Button {
                    showImporter = true
                } label: {
                    Text("library.import_dotdotdot", bundle: .module)
                }
                .buttonStyle(.borderedProminent)
            }
        } else if isFolderEmpty {
            ContentUnavailableView {
                Label {
                    Text("library.folder_empty.title", bundle: .module)
                } icon: {
                    Image(systemName: "tray")
                }
            } description: {
                Text("library.folder_empty.description", bundle: .module)
            }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: Tokens.Spacing.l) {
                    if store.currentFolderId == nil {
                        ForEach(store.displayedFolders) { folder in
                            FolderCard(
                                folder: folder,
                                comicsInFolder: store.comics.filter { $0.folderId == folder.id },
                                onTap: { store.send(.folderTapped(folder)) },
                                onRename: { store.send(.renameFolderRequested(folder.id)) },
                                onDelete: { store.send(.folderDeleteConfirmationRequested(folder.id)) },
                                onDropComic: { comicId in
                                    store.send(.comicMoveToFolderRequested(comicId: comicId, folderId: folder.id))
                                }
                            )
                        }
                    }
                    ForEach(store.displayedComics) { comic in
                        Button {
                            if store.isSelecting {
                                store.send(.comicSelectionToggled(comic.id))
                            } else {
                                store.send(.comicTapped(comic))
                            }
                        } label: {
                            LibraryCell(
                                comic: comic,
                                isSelectionMode: store.isSelecting,
                                isSelected: store.selectedComicIds.contains(comic.id)
                            )
                        }
                        .buttonStyle(.plain)
                        .draggable(
                            ComicDragPayload(comicIds: dragPayloadFor(comic.id))
                        )
                        .contextMenu {
                            if !store.isSelecting {
                                Button {
                                    store.send(.renameComicRequested(comic.id))
                                } label: {
                                    Label {
                                        Text("library.rename_comic", bundle: .module)
                                    } icon: {
                                        Image(systemName: "pencil")
                                    }
                                }
                                moveMenu(for: comic)
                                Button(role: .destructive) {
                                    store.send(.deleteComicRequested(comic.id))
                                } label: {
                                    Label {
                                        Text("library.delete", bundle: .module)
                                    } icon: {
                                        Image(systemName: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(Tokens.Spacing.m)
            }
        }
    }

    private func dragPayloadFor(_ comicId: UUID) -> [UUID] {
        if store.isSelecting && store.selectedComicIds.contains(comicId) {
            return Array(store.selectedComicIds)
        } else {
            return [comicId]
        }
    }

    private var newFolderLabel: some View {
        Label(title: { Text("library.new_folder", bundle: .module) }, icon: { Image(systemName: "folder.badge.plus") })
    }

    private var importLabel: some View {
        Label(title: { Text("library.import_dotdotdot", bundle: .module) }, icon: { Image(systemName: "doc.badge.plus") })
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

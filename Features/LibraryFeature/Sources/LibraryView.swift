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
            .background(Tokens.Colors.paper.ignoresSafeArea())
            .toolbarBackground(Tokens.Colors.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(nil, for: .navigationBar)
            .overlay { if store.isImporting { importingOverlay } }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { libraryToolbar }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: importContentTypes,
                allowsMultipleSelection: true,
                onCompletion: handleImportResult
            )
            .dropDestination(for: URL.self, action: handleDrop)
            .task { await store.send(.task).finish() }
            .modifier(LibrarySheetsAndAlerts(store: store))
            .safeAreaInset(edge: .bottom) {
                if store.isSelecting && !store.selectedComicIds.isEmpty {
                    selectionActionBar
                }
            }
    }

    private var importContentTypes: [UTType] {
        [
            UTType(filenameExtension: "cbz") ?? .archive,
            UTType(filenameExtension: "cbr") ?? .archive,
            .zip,
            .pdf
        ]
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls): store.send(.importPicked(urls))
        case .failure: break
        }
    }

    private func handleDrop(_ urls: [URL], _ location: CGPoint) -> Bool {
        store.send(.droppedURLs(urls))
        return true
    }

    @ToolbarContentBuilder
    private var libraryToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            if store.currentFolderId != nil {
                Button { store.send(.backToRoot) } label: {
                    MangaIconBadge(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
            } else {
                Button { store.send(.settingsTapped) } label: {
                    MangaIconBadge(systemName: "gearshape.fill")
                }
                .buttonStyle(.plain)
            }
        }

        if !store.displayedComics.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                Button { store.send(.selectionModeToggled) } label: {
                    MangaTextBadge(
                        text: Text(store.isSelecting
                                   ? Bundle.module.localizedString(forKey: "library.done", value: nil, table: nil)
                                   : Bundle.module.localizedString(forKey: "library.select", value: nil, table: nil)),
                        isActive: store.isSelecting
                    )
                }
                .buttonStyle(.plain)
            }
        }

        folderActionToolbarItems
    }

    @ToolbarContentBuilder
    private var folderActionToolbarItems: some ToolbarContent {
        if let folderId = store.currentFolderId, !store.isSelecting {
            ToolbarItem(placement: .primaryAction) {
                Button { store.send(.renameFolderRequested(folderId)) } label: {
                    MangaIconBadge(systemName: "pencil")
                }
                .buttonStyle(.plain)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    store.send(.folderDeleteConfirmationRequested(folderId))
                } label: {
                    MangaIconBadge(systemName: "trash.fill", isAccent: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // Root-level actions (new folder / import / sort / filter) live in the
    // in-page action row below the big header — not in the toolbar.

    private var sortPicker: some View {
        Picker(selection: Binding(
            get: { store.sort },
            set: { store.send(.sortChanged($0)) }
        ), label: Text("library.sort", bundle: .module)) {
            ForEach(LibrarySortOrder.allCases, id: \.self) {
                Text(LocalizedStringKey($0.localizationKey), bundle: .module).tag($0)
            }
        }
    }

    private var filterPicker: some View {
        Picker(selection: Binding(
            get: { store.filter },
            set: { store.send(.filterChanged($0)) }
        ), label: Text("library.filter", bundle: .module)) {
            ForEach(LibraryFilter.allCases, id: \.self) {
                Text(LocalizedStringKey($0.localizationKey), bundle: .module).tag($0)
            }
        }
    }

    private var selectionActionBar: some View {
        HStack(spacing: Tokens.Spacing.m) {
            Text(verbatim: String(
                format: Bundle.module.localizedString(forKey: "library.selected_count", value: nil, table: nil),
                store.selectedComicIds.count
            ))
            .font(Tokens.Typography.mono)
            .foregroundStyle(Tokens.Colors.paper)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Tokens.Colors.ink)

            Spacer()

            Button {
                store.send(.bulkMoveRequested)
            } label: {
                Label {
                    Text("library.move_to", bundle: .module)
                        .font(Tokens.Typography.subtitle)
                } icon: {
                    Image(systemName: "folder.fill")
                }
                .foregroundStyle(Tokens.Colors.ink)
            }

            Button(role: .destructive) {
                store.send(.bulkDeleteRequested)
            } label: {
                Label {
                    Text("library.delete", bundle: .module)
                        .font(Tokens.Typography.subtitle)
                } icon: {
                    Image(systemName: "trash.fill")
                }
                .foregroundStyle(Tokens.Colors.paper)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Tokens.Colors.accent)
                .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.bold))
            }
        }
        .padding(Tokens.Spacing.m)
        .background(Tokens.Colors.paper)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Tokens.Colors.ink)
                .frame(height: Tokens.Stroke.bold)
        }
    }

    private var importingOverlay: some View {
        VStack(spacing: Tokens.Spacing.s) {
            SoundEffectText(
                "LOADING…",
                font: Tokens.Typography.displayM,
                fill: Tokens.Colors.accent,
                stroke: Tokens.Colors.ink,
                strokeWidth: 4,
                tilt: -4
            )
            ProgressView()
                .tint(Tokens.Colors.ink)
            Text("library.importing", bundle: .module)
                .font(Tokens.Typography.mono)
                .foregroundStyle(Tokens.Colors.ink)
        }
        .padding(Tokens.Spacing.l)
        .background(Tokens.Colors.paper)
        .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.panel))
        .background(Tokens.Colors.ink.offset(x: 5, y: 6))
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
            emptyLibraryState
        } else if isFolderEmpty {
            emptyFolderState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
                    bigHeader
                    if showsActionRow { actionRow }
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
                            ComicDragPayload(comicIds: dragPayloadFor(comic.id)),
                            preview: { dragPreview(for: comic) }
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
                }
                .padding(Tokens.Spacing.m)
            }
            .background(
                HalftoneBackground()
                    .opacity(0.7)
                    .ignoresSafeArea()
            )
        }
    }

    @ViewBuilder
    private var bigHeader: some View {
        let title: String = store.currentFolder?.name ?? String(localized: "library.title", bundle: .module)
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                SoundEffectText(
                    title.uppercased(),
                    font: Tokens.Typography.displayL,
                    fill: Tokens.Colors.accent,
                    stroke: Tokens.Colors.ink,
                    strokeWidth: 5,
                    tilt: -3,
                    shadowOffset: .init(width: 4, height: 5)
                )
                Text(headerSubtitle)
                    .font(Tokens.Typography.mono)
                    .foregroundStyle(Tokens.Colors.ink.opacity(0.7))
                    .padding(.leading, 4)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Spacing.s)
        .padding(.top, Tokens.Spacing.s)
    }

    private var showsActionRow: Bool {
        store.currentFolderId == nil && !store.isSelecting
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: Tokens.Spacing.s) {
            Button { store.send(.newFolderRequested) } label: {
                MangaActionChip(
                    systemName: "folder.badge.plus",
                    title: Text("library.new_folder", bundle: .module)
                )
            }
            .buttonStyle(.plain)

            Button { showImporter = true } label: {
                MangaActionChip(
                    systemName: "doc.badge.plus",
                    title: Text("library.import_dotdotdot", bundle: .module),
                    isAccent: true
                )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Menu {
                sortPicker
            } label: {
                MangaActionChip(
                    systemName: "arrow.up.arrow.down",
                    title: Text("library.sort", bundle: .module)
                )
            }
            .menuStyle(.button)
            .buttonStyle(.plain)

            Menu {
                filterPicker
            } label: {
                MangaActionChip(
                    systemName: "line.3.horizontal.decrease",
                    title: Text("library.filter", bundle: .module)
                )
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Tokens.Spacing.s)
    }

    private var headerSubtitle: String {
        let folderCount = store.currentFolderId == nil ? store.displayedFolders.count : 0
        let comicCount = store.displayedComics.count
        if folderCount > 0 {
            return "\(folderCount) FOLDERS · \(comicCount) COMICS"
        } else {
            return "\(comicCount) COMICS"
        }
    }

    private var emptyLibraryState: some View {
        ZStack {
            HalftoneBackground().ignoresSafeArea()
            VStack(spacing: Tokens.Spacing.l) {
                SoundEffectText(
                    "EMPTY!",
                    font: Tokens.Typography.displayXL,
                    fill: Tokens.Colors.accent,
                    stroke: Tokens.Colors.ink,
                    strokeWidth: 6,
                    tilt: -8,
                    shadowOffset: .init(width: 5, height: 7)
                )
                Text("library.empty.description", bundle: .module)
                    .font(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Colors.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Spacing.l)

                Button {
                    showImporter = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.badge.plus")
                        Text("library.import_dotdotdot", bundle: .module)
                            .font(Tokens.Typography.title)
                    }
                    .foregroundStyle(Tokens.Colors.paper)
                    .padding(.horizontal, Tokens.Spacing.l)
                    .padding(.vertical, Tokens.Spacing.s)
                    .background(Tokens.Colors.ink)
                    .overlay(
                        Rectangle()
                            .strokeBorder(Tokens.Colors.paper, lineWidth: 1.5)
                            .padding(3)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyFolderState: some View {
        ZStack {
            HalftoneBackground().ignoresSafeArea()
            VStack(spacing: Tokens.Spacing.m) {
                SoundEffectText(
                    "…SHIIN",
                    font: Tokens.Typography.displayL,
                    fill: Tokens.Colors.accentSecondary,
                    stroke: Tokens.Colors.ink,
                    strokeWidth: 5,
                    tilt: -5
                )
                Text("library.folder_empty.description", bundle: .module)
                    .font(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Colors.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Spacing.l)
            }
        }
    }

    /// Floating drag preview: stacked offset cards + count chip when more than one is grabbed.
    @ViewBuilder
    private func dragPreview(for comic: ComicItem) -> some View {
        let count = dragPayloadFor(comic.id).count
        ZStack(alignment: .topTrailing) {
            ZStack {
                if count > 2 {
                    dragCard(for: comic)
                        .rotationEffect(.degrees(-7))
                        .offset(x: -10, y: -6)
                        .opacity(0.8)
                }
                if count > 1 {
                    dragCard(for: comic)
                        .rotationEffect(.degrees(5))
                        .offset(x: 8, y: 4)
                        .opacity(0.9)
                }
                dragCard(for: comic)
            }

            if count > 1 {
                Text("×\(count)")
                    .font(Tokens.Typography.mono)
                    .foregroundStyle(Tokens.Colors.paper)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Tokens.Colors.accent)
                    .overlay(
                        Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular)
                    )
                    .offset(x: 14, y: -10)
            }
        }
        .frame(width: 120, height: 170)
    }

    @ViewBuilder
    private func dragCard(for comic: ComicItem) -> some View {
        ZStack {
            Tokens.Colors.paper
            if let data = comic.coverThumbnail, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(Tokens.Colors.ink)
            }
        }
        .frame(width: 110, height: 158)
        .overlay(
            Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.panel)
        )
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

// MARK: - Sheets and Alerts

private struct LibrarySheetsAndAlerts: ViewModifier {
    @Bindable var store: StoreOf<LibraryFeature>

    func body(content: Content) -> some View {
        content
            .alert($store.scope(state: \.alert, action: \.alert))
            .alert($store.scope(state: \.folderDeleteAlert, action: \.folderDeleteAlert))
            .alert($store.scope(state: \.bulkDeleteAlert, action: \.bulkDeleteAlert))
            .sheet(isPresented: newFolderBinding) {
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
            .sheet(isPresented: renameFolderBinding) {
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
            .sheet(isPresented: renameComicBinding) {
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
            .sheet(isPresented: bulkMoveBinding) {
                if store.bulkMoveSheet != nil {
                    BulkMoveSheet(store: store)
                }
            }
    }

    private var newFolderBinding: Binding<Bool> {
        Binding(
            get: { store.newFolderSheet != nil },
            set: { if !$0 { store.send(.newFolderSheetDismissed) } }
        )
    }

    private var renameFolderBinding: Binding<Bool> {
        Binding(
            get: { store.renameFolderSheet != nil },
            set: { if !$0 { store.send(.renameFolderSheetDismissed) } }
        )
    }

    private var renameComicBinding: Binding<Bool> {
        Binding(
            get: { store.renameComicSheet != nil },
            set: { if !$0 { store.send(.renameComicSheetDismissed) } }
        )
    }

    private var bulkMoveBinding: Binding<Bool> {
        Binding(
            get: { store.bulkMoveSheet != nil },
            set: { if !$0 { store.send(.bulkMoveSheetDismissed) } }
        )
    }
}

private struct BulkMoveSheet: View {
    @Bindable var store: StoreOf<LibraryFeature>

    var body: some View {
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

import SwiftUI
import ComposableArchitecture
import Domain
import DesignSystem
import AdKit
import UniformTypeIdentifiers

public struct LibraryView: View {
    @Bindable public var store: StoreOf<LibraryFeature>
    @State private var showImporter = false
    @State private var activePopover: ActivePopover? = nil
    @Environment(\.locale) private var locale

    private enum ActivePopover: Equatable { case sort }

    private var columns: [GridItem] {
        store.viewMode == .list
            ? [GridItem(.flexible(), spacing: 0, alignment: .top)]
            : [GridItem(.adaptive(minimum: 140), spacing: 16, alignment: .top)]
    }

    public init(store: StoreOf<LibraryFeature>) {
        self.store = store
    }

    public var body: some View {
        contentBody
            .background(Tokens.Colors.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .overlay { popoverOverlay }
            .overlayPreferenceValue(SortChipAnchorKey.self) { anchor in
                popoverPanelOverlay(anchor: anchor)
            }
            .animation(.easeOut(duration: 0.12), value: activePopover)
            .overlay { if store.isImporting { importingOverlay } }
            .overlay { dialogs }
            .sensoryFeedback(.success, trigger: store.importSuccessCount)
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: importContentTypes,
                allowsMultipleSelection: true,
                onCompletion: handleImportResult
            )
            .dropDestination(for: URL.self, action: handleDrop)
            .task { await store.send(.task).finish() }
            .onAppear { store.send(.onAppear) }
            .alert($store.scope(state: \.alert, action: \.alert))
            .safeAreaInset(edge: .bottom) {
                if store.isSelecting && !store.selectedComicIds.isEmpty {
                    selectionActionBar
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Hide the banner while the selection action bar is up to avoid
                // stacking two bars at the bottom of the screen.
                if !(store.isSelecting && !store.selectedComicIds.isEmpty) {
                    AdaptiveBannerView()
                }
            }
    }

    private var importContentTypes: [UTType] {
        [
            UTType(filenameExtension: "cbz") ?? .archive,
            UTType(filenameExtension: "cbr") ?? .archive,
            UTType(filenameExtension: "rar") ?? .archive,
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

    // MARK: - Header

    /// Root: [⚙] … [Downloads][Browse][Select]. Folder: [‹] … [☁][🖼][✏][🗑][Select].
    /// Everything except Select/Done hides while selecting. (Android `LibraryScreen` header.)
    @ViewBuilder
    private var headerBar: some View {
        HStack(spacing: Tokens.Spacing.s) {
            leadingButton
            Spacer(minLength: 0)
            if !store.isSelecting {
                if let folder = store.currentFolder {
                    if let source = folder.sourceURL {
                        headerIcon("icloud.and.arrow.down.fill") {
                            store.send(.openSourceSeries(url: source))
                        }
                    }
                    headerIcon("photo.fill") { store.send(.folderCoverRequested) }
                    headerIcon("pencil") { store.send(.renameFolderRequested(folder.id)) }
                    headerIcon("trash.fill", isAccent: true) {
                        store.send(.folderDeleteConfirmationRequested(folder.id))
                    }
                } else if store.currentFolderId == nil {
                    headerIcon("arrow.down.circle.fill") { store.send(.downloadsTapped) }
                    headerIcon("globe") { store.send(.browseTapped) }
                }
            }
            if !store.displayedComics.isEmpty || !store.displayedFolders.isEmpty {
                Button { store.send(.selectionModeToggled) } label: {
                    MangaTextBadge(
                        text: Text(store.isSelecting ? "library.done" : "library.select", bundle: .module),
                        isActive: store.isSelecting
                    )
                }
                .buttonStyle(MangaPressStyle(haptic: .tick))
            }
        }
        .padding(.horizontal, Tokens.Spacing.m)
        .padding(.top, Tokens.Spacing.s)
        .padding(.bottom, Tokens.Spacing.xs)
    }

    private func headerIcon(_ systemName: String, isAccent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MangaIconBadge(systemName: systemName, isAccent: isAccent)
        }
        .buttonStyle(MangaPressStyle(haptic: .tap))
    }

    @ViewBuilder
    private var leadingButton: some View {
        if store.currentFolderId != nil {
            headerIcon("chevron.left") { store.send(.backToRoot) }
        } else {
            headerIcon("gearshape.fill") { store.send(.settingsTapped) }
        }
    }

    // MARK: - Selection bar

    /// [count] … [✏ Rename (exactly 1)] [📁 Move to] [🗑 Delete]. (Android `SelectionActionBar`.)
    private var selectionActionBar: some View {
        HStack(spacing: Tokens.Spacing.s) {
            Text(verbatim: "\(store.selectedComicIds.count)")
                .font(Tokens.Typography.mono)
                .foregroundStyle(Tokens.Colors.paper)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Tokens.Colors.ink)
                .accessibilityLabel(Text(verbatim: String(
                    format: Bundle.module.localized("library.selected_count", for: locale),
                    store.selectedComicIds.count
                )))

            Spacer(minLength: 0)

            if store.selectedComicIds.count == 1, let only = store.selectedComicIds.first {
                Button { store.send(.renameComicRequested(only)) } label: {
                    MangaActionChip(systemName: "pencil", title: Text("library.rename", bundle: .module))
                }
                .buttonStyle(MangaPressStyle(haptic: .tap))
            }

            Button { store.send(.bulkMoveRequested) } label: {
                MangaActionChip(systemName: "folder.fill", title: Text("library.move_to", bundle: .module))
            }
            .buttonStyle(MangaPressStyle(haptic: .tap))

            Button { store.send(.bulkDeleteRequested) } label: {
                MangaActionChip(
                    systemName: "trash.fill",
                    title: Text("library.delete", bundle: .module),
                    isAccent: true
                )
            }
            .buttonStyle(MangaPressStyle(haptic: .tap))
        }
        .padding(Tokens.Spacing.m)
        .background(Tokens.Colors.paper)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Tokens.Colors.ink)
                .frame(height: Tokens.Stroke.bold)
        }
    }

    // MARK: - Importing overlay

    private var importingOverlay: some View {
        ZStack {
            Tokens.Colors.ink.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: Tokens.Spacing.s) {
                SoundEffectText(
                    "LOADING…",
                    font: Tokens.Typography.displayM,
                    fill: Tokens.Colors.accent,
                    stroke: Tokens.Colors.ink,
                    strokeWidth: 4,
                    tilt: -4,
                    shadowOffset: .init(width: 4, height: 4)
                )
                .glitchPulse(every: 0.9, intensity: 10)
                Text("library.importing", bundle: .module)
                    .font(Tokens.Typography.mono)
                    .foregroundStyle(Tokens.Colors.ink)
            }
            .padding(Tokens.Spacing.l)
            .background {
                // Speed-line burst behind the loading title.
                SpeedLines(color: Tokens.Colors.accent.opacity(0.18), lineCount: 44)
                    .clipped()
            }
            .background(Tokens.Colors.paper)
            .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.panel))
            .background(Tokens.Colors.ink.offset(x: 5, y: 6))
        }
    }

    // MARK: - Content

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
        VStack(spacing: 0) {
            headerBar
            innerContent
        }
    }

    @ViewBuilder
    private var innerContent: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.m) {
            bigHeader
                .padding(.horizontal, Tokens.Spacing.m)
            if showsActionRow {
                actionRow
                    .padding(.horizontal, Tokens.Spacing.m)
            }
            if store.currentFolderId == nil, !store.isSelecting, let resume = store.continueReading {
                ContinueReadingBanner(comic: resume.comic, progress: resume.progress) {
                    store.send(.comicTapped(resume.comic))
                }
                .padding(.horizontal, Tokens.Spacing.m)
                .padding(.trailing, 5) // room for the hard ink shadow
            }
            folderTransitionContainer
        }
    }

    /// Folder enter/exit: direction-aware slide + fade (Android `AnimatedContent`
    /// "folderTransition"). Root always leaves/returns on the leading side and a folder always
    /// enters/leaves on the trailing side, so each view's transition is static.
    private var folderTransitionContainer: some View {
        ZStack {
            grid
                .id(store.currentFolderId)
                .transition(store.currentFolderId == nil ? Self.rootTransition : Self.folderTransition)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .animation(.easeOut(duration: 0.25), value: store.currentFolderId)
    }

    private static let rootTransition: AnyTransition = .asymmetric(
        insertion: .offset(x: -60).combined(with: .opacity.animation(.easeOut(duration: 0.22))),
        removal: .offset(x: -60).combined(with: .opacity.animation(.easeOut(duration: 0.15)))
    )

    private static let folderTransition: AnyTransition = .asymmetric(
        insertion: .offset(x: 60).combined(with: .opacity.animation(.easeOut(duration: 0.22))),
        removal: .offset(x: 60).combined(with: .opacity.animation(.easeOut(duration: 0.15)))
    )

    @ViewBuilder
    private var grid: some View {
        if !store.hasLoaded && isLibraryEmpty {
            ManaLoader()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isLibraryEmpty {
            emptyState(isRoot: true)
        } else if isFolderEmpty {
            emptyState(isRoot: false)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
                    LazyVGrid(columns: columns, spacing: store.viewMode == .list ? Tokens.Spacing.s : Tokens.Spacing.l) {
                        if store.currentFolderId == nil {
                            ForEach(store.displayedFolders) { folder in
                                folderItem(folder)
                            }
                        }
                        ForEach(store.displayedComics) { comic in
                            comicItem(comic)
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
    private func folderItem(_ folder: Folder) -> some View {
        let cover = store.state.coverData(for: folder)
        let count = store.state.comicCount(in: folder.id)
        let onDrop: (UUID) -> Void = { comicId in
            store.send(.comicMoveToFolderRequested(comicId: comicId, folderId: folder.id))
        }
        if store.viewMode == .list {
            FolderListRow(
                folder: folder,
                cover: cover,
                comicCount: count,
                onTap: { store.send(.folderTapped(folder)) },
                onLongPress: { store.send(.folderDeleteConfirmationRequested(folder.id)) },
                onDropComic: onDrop
            )
        } else {
            FolderCard(
                folder: folder,
                cover: cover,
                count: count,
                onTap: { store.send(.folderTapped(folder)) },
                onLongPress: { store.send(.folderDeleteConfirmationRequested(folder.id)) },
                onDropComic: onDrop
            )
        }
    }

    /// Tap opens (or toggles in selection mode). Long-press enters selection mode with this comic
    /// selected (Android). In selection mode the long-press is disabled so the system context
    /// menu (rename / move / delete) and drag-to-folder take over the hold.
    @ViewBuilder
    private func comicItem(_ comic: ComicItem) -> some View {
        Group {
            if store.viewMode == .list {
                LibraryListRow(
                    comic: comic,
                    progress: store.progresses[comic.id],
                    isSelectionMode: store.isSelecting,
                    isSelected: store.selectedComicIds.contains(comic.id)
                )
            } else {
                LibraryCell(
                    comic: comic,
                    progress: store.progresses[comic.id],
                    isSelectionMode: store.isSelecting,
                    isSelected: store.selectedComicIds.contains(comic.id)
                )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if store.isSelecting {
                MangaHaptic.tick.play()
                store.send(.comicSelectionToggled(comic.id))
            } else {
                MangaHaptic.tap.play()
                store.send(.comicTapped(comic))
            }
        }
        .gesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                MangaHaptic.longPress.play()
                store.send(.comicLongPressed(comic.id))
            },
            including: store.isSelecting ? .subviews : .all
        )
        .draggable(
            ComicDragPayload(comicIds: dragPayloadFor(comic.id)),
            preview: { dragPreview(for: comic) }
        )
        .contextMenu {
            if store.isSelecting {
                Button {
                    store.send(.renameComicRequested(comic.id))
                } label: {
                    Label {
                        Text("library.rename", bundle: .module)
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

    @ViewBuilder
    private var bigHeader: some View {
        let title: String = store.currentFolder?.name ?? Bundle.module.localized("library.title", for: locale)
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
        !store.isSelecting
    }

    // MARK: - Action row

    /// [📁+ New folder] [📄+ Import…] … [list/grid toggle] [sort]. (Android action row.)
    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: Tokens.Spacing.s) {
            Button { store.send(.newFolderRequested) } label: {
                MangaActionChip(
                    systemName: "folder.badge.plus",
                    title: Text("library.new_folder", bundle: .module)
                )
            }
            .buttonStyle(MangaPressStyle(haptic: .tap))

            Button { showImporter = true } label: {
                MangaActionChip(
                    systemName: "doc.badge.plus",
                    title: Text("library.import_dotdotdot", bundle: .module),
                    isAccent: true
                )
            }
            .buttonStyle(MangaPressStyle(haptic: .confirm))

            Spacer(minLength: 0)

            Button { store.send(.viewModeToggled) } label: {
                MangaActionChip(systemName: store.viewMode == .grid ? "list.bullet" : "square.grid.2x2.fill")
            }
            .buttonStyle(MangaPressStyle(haptic: .tick))
            .accessibilityLabel(Text(verbatim: store.viewMode == .grid ? "List" : "Grid"))

            Button { activePopover = (activePopover == .sort) ? nil : .sort } label: {
                MangaActionChip(systemName: "arrow.up.arrow.down")
            }
            .buttonStyle(MangaPressStyle(haptic: .tap))
            .accessibilityLabel(Text("library.sort", bundle: .module))
            .anchorPreference(key: SortChipAnchorKey.self, value: .bounds) { $0 }
        }
        .padding(.horizontal, Tokens.Spacing.s)
    }

    private var sortPopover: some View {
        popoverPanel {
            ForEach(Array(LibrarySortOrder.allCases.enumerated()), id: \.offset) { index, sort in
                popoverRow(
                    title: Text(LocalizedStringKey(sort.localizationKey), bundle: .module),
                    isSelected: store.sort == sort
                ) {
                    store.send(.sortChanged(sort))
                    activePopover = nil
                }
                if index < LibrarySortOrder.allCases.count - 1 {
                    Rectangle().fill(Tokens.Colors.ink.opacity(0.15)).frame(height: Tokens.Stroke.hair)
                }
            }
        }
        .frame(width: 240)
    }

    @ViewBuilder
    private func popoverPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .background(Tokens.Colors.paper)
        .overlay(
            Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular)
        )
        .background(
            Rectangle()
                .fill(Tokens.Colors.ink)
                .offset(x: 4, y: 5)
        )
    }

    @ViewBuilder
    private var popoverOverlay: some View {
        if activePopover != nil {
            Color.black.opacity(0.0001)
                .ignoresSafeArea()
                .onTapGesture { activePopover = nil }
        }
    }

    /// Sort menu anchored just below the sort chip, right-aligned to it.
    @ViewBuilder
    private func popoverPanelOverlay(anchor: Anchor<CGRect>?) -> some View {
        GeometryReader { proxy in
            if activePopover == .sort, let anchor, showsActionRow {
                let rect = proxy[anchor]
                sortPopover
                    .offset(x: max(Tokens.Spacing.m, rect.maxX - 240), y: rect.maxY + Tokens.Spacing.s)
                    .transition(.scale(scale: 0.9, anchor: .topTrailing).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private func popoverRow(title: Text, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.s) {
                title
                    .font(Tokens.Typography.subtitle)
                    .foregroundStyle(isSelected ? Tokens.Colors.paper : Tokens.Colors.ink)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Tokens.Colors.paper)
                }
            }
            .padding(.horizontal, Tokens.Spacing.m)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Tokens.Colors.accent : Tokens.Colors.paper)
            .contentShape(Rectangle())
        }
        .buttonStyle(MangaPressStyle(haptic: .tick, pressedScale: 0.98))
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

    // MARK: - Empty states

    /// Root: "EMPTY!" + import hint + Import… chip. Folder: "…SHIIN" + "This folder is empty."
    private func emptyState(isRoot: Bool) -> some View {
        ZStack {
            HalftoneBackground()
            VStack(spacing: 0) {
                SoundEffectText(
                    isRoot ? "EMPTY!" : "…SHIIN",
                    font: Tokens.Typography.displayXL,
                    fill: Tokens.Colors.accent,
                    stroke: Tokens.Colors.ink,
                    strokeWidth: 6,
                    tilt: -8,
                    shadowOffset: .init(width: 5, height: 7)
                )
                .glitchPulse(every: 2.6, intensity: 9)
                Text(isRoot ? "library.empty.description" : "library.folder_empty.description", bundle: .module)
                    .font(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Colors.ink)
                    .multilineTextAlignment(.center)
                    .padding(Tokens.Spacing.l)
                if isRoot {
                    Button { showImporter = true } label: {
                        MangaActionChip(
                            systemName: "doc.badge.plus",
                            title: Text("library.import_dotdotdot", bundle: .module),
                            isAccent: true
                        )
                    }
                    .buttonStyle(MangaPressStyle(haptic: .confirm))
                }
            }
            .padding(.bottom, 80)
        }
    }

    // MARK: - Drag

    /// Floating drag preview: stacked offset cards + count chip when more than one is grabbed.
    @ViewBuilder
    private func dragPreview(for comic: ComicItem) -> some View {
        let count = dragPayloadFor(comic.id).count
        ZStack(alignment: .topTrailing) {
            ZStack {
                if count > 2 {
                    dragCard(for: comic)
                        .rotationEffect(.degrees(-14))
                        .offset(x: -22, y: -12)
                        .opacity(0.85)
                }
                if count > 1 {
                    dragCard(for: comic)
                        .rotationEffect(.degrees(10))
                        .offset(x: 18, y: 8)
                        .opacity(0.92)
                }
                dragCard(for: comic)
            }
            .frame(width: 130, height: 186)
            .padding(36)

            if count > 1 {
                Text("×\(count)")
                    .font(Tokens.Typography.monoLarge)
                    .foregroundStyle(Tokens.Colors.paper)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Tokens.Colors.accent)
                    .overlay(
                        Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.bold)
                    )
                    .offset(x: -8, y: 8)
            }
        }
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
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(Tokens.Colors.ink)
            }
        }
        .frame(width: 130, height: 186)
        .overlay(
            Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.panel)
        )
        .background(
            Rectangle()
                .fill(Tokens.Colors.ink)
                .offset(x: 4, y: 5)
        )
    }

    private func dragPayloadFor(_ comicId: UUID) -> [UUID] {
        if store.isSelecting && store.selectedComicIds.contains(comicId) {
            return Array(store.selectedComicIds)
        } else {
            return [comicId]
        }
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

    // MARK: - Dialogs

    @ViewBuilder
    private var dialogs: some View {
        ZStack {
            confirmDialogHost
            newFolderDialogHost
            renameFolderDialogHost
            renameComicDialogHost
            moveToDialogHost
            folderCoverDialogHost
        }
    }

    private var confirmDialogHost: some View {
        MangaDialogHost(
            isPresented: store.confirmDialog != nil,
            onDismiss: { store.send(.confirmDialogDismissed) }
        ) {
            if let dialog = store.confirmDialog {
                MangaDialogPanel(
                    title: confirmTitle(dialog),
                    message: confirmMessage(dialog),
                    cancelTitle: Bundle.module.localized("library.cancel", for: locale),
                    confirmTitle: Bundle.module.localized("library.delete", for: locale),
                    onCancel: { store.send(.confirmDialogDismissed) },
                    onConfirm: { store.send(.confirmDialogConfirmed) }
                )
            }
        }
    }

    private func confirmTitle(_ dialog: LibraryFeature.State.ConfirmDialog) -> String {
        switch dialog {
        case .folderDelete:
            return Bundle.module.localized("library.delete_folder_title", for: locale)
        case .bulkDelete, .comicDelete:
            return Bundle.module.localized("library.bulk_delete_title", for: locale)
        }
    }

    private func confirmMessage(_ dialog: LibraryFeature.State.ConfirmDialog) -> String {
        switch dialog {
        case let .folderDelete(_, folderName, _):
            return String(
                format: Bundle.module.localized("library.delete_folder_message", for: locale),
                folderName
            )
        case let .bulkDelete(count):
            return String(
                format: Bundle.module.localized("library.bulk_delete_message", for: locale),
                count
            )
        case let .comicDelete(_, title):
            return String(
                format: Bundle.module.localized("library.delete_comic_message", for: locale),
                title
            )
        }
    }

    private var newFolderDialogHost: some View {
        MangaDialogHost(
            isPresented: store.newFolderSheet != nil,
            onDismiss: { store.send(.newFolderSheetDismissed) }
        ) {
            if let sheet = store.newFolderSheet {
                NameEntryDialog(
                    name: Binding(
                        get: { sheet.name },
                        set: { store.send(.newFolderNameChanged($0)) }
                    ),
                    titleKey: "library.new_folder",
                    submitKey: "library.create",
                    fieldLabelKey: "library.folder_name",
                    placeholderKey: "library.folder_name_placeholder",
                    suggestions: store.state.folderNameSuggestions,
                    onSubmit: { store.send(.newFolderSubmitted) },
                    onCancel: { store.send(.newFolderSheetDismissed) }
                )
            }
        }
    }

    private var renameFolderDialogHost: some View {
        MangaDialogHost(
            isPresented: store.renameFolderSheet != nil,
            onDismiss: { store.send(.renameFolderSheetDismissed) }
        ) {
            if let sheet = store.renameFolderSheet {
                NameEntryDialog(
                    name: Binding(
                        get: { sheet.name },
                        set: { store.send(.renameFolderNameChanged($0)) }
                    ),
                    titleKey: "library.rename_folder",
                    submitKey: "library.save",
                    fieldLabelKey: "library.folder_name",
                    placeholderKey: "library.folder_name_placeholder",
                    onSubmit: { store.send(.renameFolderSubmitted) },
                    onCancel: { store.send(.renameFolderSheetDismissed) }
                )
            }
        }
    }

    private var renameComicDialogHost: some View {
        MangaDialogHost(
            isPresented: store.renameComicSheet != nil,
            onDismiss: { store.send(.renameComicSheetDismissed) }
        ) {
            if let sheet = store.renameComicSheet {
                NameEntryDialog(
                    name: Binding(
                        get: { sheet.title },
                        set: { store.send(.renameComicTitleChanged($0)) }
                    ),
                    titleKey: "library.rename_comic",
                    submitKey: "library.save",
                    fieldLabelKey: "library.comic_title",
                    placeholderKey: "library.comic_title_placeholder",
                    onSubmit: { store.send(.renameComicSubmitted) },
                    onCancel: { store.send(.renameComicSheetDismissed) }
                )
            }
        }
    }

    /// "MOVE TO": [tray] Library (root), then one row per folder; scrolls past 320pt.
    /// (Android `ManaDialogs.MoveToDialog`.)
    private var moveToDialogHost: some View {
        MangaDialogHost(
            isPresented: store.bulkMoveSheet != nil,
            onDismiss: { store.send(.bulkMoveSheetDismissed) }
        ) {
            if store.bulkMoveSheet != nil {
                BareMangaDialogPanel(title: Bundle.module.localized("library.move_to", for: locale)) {
                    CappedScrollView(maxHeight: 320) {
                        VStack(spacing: Tokens.Spacing.s) {
                            moveRow(systemName: "tray.fill", title: Bundle.module.localized("library.root", for: locale)) {
                                store.send(.bulkMoveDestinationChosen(folderId: nil))
                            }
                            ForEach(store.state.displayedFoldersForMove) { folder in
                                moveRow(systemName: "folder.fill", title: folder.name) {
                                    store.send(.bulkMoveDestinationChosen(folderId: folder.id))
                                }
                            }
                        }
                        .padding(.trailing, 2)
                    }
                }
            }
        }
    }

    private func moveRow(systemName: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.s) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Tokens.Colors.ink)
                    .frame(width: 20)
                Text(verbatim: title)
                    .font(Tokens.Typography.subtitle)
                    .foregroundStyle(Tokens.Colors.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Tokens.Spacing.m)
            .padding(.vertical, Tokens.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.Colors.paper)
            .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular))
            .contentShape(Rectangle())
        }
        .buttonStyle(MangaPressStyle(haptic: .tick, pressedScale: 0.98))
    }

    /// "FOLDER COVER": 3-column grid of this folder's comic covers (tap to use), plus
    /// "Use default" when a custom cover is set. (Android `ManaDialogs.FolderCoverDialog`.)
    private var folderCoverDialogHost: some View {
        MangaDialogHost(
            isPresented: store.isFolderCoverPickerPresented,
            onDismiss: { store.send(.folderCoverDismissed) }
        ) {
            if store.isFolderCoverPickerPresented {
                let withCovers = store.displayedComics.filter { $0.coverThumbnail != nil }
                BareMangaDialogPanel(title: Bundle.module.localized("library.folder_cover", for: locale)) {
                    if withCovers.isEmpty {
                        Text("library.cover_empty", bundle: .module)
                            .font(Tokens.Typography.body)
                            .foregroundStyle(Tokens.Colors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("library.cover_pick", bundle: .module)
                            .font(Tokens.Typography.caption)
                            .foregroundStyle(Tokens.Colors.ink.opacity(0.7))
                        CappedScrollView(maxHeight: 340) {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Spacing.s), count: 3),
                                spacing: Tokens.Spacing.s
                            ) {
                                ForEach(withCovers) { comic in
                                    coverPickCell(comic)
                                }
                            }
                        }
                    }
                    if store.currentFolder?.coverImage != nil {
                        MangaDialogButton(
                            title: Bundle.module.localized("library.cover_reset", for: locale),
                            isAccent: false
                        ) {
                            store.send(.folderCoverReset)
                        }
                    }
                }
            }
        }
    }

    private func coverPickCell(_ comic: ComicItem) -> some View {
        Button { store.send(.folderCoverPicked(comicId: comic.id)) } label: {
            Color.clear
                .aspectRatio(0.7, contentMode: .fit)
                .overlay {
                    if let data = comic.coverThumbnail, let img = UIImage(data: data) {
                        Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                    }
                }
                .clipped()
                .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular))
                .contentShape(Rectangle())
        }
        .buttonStyle(MangaPressStyle(haptic: .tap, pressedScale: 0.96))
        .accessibilityLabel(Text(comic.title))
    }
}

/// Bounds of the sort chip, so the sort popover can anchor right below it.
private struct SortChipAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

private extension LibraryFeature.State {
    /// Every folder (newest first) as a move destination, regardless of the current level.
    var displayedFoldersForMove: [Folder] {
        folders.elements.sorted { $0.dateAdded > $1.dateAdded }
    }
}

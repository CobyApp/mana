import Foundation
import ComposableArchitecture
import Domain

public protocol LibraryImporter: Sendable {
    func importFiles(_ urls: [URL], folderId: UUID?) async throws -> [ComicItem]
}

public extension Notification.Name {
    /// Posted once the on-disk library has been reconciled with the catalog at
    /// app launch. The library view listens for this and reloads.
    static let manaLibraryReconciled = Notification.Name("com.coby.mana.libraryReconciled")
    /// Posted by the reader whenever a comic's reading progress is persisted.
    /// The library listens for this so the per-cover progress bar stays fresh.
    static let manaProgressUpdated = Notification.Name("com.coby.mana.progressUpdated")
}

@Reducer
public struct LibraryFeature {
    public init() {}

    public static let viewModeKey = "mana.libraryViewMode"
    public static let sortKey = "mana.librarySort"

    public struct NewFolderSheet: Equatable, Sendable {
        public struct State: Equatable, Sendable {
            public var name: String

            public init(name: String = "") {
                self.name = name
            }
        }
    }

    public struct RenameFolderSheet: Equatable, Sendable {
        public struct State: Equatable, Sendable {
            public let folderId: UUID
            public var name: String
        }
    }

    public struct RenameComicSheet: Equatable, Sendable {
        public struct State: Equatable, Sendable {
            public let comicId: UUID
            public var title: String
        }
    }

    public struct BulkMoveSheet: Equatable, Sendable {
        public struct State: Equatable, Sendable {
            public let comicIds: [UUID]
        }
    }

    @ObservableState
    public struct State: Equatable {
        public var comics: IdentifiedArrayOf<ComicItem> = []
        public var folders: IdentifiedArrayOf<Folder> = []
        public var progresses: [UUID: ReadingProgress] = [:]
        public var currentFolderId: UUID?
        public var isImporting: Bool = false
        public var sort: LibrarySortOrder = .dateAddedDesc
        public var filter: LibraryFilter = .all
        public var newFolderSheet: NewFolderSheet.State?
        public var renameFolderSheet: RenameFolderSheet.State?
        public var renameComicSheet: RenameComicSheet.State?
        public var isSelecting: Bool = false
        public var selectedComicIds: Set<UUID> = []
        public var bulkMoveSheet: BulkMoveSheet.State?
        @Presents public var alert: AlertState<Action.Alert>?
        public var confirmDialog: ConfirmDialog?
        /// Cover grid or compact list; persisted under `LibraryFeature.viewModeKey`.
        public var viewMode: LibraryViewMode = .grid
        /// False until the first catalog load lands, so the view shows a loader instead of
        /// flashing the empty state.
        public var hasLoaded: Bool = false
        /// Folder-cover picker dialog (inside a folder).
        public var isFolderCoverPickerPresented: Bool = false
        /// Bumped whenever an import adds comics; the view plays a success haptic on change.
        public var importSuccessCount: Int = 0

        public enum ConfirmDialog: Equatable, Sendable {
            case folderDelete(folderId: UUID, folderName: String, comicCount: Int)
            case bulkDelete(count: Int)
            case comicDelete(comicId: UUID, title: String)
        }

        public init(
            comics: IdentifiedArrayOf<ComicItem> = [],
            folders: IdentifiedArrayOf<Folder> = [],
            currentFolderId: UUID? = nil,
            isImporting: Bool = false,
            sort: LibrarySortOrder = .dateAddedDesc,
            filter: LibraryFilter = .all
        ) {
            self.comics = comics
            self.folders = folders
            self.currentFolderId = currentFolderId
            self.isImporting = isImporting
            self.sort = sort
            self.filter = filter
        }

        public var displayedFolders: [Folder] {
            // Folders are only shown at the root level (no nesting).
            currentFolderId == nil
                ? folders.elements.sorted { $0.dateAdded > $1.dateAdded }
                : []
        }

        public var displayedComics: [ComicItem] {
            let scoped = comics.filter { $0.folderId == currentFolderId }
            let filtered: [ComicItem] = scoped.filter { item in
                switch filter {
                case .all: return true
                case .zip: return item.format == .zip || item.format == .cbz
                case .rar: return item.format == .rar || item.format == .cbr
                case .pdf: return item.format == .pdf
                }
            }
            switch sort {
            case .dateAddedDesc: return filtered.sorted { $0.dateAdded > $1.dateAdded }
            case .dateAddedAsc: return filtered.sorted { $0.dateAdded < $1.dateAdded }
            // `localizedStandardCompare` is natural order ("Chapter 2" < "Chapter 10").
            case .titleAsc: return filtered.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            case .titleDesc: return filtered.sorted { $0.title.localizedStandardCompare($1.title) == .orderedDescending }
            case .pageCountDesc: return filtered.sorted { ($0.pageCount ?? 0) > ($1.pageCount ?? 0) }
            case .fileSizeDesc: return filtered.sorted { $0.fileSizeBytes > $1.fileSizeBytes }
            }
        }

        /// Cover shown for a folder: its custom cover, else the most recently added comic in it
        /// that has a cover thumbnail.
        public func coverData(for folder: Folder) -> Data? {
            if let custom = folder.coverImage { return custom }
            return comics
                .filter { $0.folderId == folder.id && $0.coverThumbnail != nil }
                .max { $0.dateAdded < $1.dateAdded }?
                .coverThumbnail
        }

        public func comicCount(in folderId: UUID) -> Int {
            comics.reduce(0) { $0 + ($1.folderId == folderId ? 1 : 0) }
        }

        /// Quick-fill names for the New Folder dialog, derived from the visible comics' titles.
        public var folderNameSuggestions: [String] {
            LibraryFeature.folderNameSuggestions(
                titles: displayedComics.map(\.title),
                existingFolders: folders.map(\.name)
            )
        }

        public var currentFolder: Folder? {
            guard let id = currentFolderId else { return nil }
            return folders[id: id]
        }

        /// The most recently read comic (even if finished), for the "continue reading" banner
        /// (Android `LibraryViewModel`: `progress.maxByOrNull { updatedAt }`).
        public var continueReading: (comic: ComicItem, progress: ReadingProgress)? {
            let candidates = progresses.values
                .sorted { $0.updatedAt > $1.updatedAt }
            for p in candidates {
                if let comic = comics[id: p.comicId] { return (comic, p) }
            }
            return nil
        }
    }

    public enum Action {
        case task
        case onAppear
        case refreshed([ComicItem])
        case foldersRefreshed([Folder])
        case progressesRefreshed([ReadingProgress])
        case importTapped
        case importPicked([URL])
        case droppedURLs([URL])
        case imported([ComicItem])
        case importFailed(String)
        case comicTapped(ComicItem)
        case settingsTapped
        case browseTapped
        case viewModeToggled
        case downloadsTapped
        case delete(IndexSet)
        case sortChanged(LibrarySortOrder)
        case filterChanged(LibraryFilter)
        case folderTapped(Folder)
        case backToRoot
        case newFolderRequested
        case newFolderSheetDismissed
        case newFolderNameChanged(String)
        case newFolderSubmitted
        case folderCreated(Folder)
        case folderDeleteConfirmationRequested(UUID)
        case folderDeleteRequested(UUID)
        case folderDeleted(UUID)
        case confirmDialogDismissed
        case confirmDialogConfirmed
        case renameFolderRequested(UUID)
        case renameFolderSheetDismissed
        case renameFolderNameChanged(String)
        case renameFolderSubmitted
        case folderRenamed(Folder)
        case comicMoveToFolderRequested(comicId: UUID, folderId: UUID?)
        case comicMoved(ComicItem)
        case deleteComicRequested(UUID)
        case alert(PresentationAction<Alert>)
        // Comic rename
        case renameComicRequested(UUID)
        case renameComicSheetDismissed
        case renameComicTitleChanged(String)
        case renameComicSubmitted
        case comicRenamed(ComicItem)
        // Multi-select
        case selectionModeToggled
        case comicSelectionToggled(UUID)
        case selectAllToggled
        case bulkDeleteRequested
        case bulkMoveRequested
        case bulkMoveDestinationChosen(folderId: UUID?)
        case bulkMoveSheetDismissed
        /// Long-press on a comic: enter selection mode with it selected.
        case comicLongPressed(UUID)
        // Folder cover (inside a folder)
        case folderCoverRequested
        case folderCoverDismissed
        case folderCoverPicked(comicId: UUID)
        case folderCoverReset
        /// In-folder "Get more chapters" (☁). Handled by the parent (opens the source series).
        case openSourceSeries(url: String)

        public enum Alert: Equatable {}
    }

    @Dependency(\.comicRepository) var repo
    @Dependency(\.folderRepository) var folderRepo
    @Dependency(\.progressRepository) var progressRepo
    @Dependency(\.libraryImporter) var importer
    @Dependency(\.uuid) var uuid
    @Dependency(\.date.now) var now

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.viewMode = LibraryViewMode(rawStringOrDefault: UserDefaults.standard.string(forKey: Self.viewModeKey) ?? "")
                if let raw = UserDefaults.standard.string(forKey: Self.sortKey),
                   let saved = LibrarySortOrder(rawValue: raw) {
                    state.sort = saved
                }
                let repo = self.repo
                let folderRepo = self.folderRepo
                let progressRepo = self.progressRepo
                return .merge(
                    .run { send in
                        await loadComics(repo: repo, send: send)
                        for await _ in NotificationCenter.default.notifications(named: .manaLibraryReconciled).map({ _ in () }) {
                            await loadComics(repo: repo, send: send)
                        }
                    },
                    .run { send in
                        await send(.foldersRefreshed(await folderRepo.all()))
                        // Downloads create series folders; pick them up when the library changes.
                        for await _ in NotificationCenter.default.notifications(named: .manaLibraryReconciled).map({ _ in () }) {
                            await send(.foldersRefreshed(await folderRepo.all()))
                        }
                    },
                    .run { send in
                        await send(.progressesRefreshed(await progressRepo.all()))
                        for await _ in NotificationCenter.default.notifications(named: .manaProgressUpdated).map({ _ in () }) {
                            await send(.progressesRefreshed(await progressRepo.all()))
                        }
                    }
                )

            case .onAppear:
                // Defensive refresh whenever the library view comes back into
                // focus (e.g. after popping the reader). The NotificationCenter
                // subscription in `.task` should cover this too, but in case
                // SwiftUI cancels the root view's `.task` during a push we
                // still want progress to land.
                let progressRepo = self.progressRepo
                return .run { send in
                    await send(.progressesRefreshed(await progressRepo.all()))
                }

            case let .refreshed(items):
                state.comics = IdentifiedArray(uniqueElements: items)
                state.hasLoaded = true
                return .none

            case let .foldersRefreshed(folders):
                state.folders = IdentifiedArray(uniqueElements: folders)
                return .none

            case let .progressesRefreshed(items):
                state.progresses = Dictionary(uniqueKeysWithValues: items.map { ($0.comicId, $0) })
                return .none

            case .importTapped:
                return .none

            case let .importPicked(urls):
                state.isImporting = true
                let importer = self.importer
                let folderId = state.currentFolderId
                return .run { send in
                    do {
                        let imported = try await importer.importFiles(urls, folderId: folderId)
                        await send(.imported(imported))
                    } catch {
                        await send(.importFailed(error.localizedDescription))
                    }
                }

            case let .droppedURLs(urls):
                state.isImporting = true
                let importer = self.importer
                let folderId = state.currentFolderId
                return .run { send in
                    do {
                        let imported = try await importer.importFiles(urls, folderId: folderId)
                        await send(.imported(imported))
                    } catch {
                        await send(.importFailed(error.localizedDescription))
                    }
                }

            case let .imported(items):
                state.isImporting = false
                if !items.isEmpty { state.importSuccessCount += 1 }
                for item in items {
                    state.comics.updateOrAppend(item)
                }
                return .none

            case let .importFailed(message):
                state.isImporting = false
                state.alert = AlertState {
                    TextState("library.import_failed", bundle: .module)
                } message: {
                    TextState(verbatim: message)
                }
                return .none

            case .comicTapped:
                return .none

            case .settingsTapped:
                return .none

            case .browseTapped, .downloadsTapped:
                return .none

            case .viewModeToggled:
                state.viewMode = state.viewMode == .grid ? .list : .grid
                UserDefaults.standard.set(state.viewMode.rawValue, forKey: Self.viewModeKey)
                return .none

            case let .delete(indexSet):
                let displayed = state.displayedComics
                let toDelete = indexSet.map { displayed[$0] }
                for comic in toDelete { state.comics.remove(id: comic.id) }
                let repo = self.repo
                return .run { _ in
                    for comic in toDelete {
                        Self.deleteComicFile(at: comic.url)
                        try? await repo.delete(comic.id)
                    }
                }

            case let .sortChanged(s):
                state.sort = s
                UserDefaults.standard.set(s.rawValue, forKey: Self.sortKey)
                return .none

            case let .filterChanged(f):
                state.filter = f
                return .none

            case let .folderTapped(folder):
                state.currentFolderId = folder.id
                return .none

            case .backToRoot:
                state.currentFolderId = nil
                return .none

            case .newFolderRequested:
                state.newFolderSheet = NewFolderSheet.State()
                return .none

            case .newFolderSheetDismissed:
                state.newFolderSheet = nil
                return .none

            case let .newFolderNameChanged(name):
                state.newFolderSheet?.name = name
                return .none

            case .newFolderSubmitted:
                guard let sheet = state.newFolderSheet else { return .none }
                let name = sheet.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return .none }
                let folder = Folder(id: uuid(), name: name, dateAdded: now)
                state.folders.append(folder)
                state.newFolderSheet = nil
                let folderRepo = self.folderRepo
                return .run { send in
                    try? await folderRepo.upsert(folder)
                    await send(.folderCreated(folder))
                }

            case .folderCreated:
                return .none

            case let .folderDeleteConfirmationRequested(folderId):
                guard let folder = state.folders[id: folderId] else { return .none }
                let count = state.comics.filter { $0.folderId == folderId }.count
                state.confirmDialog = .folderDelete(
                    folderId: folderId,
                    folderName: folder.name,
                    comicCount: count
                )
                return .none

            case let .folderDeleteRequested(id):
                return deleteFolderKeepingComics(&state, folderId: id)

            case .folderDeleted:
                return .none

            case let .comicMoveToFolderRequested(comicId, folderId):
                guard let existing = state.comics[id: comicId] else { return .none }
                let updated = ComicItem(
                    id: existing.id, url: existing.url, format: existing.format, title: existing.title,
                    pageCount: existing.pageCount, coverThumbnail: existing.coverThumbnail,
                    dateAdded: existing.dateAdded, fileSizeBytes: existing.fileSizeBytes,
                    readingMode: existing.readingMode,
                    folderId: folderId, pageProgressionDirection: existing.pageProgressionDirection
                )
                state.comics.updateOrAppend(updated)
                // If this drop happened in selection mode, drop the moved id from
                // the selection set; once nothing's left, leave selection mode so
                // the bottom action bar dismisses.
                if state.isSelecting {
                    state.selectedComicIds.remove(comicId)
                    if state.selectedComicIds.isEmpty {
                        state.isSelecting = false
                    }
                }
                let repo = self.repo
                return .run { send in
                    try? await repo.upsert(updated)
                    await send(.comicMoved(updated))
                }

            case .comicMoved:
                return .none

            case let .deleteComicRequested(id):
                // Goes through the confirm dialog; the actual delete happens on confirm.
                guard let comic = state.comics[id: id] else { return .none }
                state.confirmDialog = .comicDelete(comicId: id, title: comic.title)
                return .none

            case let .renameFolderRequested(folderId):
                guard let folder = state.folders[id: folderId] else { return .none }
                state.renameFolderSheet = RenameFolderSheet.State(folderId: folderId, name: folder.name)
                return .none

            case .renameFolderSheetDismissed:
                state.renameFolderSheet = nil
                return .none

            case let .renameFolderNameChanged(text):
                state.renameFolderSheet?.name = text
                return .none

            case .renameFolderSubmitted:
                guard let sheet = state.renameFolderSheet,
                      let existing = state.folders[id: sheet.folderId]
                else { return .none }
                let name = sheet.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return .none }
                // Keep sourceURL + cover: upsert writes every field.
                let renamed = existing.renamed(name)
                state.folders.updateOrAppend(renamed)
                state.renameFolderSheet = nil
                let folderRepo = self.folderRepo
                return .run { send in
                    try? await folderRepo.upsert(renamed)
                    await send(.folderRenamed(renamed))
                }

            case .folderRenamed:
                return .none

            case .alert:
                return .none

            // MARK: - Comic rename

            case let .renameComicRequested(comicId):
                guard let comic = state.comics[id: comicId] else { return .none }
                state.renameComicSheet = RenameComicSheet.State(comicId: comicId, title: comic.title)
                return .none

            case .renameComicSheetDismissed:
                state.renameComicSheet = nil
                return .none

            case let .renameComicTitleChanged(text):
                state.renameComicSheet?.title = text
                return .none

            case .renameComicSubmitted:
                guard let sheet = state.renameComicSheet,
                      let existing = state.comics[id: sheet.comicId]
                else { return .none }
                let title = sheet.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return .none }
                let renamed = ComicItem(
                    id: existing.id, url: existing.url, format: existing.format,
                    title: title, pageCount: existing.pageCount,
                    coverThumbnail: existing.coverThumbnail, dateAdded: existing.dateAdded,
                    fileSizeBytes: existing.fileSizeBytes,
                    readingMode: existing.readingMode, folderId: existing.folderId,
                    pageProgressionDirection: existing.pageProgressionDirection,
                    pageOffset: existing.pageOffset
                )
                state.comics.updateOrAppend(renamed)
                state.renameComicSheet = nil
                let repo = self.repo
                return .run { send in
                    try? await repo.upsert(renamed)
                    await send(.comicRenamed(renamed))
                }

            case .comicRenamed:
                return .none

            // MARK: - Multi-select

            case .selectionModeToggled:
                state.isSelecting.toggle()
                if !state.isSelecting {
                    state.selectedComicIds = []
                }
                return .none

            case let .comicSelectionToggled(id):
                if state.selectedComicIds.contains(id) {
                    state.selectedComicIds.remove(id)
                } else {
                    state.selectedComicIds.insert(id)
                }
                return .none

            case .selectAllToggled:
                let displayed = state.displayedComics.map(\.id)
                let allSelected = !displayed.isEmpty && Set(displayed).isSubset(of: state.selectedComicIds)
                if allSelected {
                    for id in displayed { state.selectedComicIds.remove(id) }
                } else {
                    for id in displayed { state.selectedComicIds.insert(id) }
                }
                return .none

            case .bulkDeleteRequested:
                guard !state.selectedComicIds.isEmpty else { return .none }
                state.confirmDialog = .bulkDelete(count: state.selectedComicIds.count)
                return .none

            case .confirmDialogDismissed:
                state.confirmDialog = nil
                return .none

            case .confirmDialogConfirmed:
                guard let dialog = state.confirmDialog else { return .none }
                state.confirmDialog = nil
                switch dialog {
                case let .folderDelete(folderId, _, _):
                    // Never deletes the comics: they move back to the library root.
                    return deleteFolderKeepingComics(&state, folderId: folderId)

                case let .comicDelete(comicId, _):
                    guard let comic = state.comics[id: comicId] else { return .none }
                    state.comics.remove(id: comicId)
                    state.selectedComicIds.remove(comicId)
                    let repo = self.repo
                    return .run { _ in
                        Self.deleteComicFile(at: comic.url)
                        try? await repo.delete(comicId)
                    }

                case .bulkDelete:
                    let toDelete = state.comics.filter { state.selectedComicIds.contains($0.id) }
                    for id in state.selectedComicIds { state.comics.remove(id: id) }
                    state.selectedComicIds = []
                    state.isSelecting = false
                    let repo = self.repo
                    return .run { _ in
                        for comic in toDelete {
                            Self.deleteComicFile(at: comic.url)
                            try? await repo.delete(comic.id)
                        }
                    }
                }

            case .bulkMoveRequested:
                guard !state.selectedComicIds.isEmpty else { return .none }
                state.bulkMoveSheet = BulkMoveSheet.State(comicIds: Array(state.selectedComicIds))
                return .none

            case let .bulkMoveDestinationChosen(folderId):
                guard let sheet = state.bulkMoveSheet else { return .none }
                let comicIds = sheet.comicIds
                var updatedComics: [ComicItem] = []
                for id in comicIds {
                    guard let existing = state.comics[id: id] else { continue }
                    let updated = ComicItem(
                        id: existing.id, url: existing.url, format: existing.format,
                        title: existing.title, pageCount: existing.pageCount,
                        coverThumbnail: existing.coverThumbnail, dateAdded: existing.dateAdded,
                        fileSizeBytes: existing.fileSizeBytes,
                        readingMode: existing.readingMode, folderId: folderId,
                        pageProgressionDirection: existing.pageProgressionDirection,
                        pageOffset: existing.pageOffset
                    )
                    state.comics.updateOrAppend(updated)
                    updatedComics.append(updated)
                }
                state.bulkMoveSheet = nil
                state.selectedComicIds = []
                state.isSelecting = false
                let repo = self.repo
                let comicsToUpsert = updatedComics
                return .run { _ in
                    for item in comicsToUpsert {
                        try? await repo.upsert(item)
                    }
                }

            case .bulkMoveSheetDismissed:
                state.bulkMoveSheet = nil
                return .none

            case let .comicLongPressed(id):
                guard state.comics[id: id] != nil else { return .none }
                state.isSelecting = true
                state.selectedComicIds.insert(id)
                return .none

            case .folderCoverRequested:
                guard state.currentFolderId != nil else { return .none }
                state.isFolderCoverPickerPresented = true
                return .none

            case .folderCoverDismissed:
                state.isFolderCoverPickerPresented = false
                return .none

            case let .folderCoverPicked(comicId):
                state.isFolderCoverPickerPresented = false
                guard let folderId = state.currentFolderId,
                      let folder = state.folders[id: folderId],
                      let cover = state.comics[id: comicId]?.coverThumbnail
                else { return .none }
                state.folders.updateOrAppend(folder.withCover(cover))
                let folderRepo = self.folderRepo
                return .run { _ in try? await folderRepo.setCover(folderId: folderId, image: cover) }

            case .folderCoverReset:
                state.isFolderCoverPickerPresented = false
                guard let folderId = state.currentFolderId,
                      let folder = state.folders[id: folderId]
                else { return .none }
                state.folders.updateOrAppend(folder.withCover(nil))
                let folderRepo = self.folderRepo
                return .run { _ in try? await folderRepo.setCover(folderId: folderId, image: nil) }

            case .openSourceSeries:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private static func deleteComicFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Deletes a folder but keeps its comics: they're detached back to the library root
    /// (Android `FolderRepositoryImpl.delete`: `detachComics` then `deleteById`).
    private func deleteFolderKeepingComics(_ state: inout State, folderId: UUID) -> Effect<Action> {
        state.folders.remove(id: folderId)
        let detached = state.comics.filter { $0.folderId == folderId }.map { $0.movedTo(folderId: nil) }
        for comic in detached { state.comics.updateOrAppend(comic) }
        if state.currentFolderId == folderId { state.currentFolderId = nil }
        state.isFolderCoverPickerPresented = false
        let folderRepo = self.folderRepo
        let repo = self.repo
        return .run { send in
            // Persist the detach on the comics first so nothing is lost if the folder delete fails.
            for comic in detached { try? await repo.upsert(comic) }
            try? await folderRepo.delete(folderId)
            await send(.folderDeleted(folderId))
        }
    }

    // Trailing chapter/volume markers, so "One Piece Chapter 1012" suggests "One Piece".
    nonisolated(unsafe) private static let chapterTail: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)[\s\-_·:]*(chapter|chap|ch|episode|ep|vol|volume|season|part|화|권|第)?\.?\s*#?\d+(\.\d+)?\s*$"#
    )

    /// Suggested folder names from comic titles: strips trailing chapter numbers to recover a
    /// series name, ranks by how many comics share it (then alphabetically), drops names that
    /// are already folders, max 6. Ported from Android `folderNameSuggestions`.
    public static func folderNameSuggestions(titles: [String], existingFolders: [String]) -> [String] {
        let existing = Set(existingFolders.map { $0.lowercased() })
        let trimSet = CharacterSet(charactersIn: "-_·:. ").union(.whitespacesAndNewlines)
        var counts: [String: Int] = [:]
        for title in titles {
            var stripped = title
            if let regex = chapterTail {
                let range = NSRange(title.startIndex..., in: title)
                stripped = regex.stringByReplacingMatches(in: title, range: range, withTemplate: "")
            }
            let name = stripped.trimmingCharacters(in: trimSet)
            guard !name.isEmpty else { continue }
            counts[name, default: 0] += 1
        }
        return counts
            .sorted { a, b in
                a.value != b.value ? a.value > b.value : a.key.lowercased() < b.key.lowercased()
            }
            .map(\.key)
            .filter { !existing.contains($0.lowercased()) }
            .prefix(6)
            .map { $0 }
    }
}

private extension ComicItem {
    func movedTo(folderId: UUID?) -> ComicItem {
        ComicItem(
            id: id, url: url, format: format, title: title,
            pageCount: pageCount, coverThumbnail: coverThumbnail,
            dateAdded: dateAdded, fileSizeBytes: fileSizeBytes,
            readingMode: readingMode, folderId: folderId,
            pageProgressionDirection: pageProgressionDirection, pageOffset: pageOffset
        )
    }
}

// Existing types kept (LibrarySortOrder, LibraryFilter, dependency keys)
public enum LibrarySortOrder: String, CaseIterable, Sendable, Equatable {
    case dateAddedDesc
    case dateAddedAsc
    case titleAsc
    case titleDesc
    case pageCountDesc
    case fileSizeDesc

    public var localizationKey: String {
        switch self {
        case .dateAddedDesc: return "library.sort.recent"
        case .dateAddedAsc:  return "library.sort.oldest"
        case .titleAsc:      return "library.sort.title_asc"
        case .titleDesc:     return "library.sort.title_desc"
        case .pageCountDesc: return "library.sort.pages"
        case .fileSizeDesc:  return "library.sort.size_desc"
        }
    }
}

public enum LibraryFilter: String, CaseIterable, Sendable, Equatable {
    case all
    case zip
    case rar
    case pdf

    public var localizationKey: String {
        switch self {
        case .all: return "library.filter.all"
        case .zip: return "library.filter.zip"
        case .rar: return "library.filter.rar"
        case .pdf: return "library.filter.pdf"
        }
    }
}

private enum ComicRepositoryKey: DependencyKey {
    static let liveValue: any ComicRepository = LiveComicRepoPlaceholder()
}

private struct LiveComicRepoPlaceholder: ComicRepository {
    func all() async -> [ComicItem] { [] }
    func comic(id: UUID) async -> ComicItem? { nil }
    func upsert(_ item: ComicItem) async throws {}
    func delete(_ id: UUID) async throws {}
}

private enum FolderRepositoryKey: DependencyKey {
    static let liveValue: any FolderRepository = LiveFolderRepoPlaceholder()
}

private struct LiveFolderRepoPlaceholder: FolderRepository {
    func all() async -> [Folder] { []  }
    func upsert(_ folder: Folder) async throws {}
    func delete(_ id: UUID) async throws {}
}

private enum LibraryImporterKey: DependencyKey {
    static let liveValue: any LibraryImporter = LiveImporterPlaceholder()
}

private struct LiveImporterPlaceholder: LibraryImporter {
    func importFiles(_ urls: [URL], folderId: UUID?) async throws -> [ComicItem] { [] }
}

private enum ProgressRepositoryKey: DependencyKey {
    static let liveValue: any ProgressRepository = LiveProgressRepositoryPlaceholder()
}

private struct LiveProgressRepositoryPlaceholder: ProgressRepository {
    func all() async -> [ReadingProgress] { [] }
    func load(comicId: UUID) async -> ReadingProgress? { nil }
    func save(_ progress: ReadingProgress) async throws {}
}

private func loadComics(
    repo: any ComicRepository,
    send: Send<LibraryFeature.Action>
) async {
    var items = await repo.all()
    let fm = FileManager.default
    var orphanIds: [UUID] = []
    for comic in items {
        if !fm.fileExists(atPath: comic.url.path) {
            orphanIds.append(comic.id)
        }
    }
    if !orphanIds.isEmpty {
        for id in orphanIds {
            try? await repo.delete(id)
        }
        items = items.filter { !orphanIds.contains($0.id) }
    }
    await send(.refreshed(items))
}

extension DependencyValues {
    public var comicRepository: any ComicRepository {
        get { self[ComicRepositoryKey.self] }
        set { self[ComicRepositoryKey.self] = newValue }
    }
    public var folderRepository: any FolderRepository {
        get { self[FolderRepositoryKey.self] }
        set { self[FolderRepositoryKey.self] = newValue }
    }
    public var libraryImporter: any LibraryImporter {
        get { self[LibraryImporterKey.self] }
        set { self[LibraryImporterKey.self] = newValue }
    }
    public var progressRepository: any ProgressRepository {
        get { self[ProgressRepositoryKey.self] }
        set { self[ProgressRepositoryKey.self] = newValue }
    }
}

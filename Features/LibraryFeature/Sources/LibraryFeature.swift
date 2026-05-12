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
}

@Reducer
public struct LibraryFeature {
    public init() {}

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

        public enum ConfirmDialog: Equatable, Sendable {
            case folderDelete(folderId: UUID, folderName: String, comicCount: Int)
            case bulkDelete(count: Int)
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
            case .titleAsc: return filtered.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            case .titleDesc: return filtered.sorted { $0.title.localizedStandardCompare($1.title) == .orderedDescending }
            case .fileSizeDesc: return filtered.sorted { $0.fileSizeBytes > $1.fileSizeBytes }
            }
        }

        public var currentFolder: Folder? {
            guard let id = currentFolderId else { return nil }
            return folders[id: id]
        }
    }

    public enum Action {
        case task
        case refreshed([ComicItem])
        case foldersRefreshed([Folder])
        case importTapped
        case importPicked([URL])
        case droppedURLs([URL])
        case imported([ComicItem])
        case importFailed(String)
        case comicTapped(ComicItem)
        case settingsTapped
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

        public enum Alert: Equatable {}
    }

    @Dependency(\.comicRepository) var repo
    @Dependency(\.folderRepository) var folderRepo
    @Dependency(\.libraryImporter) var importer
    @Dependency(\.uuid) var uuid
    @Dependency(\.date.now) var now

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let repo = self.repo
                let folderRepo = self.folderRepo
                return .merge(
                    .run { send in
                        await loadComics(repo: repo, send: send)
                        for await _ in NotificationCenter.default.notifications(named: .manaLibraryReconciled).map({ _ in () }) {
                            await loadComics(repo: repo, send: send)
                        }
                    },
                    .run { send in
                        let folders = await folderRepo.all()
                        await send(.foldersRefreshed(folders))
                    }
                )

            case let .refreshed(items):
                state.comics = IdentifiedArray(uniqueElements: items)
                return .none

            case let .foldersRefreshed(folders):
                state.folders = IdentifiedArray(uniqueElements: folders)
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
                guard let sheet = state.newFolderSheet, !sheet.name.isEmpty else { return .none }
                let folder = Folder(id: uuid(), name: sheet.name, dateAdded: now)
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
                state.folders.remove(id: id)
                // Comics that were in this folder fall back to root.
                for var comic in state.comics where comic.folderId == id {
                    let updated = ComicItem(
                        id: comic.id, url: comic.url, format: comic.format, title: comic.title,
                        pageCount: comic.pageCount, coverThumbnail: comic.coverThumbnail,
                        dateAdded: comic.dateAdded, fileSizeBytes: comic.fileSizeBytes,
                        readingMode: comic.readingMode,
                        folderId: nil, pageProgressionDirection: comic.pageProgressionDirection
                    )
                    state.comics.updateOrAppend(updated)
                    _ = comic
                }
                if state.currentFolderId == id { state.currentFolderId = nil }
                let folderRepo2 = self.folderRepo
                let repo2 = self.repo
                let affectedIds = state.comics.filter { $0.folderId == nil }.map(\.id)
                return .run { send in
                    try? await folderRepo2.delete(id)
                    // Persist the folder-clear on the orphaned comics.
                    let all = await repo2.all()
                    for var item in all where affectedIds.contains(item.id) && item.folderId != nil {
                        item = ComicItem(
                            id: item.id, url: item.url, format: item.format, title: item.title,
                            pageCount: item.pageCount, coverThumbnail: item.coverThumbnail,
                            dateAdded: item.dateAdded, fileSizeBytes: item.fileSizeBytes,
                            readingMode: item.readingMode,
                            folderId: nil, pageProgressionDirection: item.pageProgressionDirection
                        )
                        try? await repo2.upsert(item)
                    }
                    await send(.folderDeleted(id))
                }

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
                guard let comic = state.comics[id: id] else { return .none }
                state.comics.remove(id: id)
                let repo = self.repo
                return .run { _ in
                    Self.deleteComicFile(at: comic.url)
                    try? await repo.delete(id)
                }

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
                      !sheet.name.isEmpty,
                      let existing = state.folders[id: sheet.folderId]
                else { return .none }
                let renamed = Folder(id: existing.id, name: sheet.name, dateAdded: existing.dateAdded)
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
                      !sheet.title.isEmpty,
                      let existing = state.comics[id: sheet.comicId]
                else { return .none }
                let renamed = ComicItem(
                    id: existing.id, url: existing.url, format: existing.format,
                    title: sheet.title, pageCount: existing.pageCount,
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
                    let comicsToDelete = state.comics.filter { $0.folderId == folderId }
                    for comic in comicsToDelete { state.comics.remove(id: comic.id) }
                    state.folders.remove(id: folderId)
                    if state.currentFolderId == folderId { state.currentFolderId = nil }
                    let repo = self.repo
                    let folderRepo = self.folderRepo
                    return .run { send in
                        for comic in comicsToDelete {
                            Self.deleteComicFile(at: comic.url)
                            try? await repo.delete(comic.id)
                        }
                        try? await folderRepo.delete(folderId)
                        await send(.folderDeleted(folderId))
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
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private static func deleteComicFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

// Existing types kept (LibrarySortOrder, LibraryFilter, dependency keys)
public enum LibrarySortOrder: String, CaseIterable, Sendable, Equatable {
    case dateAddedDesc
    case dateAddedAsc
    case titleAsc
    case titleDesc
    case fileSizeDesc

    public var localizationKey: String {
        switch self {
        case .dateAddedDesc: return "library.sort.recent"
        case .dateAddedAsc:  return "library.sort.oldest"
        case .titleAsc:      return "library.sort.title_asc"
        case .titleDesc:     return "library.sort.title_desc"
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
}

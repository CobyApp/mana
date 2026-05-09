import Foundation
import ComposableArchitecture
import Domain
import CloudSyncKit

public protocol LibraryImporter: Sendable {
    func importFiles(_ urls: [URL], folderId: UUID?) async throws -> [ComicItem]
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

    @ObservableState
    public struct State: Equatable {
        public var comics: IdentifiedArrayOf<ComicItem> = []
        public var folders: IdentifiedArrayOf<Folder> = []
        public var currentFolderId: UUID?
        public var isImporting: Bool = false
        public var sort: LibrarySortOrder = .dateAddedDesc
        public var filter: LibraryFilter = .all
        public var newFolderSheet: NewFolderSheet.State?
        @Presents public var alert: AlertState<Action.Alert>?

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
        case folderDeleteRequested(UUID)
        case folderDeleted(UUID)
        case comicMoveToFolderRequested(comicId: UUID, folderId: UUID?)
        case comicMoved(ComicItem)
        case fileSyncEvent(FileSyncEvent)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    @Dependency(\.comicRepository) var repo
    @Dependency(\.folderRepository) var folderRepo
    @Dependency(\.libraryImporter) var importer
    @Dependency(\.fileSyncService) var fileSync
    @Dependency(\.uuid) var uuid
    @Dependency(\.date.now) var now

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let repo = self.repo
                let folderRepo = self.folderRepo
                let fileSync = self.fileSync
                return .merge(
                    .run { send in
                        let items = await repo.all()
                        await send(.refreshed(items))
                    },
                    .run { send in
                        let folders = await folderRepo.all()
                        await send(.foldersRefreshed(folders))
                    },
                    .run { send in
                        for await event in fileSync.observeChanges() {
                            await send(.fileSyncEvent(event))
                        }
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
                let ids = indexSet.map { displayed[$0].id }
                for id in ids { state.comics.remove(id: id) }
                let repo = self.repo
                return .run { _ in
                    for id in ids { try? await repo.delete(id) }
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

            case let .folderDeleteRequested(id):
                state.folders.remove(id: id)
                // Comics that were in this folder fall back to root.
                for var comic in state.comics where comic.folderId == id {
                    let updated = ComicItem(
                        id: comic.id, url: comic.url, format: comic.format, title: comic.title,
                        pageCount: comic.pageCount, coverThumbnail: comic.coverThumbnail,
                        dateAdded: comic.dateAdded, fileSizeBytes: comic.fileSizeBytes,
                        readingMode: comic.readingMode, urlBookmarkData: comic.urlBookmarkData,
                        folderId: nil, pageProgressionDirection: comic.pageProgressionDirection
                    )
                    state.comics.updateOrAppend(updated)
                    _ = comic
                }
                if state.currentFolderId == id { state.currentFolderId = nil }
                let folderRepo = self.folderRepo
                let repo = self.repo
                let affectedIds = state.comics.filter { $0.folderId == nil }.map(\.id)
                return .run { send in
                    try? await folderRepo.delete(id)
                    // Persist the folder-clear on the orphaned comics.
                    let all = await repo.all()
                    for var item in all where affectedIds.contains(item.id) && item.folderId != nil {
                        item = ComicItem(
                            id: item.id, url: item.url, format: item.format, title: item.title,
                            pageCount: item.pageCount, coverThumbnail: item.coverThumbnail,
                            dateAdded: item.dateAdded, fileSizeBytes: item.fileSizeBytes,
                            readingMode: item.readingMode, urlBookmarkData: item.urlBookmarkData,
                            folderId: nil, pageProgressionDirection: item.pageProgressionDirection
                        )
                        try? await repo.upsert(item)
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
                    readingMode: existing.readingMode, urlBookmarkData: existing.urlBookmarkData,
                    folderId: folderId, pageProgressionDirection: existing.pageProgressionDirection
                )
                state.comics.updateOrAppend(updated)
                let repo = self.repo
                return .run { send in
                    try? await repo.upsert(updated)
                    await send(.comicMoved(updated))
                }

            case .comicMoved:
                return .none

            case .fileSyncEvent:
                let repo = self.repo
                return .run { send in
                    let items = await repo.all()
                    await send(.refreshed(items))
                }

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
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
    func all() async -> [Folder] { [] }
    func upsert(_ folder: Folder) async throws {}
    func delete(_ id: UUID) async throws {}
}

private enum LibraryImporterKey: DependencyKey {
    static let liveValue: any LibraryImporter = LiveImporterPlaceholder()
}

private struct LiveImporterPlaceholder: LibraryImporter {
    func importFiles(_ urls: [URL], folderId: UUID?) async throws -> [ComicItem] { [] }
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

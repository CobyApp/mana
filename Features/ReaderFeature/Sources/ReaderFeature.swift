import Foundation
import ComposableArchitecture
import Domain
import ImageCacheKit
import LibraryFeature
import SettingsFeature
import CloudSyncKit

@Reducer
public struct ReaderFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var comic: ComicItem
        public var handle: ArchiveHandle?
        public var pageIndex: Int
        public var pageCount: Int
        public var mode: ReadingMode
        public var pageProgressionDirection: PageProgressionDirection = .leftToRight
        public var isControlsVisible: Bool
        public var loadedIndices: Set<Int>
        public var securityScopedURL: URL?
        public var controlsAutoHideSeconds: Double = 3.0
        public var isSliderDragging: Bool = false
        @Presents public var alert: AlertState<Action.Alert>?

        public init(
            comic: ComicItem,
            handle: ArchiveHandle? = nil,
            pageIndex: Int = 0,
            pageCount: Int = 0,
            mode: ReadingMode = .single,
            isControlsVisible: Bool = false,
            loadedIndices: Set<Int> = [],
            securityScopedURL: URL? = nil
        ) {
            self.comic = comic
            self.handle = handle
            self.pageIndex = pageIndex
            self.pageCount = pageCount
            self.mode = mode
            self.isControlsVisible = isControlsVisible
            self.loadedIndices = loadedIndices
            self.securityScopedURL = securityScopedURL
        }
    }

    public enum Action {
        case task
        case opened(handle: ArchiveHandle, pageCount: Int, lastPage: Int)
        case openFailed(String)
        case pageChanged(Int)
        case pageLoaded(index: Int)
        case prefetchHint(Int)
        case toggleControls
        case autoHideControls
        case sliderDragStart
        case sliderDragEnd
        case persistProgress
        case modeChanged(ReadingMode)
        case progressionDirectionChanged(PageProgressionDirection)
        case bookmarksTapped(comicId: UUID)
        case startedSecurityScope(URL)
        case onDisappear
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    @Dependency(\.archiveReaderRouter) var router
    @Dependency(\.progressRepository) var progress
    @Dependency(\.imageCache) var imageCache
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.comicRepository) var comicRepo
    @Dependency(\.userDefaults) var userDefaults
    @Dependency(\.fileSyncService) var fileSync

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let comic = state.comic
                let router = self.router
                let progress = self.progress
                let fileSync = self.fileSync
                return .run { send in
                    do {
                        var url = comic.url
                        // Always prefer security-scoped bookmark when available — files picked
                        // from the Files app live outside the sandbox and require the bookmark
                        // for any access. file-existence check is unreliable here because the
                        // path may be visible while access is denied.
                        if let bookmark = comic.urlBookmarkData {
                            if let resolved = try? BookmarkURLResolver.resolve(bookmarkData: bookmark) {
                                url = resolved.url
                            }
                        }
                        if await fileSync.isAvailable {
                            try? await fileSync.ensureLocal(url: url)
                        }
                        let didStart = url.startAccessingSecurityScopedResource()
                        do {
                            let reader = router.reader(for: comic.format)
                            let handle = try await reader.openArchive(at: url)
                            let pageCount = await reader.pageCount(handle)
                            let saved = await progress.load(comicId: comic.id)
                            let lastPage = saved.map { min(max(0, $0.lastPageIndex), max(0, pageCount - 1)) } ?? 0
                            await send(.opened(handle: handle, pageCount: pageCount, lastPage: lastPage))
                            await send(.prefetchHint(lastPage))
                            if didStart { await send(.startedSecurityScope(url)) }
                        } catch {
                            if didStart { url.stopAccessingSecurityScopedResource() }
                            throw error
                        }
                    } catch {
                        await send(.openFailed(error.localizedDescription))
                    }
                }

            case let .opened(handle, pageCount, lastPage):
                state.handle = handle
                state.pageCount = pageCount
                state.pageIndex = lastPage
                if let saved = state.comic.readingMode {
                    state.mode = saved
                } else if let raw = userDefaults.string(forKey: SettingsFeature.modeKey),
                          let mode = ReadingMode(rawString: raw) {
                    state.mode = mode
                }
                if let dir = state.comic.pageProgressionDirection {
                    state.pageProgressionDirection = dir
                } else if let raw = userDefaults.string(forKey: SettingsFeature.directionKey),
                          let dir = PageProgressionDirection(rawValue: raw) {
                    state.pageProgressionDirection = dir
                }
                let storedHide = userDefaults.double(forKey: SettingsFeature.autoHideKey)
                state.controlsAutoHideSeconds = storedHide == 0 ? 3.0 : storedHide
                return .none

            case let .openFailed(message):
                state.alert = AlertState {
                    TextState("reader.error.cannot_open", bundle: .module)
                } message: {
                    TextState(verbatim: message)
                }
                return .none

            case let .pageChanged(index):
                guard index != state.pageIndex, index >= 0, index < state.pageCount else { return .none }
                state.pageIndex = index
                return .merge(
                    .send(.prefetchHint(index)),
                    .send(.persistProgress)
                )

            case let .prefetchHint(index):
                guard let handle = state.handle else { return .none }
                let comicId = state.comic.id
                let format = state.comic.format
                let pageCount = state.pageCount
                let neighbors = ([index, index - 1, index + 1]).filter { $0 >= 0 && $0 < pageCount }
                let router = self.router
                let imageCache = self.imageCache
                return .run { send in
                    let reader = router.reader(for: format)
                    for i in neighbors {
                        let key = PageKey(comicId: comicId, pageIndex: i)
                        if await imageCache.data(for: key) != nil { continue }
                        do {
                            let data = try await reader.pageData(handle, index: i)
                            await imageCache.store(data, for: key)
                            await send(.pageLoaded(index: i))
                        } catch {}
                    }
                }

            case let .pageLoaded(index):
                state.loadedIndices.insert(index)
                return .none

            case .toggleControls:
                state.isControlsVisible.toggle()
                guard state.isControlsVisible, state.controlsAutoHideSeconds > 0 else { return .none }
                let seconds = state.controlsAutoHideSeconds
                let mainQueue = self.mainQueue
                return .run { send in
                    await send(.autoHideControls)
                }
                .debounce(id: AutoHideID(), for: .seconds(seconds), scheduler: mainQueue)

            case .autoHideControls:
                guard !state.isSliderDragging else { return .none }
                state.isControlsVisible = false
                return .none

            case .sliderDragStart:
                state.isSliderDragging = true
                return .cancel(id: AutoHideID())

            case .sliderDragEnd:
                state.isSliderDragging = false
                guard state.isControlsVisible, state.controlsAutoHideSeconds > 0 else { return .none }
                let seconds = state.controlsAutoHideSeconds
                let mainQueue = self.mainQueue
                return .run { send in
                    await send(.autoHideControls)
                }
                .debounce(id: AutoHideID(), for: .seconds(seconds), scheduler: mainQueue)

            case .persistProgress:
                let p = ReadingProgress(
                    comicId: state.comic.id,
                    lastPageIndex: state.pageIndex,
                    totalPages: state.pageCount,
                    updatedAt: Date()
                )
                let progress = self.progress
                let mainQueue = self.mainQueue
                return .run { _ in
                    try? await progress.save(p)
                }
                .debounce(id: PersistDebounce(), for: .seconds(1), scheduler: mainQueue)

            case let .modeChanged(mode):
                state.mode = mode
                let updated = ComicItem(
                    id: state.comic.id, url: state.comic.url, format: state.comic.format,
                    title: state.comic.title, pageCount: state.comic.pageCount,
                    coverThumbnail: state.comic.coverThumbnail, dateAdded: state.comic.dateAdded,
                    fileSizeBytes: state.comic.fileSizeBytes,
                    readingMode: mode, urlBookmarkData: state.comic.urlBookmarkData,
                    folderId: state.comic.folderId,
                    pageProgressionDirection: state.comic.pageProgressionDirection
                )
                state.comic = updated
                let comicRepo = self.comicRepo
                return .run { _ in try? await comicRepo.upsert(updated) }

            case let .progressionDirectionChanged(direction):
                state.pageProgressionDirection = direction
                let updated = ComicItem(
                    id: state.comic.id, url: state.comic.url, format: state.comic.format,
                    title: state.comic.title, pageCount: state.comic.pageCount,
                    coverThumbnail: state.comic.coverThumbnail, dateAdded: state.comic.dateAdded,
                    fileSizeBytes: state.comic.fileSizeBytes,
                    readingMode: state.comic.readingMode, urlBookmarkData: state.comic.urlBookmarkData,
                    folderId: state.comic.folderId,
                    pageProgressionDirection: direction
                )
                state.comic = updated
                let comicRepo = self.comicRepo
                return .run { _ in try? await comicRepo.upsert(updated) }

            case .bookmarksTapped:
                return .none

            case let .startedSecurityScope(url):
                state.securityScopedURL = url
                return .none

            case .onDisappear:
                let scopedURL = state.securityScopedURL
                state.securityScopedURL = nil
                let handle = state.handle
                state.handle = nil
                let format = state.comic.format
                let router = self.router
                return .run { _ in
                    if let handle {
                        let reader = router.reader(for: format)
                        await reader.closeArchive(handle)
                    }
                    if let scopedURL { scopedURL.stopAccessingSecurityScopedResource() }
                }

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private struct PersistDebounce: Hashable {}
    private struct AutoHideID: Hashable {}
}

// MARK: - Dependency Keys

private enum ArchiveReaderRouterKey: DependencyKey {
    static let liveValue: any ArchiveReaderRouter = LiveArchiveReaderRouterPlaceholder()
}

private struct LiveArchiveReaderRouterPlaceholder: ArchiveReaderRouter {
    func reader(for format: ComicFormat) -> any ArchiveReader {
        preconditionFailure("ArchiveReaderRouter not provided.")
    }
}

private enum ProgressRepositoryKey: DependencyKey {
    static let liveValue: any ProgressRepository = LiveProgressRepositoryPlaceholder()
}

private struct LiveProgressRepositoryPlaceholder: ProgressRepository {
    func load(comicId: UUID) async -> ReadingProgress? { nil }
    func save(_ progress: ReadingProgress) async throws {}
}

private enum ImageCacheKey: DependencyKey {
    static let liveValue: ImageCache = ImageCache.inMemoryOnly()
}

extension DependencyValues {
    public var archiveReaderRouter: any ArchiveReaderRouter {
        get { self[ArchiveReaderRouterKey.self] }
        set { self[ArchiveReaderRouterKey.self] = newValue }
    }
    public var progressRepository: any ProgressRepository {
        get { self[ProgressRepositoryKey.self] }
        set { self[ProgressRepositoryKey.self] = newValue }
    }
    public var imageCache: ImageCache {
        get { self[ImageCacheKey.self] }
        set { self[ImageCacheKey.self] = newValue }
    }
}

import Foundation
import ComposableArchitecture
import Domain
import ImageCacheKit
import LibraryFeature

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
        public var isControlsVisible: Bool
        public var loadedIndices: Set<Int>
        @Presents public var alert: AlertState<Action.Alert>?

        public init(
            comic: ComicItem,
            handle: ArchiveHandle? = nil,
            pageIndex: Int = 0,
            pageCount: Int = 0,
            mode: ReadingMode = .single,
            isControlsVisible: Bool = false,
            loadedIndices: Set<Int> = []
        ) {
            self.comic = comic
            self.handle = handle
            self.pageIndex = pageIndex
            self.pageCount = pageCount
            self.mode = mode
            self.isControlsVisible = isControlsVisible
            self.loadedIndices = loadedIndices
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
        case persistProgress
        case modeChanged(ReadingMode)
        case bookmarksTapped(comicId: UUID)
        case onDisappear
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    @Dependency(\.archiveReaderRouter) var router
    @Dependency(\.progressRepository) var progress
    @Dependency(\.imageCache) var imageCache
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.comicRepository) var comicRepo

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let comic = state.comic
                return .run { send in
                    do {
                        let reader = router.reader(for: comic.format)
                        let handle = try await reader.openArchive(at: comic.url)
                        let pageCount = await reader.pageCount(handle)
                        let saved = await progress.load(comicId: comic.id)
                        let lastPage = saved.map { min(max(0, $0.lastPageIndex), max(0, pageCount - 1)) } ?? 0
                        await send(.opened(handle: handle, pageCount: pageCount, lastPage: lastPage))
                        await send(.prefetchHint(lastPage))
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
                }
                return .none

            case let .openFailed(message):
                state.alert = AlertState {
                    TextState("Cannot open comic")
                } message: {
                    TextState(message)
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
                // Current index first, then neighbors, so pageLoaded(index) fires before neighbors
                let neighbors = ([index, index - 1, index + 1]).filter { $0 >= 0 && $0 < pageCount }
                return .run { send in
                    let reader = router.reader(for: format)
                    for i in neighbors {
                        let key = PageKey(comicId: comicId, pageIndex: i)
                        if await imageCache.data(for: key) != nil { continue }
                        do {
                            let data = try await reader.pageData(handle, index: i)
                            await imageCache.store(data, for: key)
                            await send(.pageLoaded(index: i))
                        } catch {
                            // Swallow; pageLoaded will not fire for this index
                        }
                    }
                }

            case let .pageLoaded(index):
                state.loadedIndices.insert(index)
                return .none

            case .toggleControls:
                state.isControlsVisible.toggle()
                return .none

            case .persistProgress:
                let p = ReadingProgress(
                    comicId: state.comic.id,
                    lastPageIndex: state.pageIndex,
                    totalPages: state.pageCount,
                    updatedAt: Date()
                )
                return .run { _ in
                    try? await progress.save(p)
                }
                .debounce(id: PersistDebounce(), for: .seconds(1), scheduler: mainQueue)

            case let .modeChanged(mode):
                state.mode = mode
                let updated = ComicItem(
                    id: state.comic.id,
                    url: state.comic.url,
                    format: state.comic.format,
                    title: state.comic.title,
                    pageCount: state.comic.pageCount,
                    coverThumbnail: state.comic.coverThumbnail,
                    dateAdded: state.comic.dateAdded,
                    fileSizeBytes: state.comic.fileSizeBytes,
                    readingMode: mode
                )
                state.comic = updated
                return .run { _ in
                    try? await comicRepo.upsert(updated)
                }

            case .bookmarksTapped:
                // Parent (AppFeature) handles navigation
                return .none

            case .onDisappear:
                guard let handle = state.handle else { return .none }
                let format = state.comic.format
                state.handle = nil
                return .run { _ in
                    let reader = router.reader(for: format)
                    await reader.closeArchive(handle)
                }

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private struct PersistDebounce: Hashable {}
}

// MARK: - Dependency Keys

private enum ArchiveReaderRouterKey: DependencyKey {
    static let liveValue: any ArchiveReaderRouter = LiveArchiveReaderRouterPlaceholder()
}

private struct LiveArchiveReaderRouterPlaceholder: ArchiveReaderRouter {
    func reader(for format: ComicFormat) -> any ArchiveReader {
        preconditionFailure("ArchiveReaderRouter not provided. Wire it in App composition root.")
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

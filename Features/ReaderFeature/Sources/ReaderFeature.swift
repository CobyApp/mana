import Foundation
import ComposableArchitecture
import Domain
import ImageCacheKit
import LibraryFeature
import SettingsFeature

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
        public var pageOffset: Bool = false
        public var isControlsVisible: Bool
        public var loadedIndices: Set<Int>
        public var securityScopedURL: URL?
        /// The next chapter in this comic's folder (natural order), resolved after open.
        public var nextComic: ComicItem?
        /// The archive couldn't be opened; the view shows an inline retry instead of a spinner.
        public var loadFailed: Bool = false
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
        case opened(handle: ArchiveHandle, pageCount: Int, savedLastPage: Int?)
        case openFailed(String)
        case pageChanged(Int)
        case pageLoaded(index: Int)
        case prefetchHint(Int)
        case toggleControls
        case persistProgress
        case modeChanged(ReadingMode)
        case progressionDirectionChanged(PageProgressionDirection)
        case pageOffsetChanged(Bool)
        case startedSecurityScope(URL)
        case onDisappear
        case alert(PresentationAction<Alert>)
        case nextComicResolved(ComicItem?)
        case openNext
        case retry

        public enum Alert: Equatable {}
    }

    private enum CancelID: Hashable { case session }

    /// How many spreads ahead to warm into the image cache while reading (Android `PREFETCH_AHEAD`).
    public static let prefetchSpreadsAhead = 3

    @Dependency(\.archiveReaderRouter) var router
    @Dependency(\.progressRepository) var progress
    @Dependency(\.imageCache) var imageCache
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.comicRepository) var comicRepo
    @Dependency(\.userDefaults) var userDefaults

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return openEffect(comic: state.comic)

            case let .opened(handle, pageCount, savedLastPage):
                state.handle = handle
                state.pageCount = pageCount
                if let saved = state.comic.readingMode {
                    state.mode = saved
                } else if let raw = userDefaults.string(forKey: SettingsFeature.modeKey),
                          let mode = ReadingMode(rawString: raw) {
                    state.mode = mode
                }
                let resolvedDirection: PageProgressionDirection
                if let dir = state.comic.pageProgressionDirection {
                    resolvedDirection = dir
                } else if let raw = userDefaults.string(forKey: SettingsFeature.directionKey),
                          let dir = PageProgressionDirection(rawValue: raw) {
                    resolvedDirection = dir
                } else {
                    resolvedDirection = .leftToRight
                }
                state.pageProgressionDirection = resolvedDirection
                // Page-offset preference: prefer the per-comic value once any progress
                // has been recorded; otherwise fall back to the user's app-wide default.
                if savedLastPage == nil,
                   let raw = userDefaults.string(forKey: SettingsFeature.pageOffsetKey),
                   raw == "true" {
                    state.pageOffset = true
                } else {
                    state.pageOffset = state.comic.pageOffset
                }
                state.pageIndex = savedLastPage ?? 0
                let comic = state.comic
                let repo = self.comicRepo
                let resolveNext: Effect<Action> = .run { send in
                    let all = await repo.all()
                    let siblings = all
                        .filter { $0.folderId == comic.folderId }
                        .sorted { NaturalOrder.less($0.title, $1.title) }
                    if let i = siblings.firstIndex(where: { $0.id == comic.id }), i + 1 < siblings.count {
                        await send(.nextComicResolved(siblings[i + 1]))
                    } else {
                        await send(.nextComicResolved(nil))
                    }
                }
                return resolveNext

            case .openFailed:
                // Inline failure state (message + Retry + back) rather than an alert over a
                // spinner, so the reader is never a dead end. Mirrors Android `reader_load_failed`.
                state.loadFailed = true
                return .none

            case .retry:
                state.loadFailed = false
                state.handle = nil
                state.pageCount = 0
                state.loadedIndices = []
                return openEffect(comic: state.comic)

            case let .pageChanged(index):
                guard index != state.pageIndex, index >= 0, index < state.pageCount else { return .none }
                state.pageIndex = index
                let effects: [Effect<Action>] = [
                    .send(.prefetchHint(index)),
                    .send(.persistProgress)
                ]
                return .merge(effects)

            case let .prefetchHint(index):
                guard let handle = state.handle else { return .none }
                let comicId = state.comic.id
                let format = state.comic.format
                let pageCount = state.pageCount
                // Warm the current page, then `prefetchSpreadsAhead` spreads forward (a dual
                // spread is two pages), then the previous page for a back-swipe.
                let pagesPerSpread = state.mode == .dual ? 2 : 1
                let ahead = (1...(Self.prefetchSpreadsAhead * pagesPerSpread)).map { index + $0 }
                let neighbors = ([index] + ahead + [index - 1]).filter { $0 >= 0 && $0 < pageCount }
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
                return .none

            case .persistProgress:
                let p = ReadingProgress(
                    comicId: state.comic.id,
                    lastPageIndex: state.pageIndex,
                    totalPages: state.pageCount,
                    updatedAt: Date()
                )
                let progress = self.progress
                // Spawn a detached task so the save survives the reader's
                // reducer scope being cancelled mid-flight (e.g. user flips
                // pages then taps back immediately). The previous 1-second
                // debounce was getting cancelled before it could fire,
                // which is why progress sometimes wasn't reaching disk.
                return .run { _ in
                    Task.detached(priority: .utility) {
                        try? await progress.save(p)
                        NotificationCenter.default.post(name: .manaProgressUpdated, object: nil)
                    }
                }

            case let .modeChanged(mode):
                state.mode = mode
                let updated = ComicItem(
                    id: state.comic.id, url: state.comic.url, format: state.comic.format,
                    title: state.comic.title, pageCount: state.comic.pageCount,
                    coverThumbnail: state.comic.coverThumbnail, dateAdded: state.comic.dateAdded,
                    fileSizeBytes: state.comic.fileSizeBytes,
                    readingMode: mode,
                    folderId: state.comic.folderId,
                    pageProgressionDirection: state.comic.pageProgressionDirection,
                    pageOffset: state.comic.pageOffset
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
                    readingMode: state.comic.readingMode,
                    folderId: state.comic.folderId,
                    pageProgressionDirection: direction,
                    pageOffset: state.comic.pageOffset
                )
                state.comic = updated
                let comicRepo = self.comicRepo
                return .run { _ in try? await comicRepo.upsert(updated) }

            case let .pageOffsetChanged(offset):
                state.pageOffset = offset
                let updated = ComicItem(
                    id: state.comic.id, url: state.comic.url, format: state.comic.format,
                    title: state.comic.title, pageCount: state.comic.pageCount,
                    coverThumbnail: state.comic.coverThumbnail, dateAdded: state.comic.dateAdded,
                    fileSizeBytes: state.comic.fileSizeBytes,
                    readingMode: state.comic.readingMode,
                    folderId: state.comic.folderId,
                    pageProgressionDirection: state.comic.pageProgressionDirection,
                    pageOffset: offset
                )
                state.comic = updated
                let comicRepo = self.comicRepo
                return .run { _ in try? await comicRepo.upsert(updated) }

            case let .startedSecurityScope(url):
                state.securityScopedURL = url
                return .none

            case .onDisappear:
                // Cancel the parked open effect; its `defer` closes the archive and releases the
                // security scope. This also covers the case where `.openNext` left a parked effect
                // that SwiftUI's `.task` no longer owns.
                state.handle = nil
                return .cancel(id: CancelID.session)

            case let .nextComicResolved(next):
                state.nextComic = next
                return .none

            case .openNext:
                guard let next = state.nextComic else { return .none }
                state.comic = next
                state.handle = nil
                state.pageIndex = 0
                state.pageCount = 0
                state.loadedIndices = []
                state.nextComic = nil
                state.loadFailed = false
                state.isControlsVisible = false
                return openEffect(comic: next)

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    /// Opens a comic's archive, reports page count + resumed page, then parks until cancelled
    /// (view dismissed, or superseded by `.openNext`). Closing the archive and releasing the
    /// security scope happen in the effect's `defer`, so a `cancelInFlight` swap and a view
    /// teardown both clean up correctly. Shared by `.task` and `.openNext`.
    private func openEffect(comic: ComicItem) -> Effect<Action> {
        let router = self.router
        let progress = self.progress
        return .run { send in
            let url = comic.url
            let didStart = url.startAccessingSecurityScopedResource()
            let reader = router.reader(for: comic.format)
            var openedHandle: ArchiveHandle?
            defer {
                if let handle = openedHandle {
                    Task.detached { await reader.closeArchive(handle) }
                }
                if didStart { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let handle = try await reader.openArchive(at: url)
                openedHandle = handle
                let pageCount = await reader.pageCount(handle)
                let saved = await progress.load(comicId: comic.id)
                let savedLastPage: Int? = saved.map { min(max(0, $0.lastPageIndex), max(0, pageCount - 1)) }
                await send(.opened(handle: handle, pageCount: pageCount, savedLastPage: savedLastPage))
                await send(.prefetchHint(savedLastPage ?? 0))
                try await Task.sleep(nanoseconds: .max)
            } catch is CancellationError {
                // Expected when the reader view is dismissed or a next chapter supersedes this one.
            } catch {
                await send(.openFailed(error.localizedDescription))
            }
        }
        .cancellable(id: CancelID.session, cancelInFlight: true)
    }
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

private enum ImageCacheKey: DependencyKey {
    static let liveValue: ImageCache = ImageCache.inMemoryOnly()
}

extension DependencyValues {
    public var archiveReaderRouter: any ArchiveReaderRouter {
        get { self[ArchiveReaderRouterKey.self] }
        set { self[ArchiveReaderRouterKey.self] = newValue }
    }
    public var imageCache: ImageCache {
        get { self[ImageCacheKey.self] }
        set { self[ImageCacheKey.self] = newValue }
    }
}

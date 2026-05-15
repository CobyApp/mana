import Foundation
import ComposableArchitecture
import Domain
import ImageCacheKit
import IntelligenceKit
import LibraryFeature
import SettingsFeature

@Reducer
public struct ReaderFeature {
    public init() {}

    public struct TranslationState: Equatable, Sendable {
        public var isIntelligenceAvailable: Bool
        public var isEnabled: Bool
        public var targetLanguage: String
        public var pagesInFlight: Set<Int>
        public var pages: [Int: TranslatedPage]

        public init(
            isIntelligenceAvailable: Bool = false,
            isEnabled: Bool = false,
            targetLanguage: String = "ko",
            pagesInFlight: Set<Int> = [],
            pages: [Int: TranslatedPage] = [:]
        ) {
            self.isIntelligenceAvailable = isIntelligenceAvailable
            self.isEnabled = isEnabled
            self.targetLanguage = targetLanguage
            self.pagesInFlight = pagesInFlight
            self.pages = pages
        }
    }

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
        public var translation: TranslationState
        @Presents public var alert: AlertState<Action.Alert>?

        public init(
            comic: ComicItem,
            handle: ArchiveHandle? = nil,
            pageIndex: Int = 0,
            pageCount: Int = 0,
            mode: ReadingMode = .single,
            isControlsVisible: Bool = false,
            loadedIndices: Set<Int> = [],
            securityScopedURL: URL? = nil,
            translation: TranslationState = TranslationState()
        ) {
            self.comic = comic
            self.handle = handle
            self.pageIndex = pageIndex
            self.pageCount = pageCount
            self.mode = mode
            self.isControlsVisible = isControlsVisible
            self.loadedIndices = loadedIndices
            self.securityScopedURL = securityScopedURL
            self.translation = translation
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
        case translationToggleChanged(Bool)
        case translationSessionReady
        case translatePage(Int)
        case translationLoaded(pageIndex: Int, page: TranslatedPage, fromCache: Bool)
        case translationFailed(pageIndex: Int)

        public enum Alert: Equatable {}
    }

    @Dependency(\.archiveReaderRouter) var router
    @Dependency(\.progressRepository) var progress
    @Dependency(\.imageCache) var imageCache
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.comicRepository) var comicRepo
    @Dependency(\.userDefaults) var userDefaults
    @Dependency(\.pageTranslator) var pageTranslator
    @Dependency(\.translationCache) var translationCache

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                if state.translation.isIntelligenceAvailable,
                   userDefaults.string(forKey: SettingsFeature.autoTranslateKey) == "true" {
                    state.translation.isEnabled = true
                }
                // The effect parks until it's cancelled (i.e. the reader view
                // is dismissed and SwiftUI tears down its `.task`). Closing
                // the archive in the same effect avoids dispatching an
                // `.onDisappear` action after the navigation stack has already
                // popped this element (which trips TCA's "missing element"
                // forEach guard).
                let comic = state.comic
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
                        // Expected when the reader view is dismissed.
                    } catch {
                        await send(.openFailed(error.localizedDescription))
                    }
                }

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
                if state.translation.isEnabled && state.translation.isIntelligenceAvailable {
                    let idx = state.pageIndex
                    return .merge(
                        .send(.translatePage(idx - 1)),
                        .send(.translatePage(idx)),
                        .send(.translatePage(idx + 1))
                    )
                }
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
                var effects: [Effect<Action>] = [
                    .send(.prefetchHint(index)),
                    .send(.persistProgress)
                ]
                if state.translation.isEnabled && state.translation.isIntelligenceAvailable {
                    effects.append(.send(.translatePage(index - 1)))
                    effects.append(.send(.translatePage(index)))
                    effects.append(.send(.translatePage(index + 1)))
                }
                return .merge(effects)

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

            case let .translationToggleChanged(enabled):
                state.translation.isEnabled = enabled
                userDefaults.set(enabled ? "true" : "false", forKey: SettingsFeature.autoTranslateKey)
                if enabled {
                    let idx = state.pageIndex
                    return .merge(
                        .send(.translatePage(idx - 1)),
                        .send(.translatePage(idx)),
                        .send(.translatePage(idx + 1))
                    )
                }
                return .none

            case .translationSessionReady:
                guard state.translation.isEnabled, state.translation.isIntelligenceAvailable else {
                    return .none
                }
                let idx = state.pageIndex
                return .merge(
                    .send(.translatePage(idx - 1)),
                    .send(.translatePage(idx)),
                    .send(.translatePage(idx + 1))
                )

            case let .translatePage(idx):
                guard
                    state.translation.isEnabled,
                    state.translation.isIntelligenceAvailable,
                    idx >= 0, idx < state.pageCount,
                    state.translation.pages[idx] == nil,
                    !state.translation.pagesInFlight.contains(idx)
                else { return .none }

                state.translation.pagesInFlight.insert(idx)
                let comicId = state.comic.id
                let target = state.translation.targetLanguage
                let format = state.comic.format
                let cache = self.translationCache
                let translator = self.pageTranslator
                let router = self.router
                let imageCache = self.imageCache
                let handle = state.handle

                return .run { send in
                    // Cache lookup first.
                    if let cached = await cache.load(comicId: comicId, pageIndex: idx, targetLanguage: target) {
                        await send(.translationLoaded(pageIndex: idx, page: cached, fromCache: true))
                        return
                    }
                    // Fetch image bytes (try cache, then archive).
                    let key = PageKey(comicId: comicId, pageIndex: idx)
                    var imageData = await imageCache.data(for: key)
                    if imageData == nil, let handle {
                        let reader = router.reader(for: format)
                        do {
                            let data = try await reader.pageData(handle, index: idx)
                            await imageCache.store(data, for: key)
                            imageData = data
                        } catch {
                            await send(.translationFailed(pageIndex: idx))
                            return
                        }
                    }
                    guard let imageData else {
                        await send(.translationFailed(pageIndex: idx))
                        return
                    }
                    do {
                        let page = try await translator.translate(
                            imageData: imageData, comicId: comicId, pageIndex: idx, targetLanguage: target
                        )
                        await send(.translationLoaded(pageIndex: idx, page: page, fromCache: false))
                    } catch {
                        await send(.translationFailed(pageIndex: idx))
                    }
                }

            case let .translationLoaded(idx, page, fromCache):
                state.translation.pages[idx] = page
                state.translation.pagesInFlight.remove(idx)
                if fromCache { return .none }
                let cache = self.translationCache
                return .run { _ in
                    Task.detached(priority: .utility) {
                        try? await cache.save(page)
                    }
                }

            case let .translationFailed(idx):
                state.translation.pagesInFlight.remove(idx)
                return .none

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

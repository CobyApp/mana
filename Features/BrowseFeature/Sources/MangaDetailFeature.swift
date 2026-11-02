import Foundation
import ComposableArchitecture
import Domain
import LibraryFeature

/// Per-chapter page progress while downloading (done, total); total 0 means not resolved yet.
public struct ChapterProgress: Equatable, Sendable {
    public let done: Int
    public let total: Int
}

@Reducer
public struct MangaDetailFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public let mangaURL: String
        public var preview: SourceManga?
        public var detail: SourceDetail?
        public var loading: Bool = true
        public var error: Bool = false
        public var imageHeaders: [String: String] = [:]
        public var downloading: [String: ChapterProgress] = [:]
        public var downloaded: Set<String> = []
        public var failed: Set<String> = []
        public var read: Set<String> = []
        public var selectionMode: Bool = false
        public var selected: Set<String> = []

        public init(mangaURL: String, preview: SourceManga? = nil) {
            self.mangaURL = mangaURL
            self.preview = preview
        }
    }

    public enum Action {
        case task
        case retry
        case detailLoaded(SourceDetail)
        case loadFailed
        case chapterTapped(SourceChapter)   // read online — handled by parent (AppFeature)
        case downloadChapter(SourceChapter)
        case cancelChapter(SourceChapter)
        case downloadAll
        case enterSelection
        case clearSelection
        case toggleSelect(SourceChapter)
        case selectAll
        case downloadSelected
        case activeUpdated([DownloadEntry])
        case readUpdated(Set<String>)
        case downloadedComputed(Set<String>)
    }

    @Dependency(\.sourceRegistry) var registry
    @Dependency(\.downloadManager) var downloads
    @Dependency(\.comicRepository) var comicRepo
    @Dependency(\.folderRepository) var folderRepo
    @Dependency(\.readChapterRepository) var readChapters

    private enum CancelID: Hashable { case active, read }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.imageHeaders = registry.active().imageHeaders()
                return .merge(loadDetail(state.mangaURL), observeActive(), observeRead())

            case .retry:
                return loadDetail(state.mangaURL)

            case let .detailLoaded(detail):
                state.loading = false
                state.detail = detail
                return computeDownloaded(detail)

            case .loadFailed:
                state.loading = false
                state.error = true
                return .none

            case let .downloadChapter(chapter):
                enqueue([chapter], state)
                return .none

            case let .cancelChapter(chapter):
                downloads.cancel(chapterURL: chapter.url)
                return .none

            case .downloadAll:
                enqueue(state.detail?.chapters ?? [], state)
                return .none

            case .enterSelection:
                state.selectionMode = true
                state.selected = []
                return .none

            case .clearSelection:
                state.selectionMode = false
                state.selected = []
                return .none

            case let .toggleSelect(chapter):
                if state.selected.contains(chapter.url) { state.selected.remove(chapter.url) }
                else { state.selected.insert(chapter.url) }
                return .none

            case .selectAll:
                state.selected = Set((state.detail?.chapters ?? []).map(\.url))
                return .none

            case .downloadSelected:
                let sel = state.selected
                let chapters = (state.detail?.chapters ?? []).filter { sel.contains($0.url) }
                enqueue(chapters, state)
                state.selectionMode = false
                state.selected = []
                return .none

            case let .activeUpdated(entries):
                var downloading: [String: ChapterProgress] = [:]
                var failed: Set<String> = []
                for e in entries {
                    switch e.status {
                    case let .running(done, total): downloading[e.chapterURL] = ChapterProgress(done: done, total: total)
                    case .queued: downloading[e.chapterURL] = ChapterProgress(done: 0, total: 0)
                    case .failed: failed.insert(e.chapterURL)
                    }
                }
                state.downloading = downloading
                state.failed = failed
                // A completion drops out of the queue → recompute which chapters are now downloaded.
                if let detail = state.detail { return computeDownloaded(detail) }
                return .none

            case let .readUpdated(urls):
                state.read = urls
                return .none

            case let .downloadedComputed(urls):
                state.downloaded = urls
                return .none

            case .chapterTapped:
                return .none  // handled by parent
            }
        }
    }

    private func loadDetail(_ url: String) -> Effect<Action> {
        let registry = self.registry
        return .run { send in
            do {
                let detail = try await registry.active().detail(mangaURL: url)
                await send(.detailLoaded(detail))
            } catch {
                await send(.loadFailed)
            }
        }
    }

    private func observeActive() -> Effect<Action> {
        let downloads = self.downloads
        return .run { send in
            for await entries in downloads.activeStream() {
                await send(.activeUpdated(entries))
            }
        }
        .cancellable(id: CancelID.active, cancelInFlight: true)
    }

    private func observeRead() -> Effect<Action> {
        let readChapters = self.readChapters
        return .run { send in
            for await urls in readChapters.observeReadURLs() {
                await send(.readUpdated(urls))
            }
        }
        .cancellable(id: CancelID.read, cancelInFlight: true)
    }

    private func computeDownloaded(_ detail: SourceDetail) -> Effect<Action> {
        let comicRepo = self.comicRepo
        let folderRepo = self.folderRepo
        return .run { send in
            let folderName = ComicNaming.seriesFolderName(title: detail.title, url: detail.url)
            let folders = await folderRepo.all()
            let folderId = folders.first(where: { $0.name == folderName })?.id
            let comics = await comicRepo.all()
            let titlesInFolder = Set(comics.filter { $0.folderId == folderId }.map(\.title))
            let done = Set(detail.chapters.filter { titlesInFolder.contains($0.name) }.map(\.url))
            await send(.downloadedComputed(done))
        }
    }

    private func enqueue(_ chapters: [SourceChapter], _ state: State) {
        guard let detail = state.detail else { return }
        let series = ComicNaming.seriesFolderName(title: detail.title, url: state.mangaURL)
        for chapter in chapters where !state.downloaded.contains(chapter.url) && state.downloading[chapter.url] == nil {
            downloads.enqueue(
                chapterURL: chapter.url, seriesURL: state.mangaURL, seriesTitle: series,
                chapterName: chapter.name, seriesCoverURL: detail.coverURL
            )
        }
    }
}

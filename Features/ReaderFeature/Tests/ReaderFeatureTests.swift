import Testing
import Foundation
import ComposableArchitecture
@testable import ReaderFeature
import Domain
import CloudSyncKit
import ImageCacheKit
import LibraryFeature
import SettingsFeature

private struct UnavailableFileSync: FileSyncService {
    var isAvailable: Bool { get async { false } }
    func ingest(localURL: URL) async throws -> URL { throw SyncError.iCloudUnavailable }
    func ensureLocal(url: URL) async throws { throw SyncError.iCloudUnavailable }
    func observeChanges() -> AsyncStream<FileSyncEvent> { AsyncStream { _ in } }
}

private func sampleComic() -> ComicItem {
    ComicItem(
        id: UUID(),
        url: URL(fileURLWithPath: "/tmp/sample.cbz"),
        format: .cbz,
        title: "Sample",
        pageCount: 10,
        coverThumbnail: nil,
        dateAdded: Date(timeIntervalSince1970: 0),
        fileSizeBytes: 0
    )
}

private struct StubReader: ArchiveReader {
    let handle: ArchiveHandle
    let pages: [Data]
    func openArchive(at url: URL) async throws -> ArchiveHandle { handle }
    func pageCount(_ handle: ArchiveHandle) async -> Int { pages.count }
    func pageData(_ handle: ArchiveHandle, index: Int) async throws -> Data {
        guard index >= 0 && index < pages.count else { throw ArchiveError.indexOutOfBounds(index) }
        return pages[index]
    }
    func closeArchive(_ handle: ArchiveHandle) async {}
}

private struct StubRouter: ArchiveReaderRouter {
    let reader: any ArchiveReader
    func reader(for format: ComicFormat) -> any ArchiveReader { reader }
}

@Suite @MainActor struct ReaderFeatureTests {

    @Test func taskOpensArchiveAndLoadsLastPage() async {
        let pages = (0..<5).map { Data([UInt8($0)]) }
        let stubHandle = ArchiveHandle()
        let stubReader = StubReader(handle: stubHandle, pages: pages)
        let router = StubRouter(reader: stubReader)
        let comic = sampleComic()

        let progress = ReadingProgress(comicId: comic.id, lastPageIndex: 2, totalPages: 5, updatedAt: Date())
        let progressRepo = InMemoryProgressRepo(initial: [progress])

        let store = await TestStore(initialState: ReaderFeature.State(comic: comic)) {
            ReaderFeature()
        } withDependencies: {
            $0.archiveReaderRouter = router
            $0.progressRepository = progressRepo
            $0.imageCache = ImageCache.inMemoryOnly()
            $0.mainQueue = .immediate
            $0.fileSyncService = UnavailableFileSync()
            $0.userDefaults = InMemoryUserDefaults()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.task)
        await store.receive(\.opened) {
            $0.handle = stubHandle
            $0.pageCount = 5
            $0.pageIndex = 2
        }
        await store.receive(\.pageLoaded) {
            $0.loadedIndices.insert(2)
        }
    }

    @Test func modeChangedPersistsToRepo() async {
        let comic = sampleComic()
        let repo = StubComicRepoForReader(initial: [comic])
        let pages = (0..<5).map { Data([UInt8($0)]) }
        let stubHandle = ArchiveHandle()
        let stubReader = StubReader(handle: stubHandle, pages: pages)

        let store = await TestStore(initialState: ReaderFeature.State(comic: comic, pageCount: 5)) {
            ReaderFeature()
        } withDependencies: {
            $0.archiveReaderRouter = StubRouter(reader: stubReader)
            $0.progressRepository = InMemoryProgressRepo(initial: [])
            $0.imageCache = ImageCache.inMemoryOnly()
            $0.mainQueue = .immediate
            $0.comicRepository = repo
            $0.fileSyncService = UnavailableFileSync()
            $0.userDefaults = InMemoryUserDefaults()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        let expectedComic = ComicItem(
            id: comic.id,
            url: comic.url,
            format: comic.format,
            title: comic.title,
            pageCount: comic.pageCount,
            coverThumbnail: comic.coverThumbnail,
            dateAdded: comic.dateAdded,
            fileSizeBytes: comic.fileSizeBytes,
            readingMode: .scroll(direction: .rtl)
        )
        await store.send(.modeChanged(.scroll(direction: .rtl))) {
            $0.mode = .scroll(direction: .rtl)
            $0.comic = expectedComic
        }
        // Allow effect to flush
        try? await Task.sleep(nanoseconds: 50_000_000)
        let stored = await repo.all()
        #expect(stored.first?.readingMode == .scroll(direction: .rtl))
    }

    @Test func modeChangedPreservesBookmarkData() async {
        let bookmark = Data([1, 2, 3])
        let comic = ComicItem(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/x.cbz"),
            format: .cbz,
            title: "X",
            pageCount: 5,
            coverThumbnail: nil,
            dateAdded: Date(timeIntervalSince1970: 0),
            fileSizeBytes: 0,
            readingMode: nil,
            urlBookmarkData: bookmark
        )
        let repo = StubComicRepoForReader(initial: [comic])
        let store = await TestStore(initialState: ReaderFeature.State(comic: comic, pageCount: 5)) {
            ReaderFeature()
        } withDependencies: {
            let stubReader = StubReader(handle: ArchiveHandle(), pages: [])
            $0.archiveReaderRouter = StubRouter(reader: stubReader)
            $0.progressRepository = InMemoryProgressRepo(initial: [])
            $0.imageCache = ImageCache.inMemoryOnly()
            $0.mainQueue = .immediate
            $0.comicRepository = repo
            $0.fileSyncService = UnavailableFileSync()
            $0.userDefaults = InMemoryUserDefaults()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.modeChanged(.dual))
        try? await Task.sleep(nanoseconds: 50_000_000)
        let stored = await repo.all()
        #expect(stored.first?.urlBookmarkData == bookmark)
    }

    @Test func pageChangedUpdatesIndex() async {
        let pages = (0..<5).map { Data([UInt8($0)]) }
        let stubHandle = ArchiveHandle()
        let stubReader = StubReader(handle: stubHandle, pages: pages)
        let router = StubRouter(reader: stubReader)

        let store = await TestStore(
            initialState: ReaderFeature.State(comic: sampleComic(), handle: stubHandle, pageIndex: 0, pageCount: 5)
        ) {
            ReaderFeature()
        } withDependencies: {
            $0.archiveReaderRouter = router
            $0.progressRepository = InMemoryProgressRepo(initial: [])
            $0.imageCache = ImageCache.inMemoryOnly()
            $0.mainQueue = .immediate
            $0.fileSyncService = UnavailableFileSync()
            $0.userDefaults = InMemoryUserDefaults()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.pageChanged(3)) {
            $0.pageIndex = 3
        }
        await store.receive(\.pageLoaded) {
            $0.loadedIndices.insert(3)
        }
    }
}

@Test func progressionDirectionLoadsFromComic() async {
    let comic = ComicItem(
        id: UUID(), url: URL(fileURLWithPath: "/tmp/x.cbz"), format: .cbz, title: "X",
        pageCount: 5, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0),
        fileSizeBytes: 0, readingMode: nil, urlBookmarkData: nil,
        folderId: nil, pageProgressionDirection: .rightToLeft
    )
    let stubReader = StubReader(handle: ArchiveHandle(), pages: [Data([0])])
    let store = await TestStore(initialState: ReaderFeature.State(comic: comic)) {
        ReaderFeature()
    } withDependencies: {
        $0.archiveReaderRouter = StubRouter(reader: stubReader)
        $0.progressRepository = InMemoryProgressRepo(initial: [])
        $0.imageCache = ImageCache.inMemoryOnly()
        $0.mainQueue = .immediate
        $0.comicRepository = StubComicRepoForReader(initial: [comic])
        $0.fileSyncService = UnavailableFileSync()
        $0.userDefaults = InMemoryUserDefaults()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.task)
    await store.receive(\.opened) {
        $0.handle = stubReader.handle
        $0.pageCount = 1
        $0.pageProgressionDirection = .rightToLeft
    }
}

@Test func progressionDirectionChangedPersists() async {
    let comic = ComicItem(
        id: UUID(), url: URL(fileURLWithPath: "/tmp/x.cbz"), format: .cbz, title: "X",
        pageCount: 5, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0),
        fileSizeBytes: 0
    )
    let repo = StubComicRepoForReader(initial: [comic])
    let store = await TestStore(initialState: ReaderFeature.State(comic: comic, pageCount: 5)) {
        ReaderFeature()
    } withDependencies: {
        $0.archiveReaderRouter = StubRouter(reader: StubReader(handle: ArchiveHandle(), pages: []))
        $0.progressRepository = InMemoryProgressRepo(initial: [])
        $0.imageCache = ImageCache.inMemoryOnly()
        $0.mainQueue = .immediate
        $0.comicRepository = repo
        $0.fileSyncService = UnavailableFileSync()
        $0.userDefaults = InMemoryUserDefaults()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.progressionDirectionChanged(.rightToLeft)) {
        $0.pageProgressionDirection = .rightToLeft
    }
    try? await Task.sleep(nanoseconds: 50_000_000)
    let stored = await repo.all()
    #expect(stored.first?.pageProgressionDirection == .rightToLeft)
}

@Test func toggleControlsSchedulesAutoHide() async {
    let comic = ComicItem(
        id: UUID(), url: URL(fileURLWithPath: "/tmp/x.cbz"), format: .cbz, title: "X",
        pageCount: 5, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0),
        fileSizeBytes: 0
    )
    let store = await TestStore(initialState: ReaderFeature.State(comic: comic, pageCount: 5)) {
        ReaderFeature()
    } withDependencies: {
        $0.archiveReaderRouter = StubRouter(reader: StubReader(handle: ArchiveHandle(), pages: []))
        $0.progressRepository = InMemoryProgressRepo(initial: [])
        $0.imageCache = ImageCache.inMemoryOnly()
        $0.mainQueue = .immediate
        $0.comicRepository = StubComicRepoForReader(initial: [comic])
        $0.fileSyncService = UnavailableFileSync()
        $0.userDefaults = InMemoryUserDefaults()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.toggleControls) {
        $0.isControlsVisible = true
    }
    // mainQueue == .immediate, so autoHideControls fires synchronously
    await store.receive(\.autoHideControls) {
        $0.isControlsVisible = false
    }
}

actor InMemoryProgressRepo: ProgressRepository {
    private var store: [UUID: ReadingProgress]
    init(initial: [ReadingProgress]) {
        self.store = Dictionary(uniqueKeysWithValues: initial.map { ($0.comicId, $0) })
    }
    func load(comicId: UUID) async -> ReadingProgress? { store[comicId] }
    func save(_ progress: ReadingProgress) async throws { store[progress.comicId] = progress }
}

actor StubComicRepoForReader: ComicRepository {
    private var items: [ComicItem]
    init(initial: [ComicItem]) { self.items = initial }
    func all() async -> [ComicItem] { items }
    func comic(id: UUID) async -> ComicItem? { items.first { $0.id == id } }
    func upsert(_ item: ComicItem) async throws {
        if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = item }
        else { items.append(item) }
    }
    func delete(_ id: UUID) async throws { items.removeAll { $0.id == id } }
}

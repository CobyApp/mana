import Testing
import Foundation
import ComposableArchitecture
@testable import ReaderFeature
import Domain
import ImageCacheKit

@Suite @MainActor struct ReaderFeatureTests {

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

actor InMemoryProgressRepo: ProgressRepository {
    private var store: [UUID: ReadingProgress]
    init(initial: [ReadingProgress]) {
        self.store = Dictionary(uniqueKeysWithValues: initial.map { ($0.comicId, $0) })
    }
    func load(comicId: UUID) async -> ReadingProgress? { store[comicId] }
    func save(_ progress: ReadingProgress) async throws { store[progress.comicId] = progress }
}

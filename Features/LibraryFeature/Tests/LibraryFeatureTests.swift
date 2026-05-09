import Testing
import Foundation
import ComposableArchitecture
@testable import LibraryFeature
import Domain
import CloudSyncKit

private struct UnavailableFileSync: FileSyncService {
    var isAvailable: Bool { get async { false } }
    func ingest(localURL: URL) async throws -> URL { throw SyncError.iCloudUnavailable }
    func ensureLocal(url: URL) async throws { throw SyncError.iCloudUnavailable }
    func observeChanges() -> AsyncStream<FileSyncEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}

@MainActor
@Suite struct LibraryFeatureTests {

    private func sample(_ title: String) -> ComicItem {
        ComicItem(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/\(title).cbz"),
            format: .cbz,
            title: title,
            pageCount: 0,
            coverThumbnail: nil,
            dateAdded: Date(timeIntervalSince1970: 0),
            fileSizeBytes: 0
        )
    }

    @Test func taskLoadsComics() async {
        let initial = [sample("A"), sample("B")]
        let repo = StubComicRepo(initial: initial)

        let store = await TestStore(initialState: LibraryFeature.State()) {
            LibraryFeature()
        } withDependencies: {
            $0.comicRepository = repo
            $0.libraryImporter = StubImporter()
            $0.fileSyncService = UnavailableFileSync()
            $0.folderRepository = StubFolderRepo()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.task)
        await store.receive(\.refreshed) {
            $0.comics = IdentifiedArray(uniqueElements: initial)
        }
    }

    @Test func fileSyncEventTriggersRefresh() async {
        let initial = [sample("A")]
        let repo = StubComicRepo(initial: initial)

        let store = await TestStore(initialState: LibraryFeature.State()) {
            LibraryFeature()
        } withDependencies: {
            $0.comicRepository = repo
            $0.libraryImporter = StubImporter()
            $0.fileSyncService = UnavailableFileSync()
            $0.folderRepository = StubFolderRepo()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        let url = URL(fileURLWithPath: "/tmp/x.cbz")
        await store.send(.fileSyncEvent(.added(url)))
        await store.receive(\.refreshed) {
            $0.comics = IdentifiedArray(uniqueElements: initial)
        }
    }

    @Test func importPickedAddsItems() async {
        let repo = StubComicRepo(initial: [])
        let imported = sample("Imported")
        let importer = StubImporter(stubResult: [imported])

        let store = await TestStore(initialState: LibraryFeature.State()) {
            LibraryFeature()
        } withDependencies: {
            $0.comicRepository = repo
            $0.libraryImporter = importer
            $0.fileSyncService = UnavailableFileSync()
            $0.folderRepository = StubFolderRepo()
        }

        await store.send(.importPicked([URL(fileURLWithPath: "/tmp/Imported.cbz")])) {
            $0.isImporting = true
        }
        await store.receive(\.imported) {
            $0.comics = IdentifiedArray(uniqueElements: [imported])
            $0.isImporting = false
        }
    }

    @Test func sortByTitleAsc() {
        let a = ComicItem(id: UUID(), url: URL(fileURLWithPath: "/x"), format: .cbz, title: "Alpha", pageCount: 0, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 1), fileSizeBytes: 0)
        let b = ComicItem(id: UUID(), url: URL(fileURLWithPath: "/y"), format: .cbz, title: "Beta", pageCount: 0, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0), fileSizeBytes: 0)
        let state = LibraryFeature.State(
            comics: IdentifiedArray(uniqueElements: [b, a]),
            sort: .titleAsc
        )
        #expect(state.displayedComics.map(\.title) == ["Alpha", "Beta"])
    }

    @Test func filterByPdf() {
        let cbz = sample("X")
        let pdf = ComicItem(id: UUID(), url: URL(fileURLWithPath: "/p"), format: .pdf, title: "P", pageCount: 0, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0), fileSizeBytes: 0)
        let state = LibraryFeature.State(
            comics: IdentifiedArray(uniqueElements: [cbz, pdf]),
            filter: .pdf
        )
        #expect(state.displayedComics.map(\.title) == ["P"])
    }

    @Test func sortChangedActionUpdatesState() async {
        let store = await TestStore(initialState: LibraryFeature.State()) {
            LibraryFeature()
        } withDependencies: {
            $0.comicRepository = StubComicRepo(initial: [])
            $0.libraryImporter = StubImporter()
            $0.fileSyncService = UnavailableFileSync()
            $0.folderRepository = StubFolderRepo()
        }
        await store.send(.sortChanged(.titleAsc)) {
            $0.sort = .titleAsc
        }
    }
}

actor StubComicRepo: ComicRepository {
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

struct StubImporter: LibraryImporter, @unchecked Sendable {
    var stubResult: [ComicItem] = []
    func importFiles(_ urls: [URL], folderId: UUID?) async throws -> [ComicItem] { stubResult }
}

@Test func displayedFoldersSortedByDateAddedDesc() {
    let oldId = UUID()
    let newId = UUID()
    let old = Folder(id: oldId, name: "Old", dateAdded: .init(timeIntervalSince1970: 0))
    let new = Folder(id: newId, name: "New", dateAdded: .init(timeIntervalSince1970: 100))
    let state = LibraryFeature.State(
        folders: IdentifiedArray(uniqueElements: [old, new])
    )
    #expect(state.displayedFolders.map(\.id) == [newId, oldId])
}

@Test func displayedComicsFilterByCurrentFolder() {
    let folderId = UUID()
    let inFolder = ComicItem(id: UUID(), url: URL(fileURLWithPath: "/in"), format: .cbz, title: "In", pageCount: 0, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0), fileSizeBytes: 0, folderId: folderId)
    let atRoot = ComicItem(id: UUID(), url: URL(fileURLWithPath: "/root"), format: .cbz, title: "Root", pageCount: 0, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0), fileSizeBytes: 0)
    let state = LibraryFeature.State(
        comics: IdentifiedArray(uniqueElements: [inFolder, atRoot]),
        currentFolderId: folderId
    )
    #expect(state.displayedComics.map(\.title) == ["In"])
}

@Test func newFolderSubmittedCreatesFolder() async {
    let folderRepo = StubFolderRepo()
    let fixedDate = Date(timeIntervalSince1970: 100)
    let fixedUUID = UUID()

    var initialState = LibraryFeature.State()
    initialState.newFolderSheet = LibraryFeature.NewFolderSheet.State(name: "Manga")

    let store = await TestStore(initialState: initialState) {
        LibraryFeature()
    } withDependencies: {
        $0.comicRepository = StubComicRepo(initial: [])
        $0.libraryImporter = StubImporter()
        $0.fileSyncService = UnavailableFileSync()
        $0.folderRepository = folderRepo
        $0.uuid = .constant(fixedUUID)
        $0.date.now = fixedDate
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.newFolderSubmitted) {
        $0.folders.append(Folder(id: fixedUUID, name: "Manga", dateAdded: fixedDate))
        $0.newFolderSheet = nil
    }
    try? await Task.sleep(nanoseconds: 50_000_000)
    let stored = await folderRepo.all()
    #expect(stored.first?.name == "Manga")
}

@Test func folderTappedSetsCurrentFolderId() async {
    let folder = Folder(id: UUID(), name: "F", dateAdded: .init(timeIntervalSince1970: 0))
    let store = await TestStore(initialState: LibraryFeature.State(
        folders: IdentifiedArray(uniqueElements: [folder])
    )) {
        LibraryFeature()
    } withDependencies: {
        $0.comicRepository = StubComicRepo(initial: [])
        $0.libraryImporter = StubImporter()
        $0.fileSyncService = UnavailableFileSync()
        $0.folderRepository = StubFolderRepo()
    }
    await store.send(.folderTapped(folder)) {
        $0.currentFolderId = folder.id
    }
}

actor StubFolderRepo: FolderRepository {
    private var items: [Folder] = []
    init() {}
    func all() async -> [Folder] { items }
    func upsert(_ f: Folder) async throws {
        if let i = items.firstIndex(where: { $0.id == f.id }) { items[i] = f }
        else { items.append(f) }
    }
    func delete(_ id: UUID) async throws { items.removeAll { $0.id == id } }
}

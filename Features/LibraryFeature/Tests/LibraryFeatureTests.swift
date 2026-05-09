import Testing
import Foundation
import ComposableArchitecture
@testable import LibraryFeature
import Domain

@MainActor
@Suite struct LibraryFeatureTests {

    private func sample(_ title: String) -> ComicItem {
        // Write a placeholder file so orphan-cleanup doesn't remove this fixture.
        let url = FileManager.default.temporaryDirectory
            .appending(path: "\(title)-\(UUID().uuidString).cbz")
        try? Data().write(to: url)
        return ComicItem(
            id: UUID(),
            url: url,
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
            $0.folderRepository = StubFolderRepo()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.task)
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
        $0.folderRepository = StubFolderRepo()
    }
    await store.send(.folderTapped(folder)) {
        $0.currentFolderId = folder.id
    }
}

@Test func renameFolderSubmittedUpdatesState() async {
    let folder = Folder(id: UUID(), name: "Old", dateAdded: .init(timeIntervalSince1970: 0))
    let folderRepo = StubFolderRepo()
    try? await folderRepo.upsert(folder)

    var initialState = LibraryFeature.State(
        folders: IdentifiedArray(uniqueElements: [folder])
    )
    initialState.renameFolderSheet = LibraryFeature.RenameFolderSheet.State(folderId: folder.id, name: "New")

    let store = await TestStore(initialState: initialState) {
        LibraryFeature()
    } withDependencies: {
        $0.comicRepository = StubComicRepo(initial: [])
        $0.libraryImporter = StubImporter()
        $0.folderRepository = folderRepo
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.renameFolderSubmitted) {
        let renamed = Folder(id: folder.id, name: "New", dateAdded: folder.dateAdded)
        $0.folders.updateOrAppend(renamed)
        $0.renameFolderSheet = nil
    }
}

@Test func selectionModeToggleClearsSelection() async {
    let comic = ComicItem(id: UUID(), url: URL(fileURLWithPath: "/x"), format: .cbz, title: "X",
                          pageCount: 0, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0), fileSizeBytes: 0)
    var initialState = LibraryFeature.State(comics: IdentifiedArray(uniqueElements: [comic]))
    initialState.isSelecting = true
    initialState.selectedComicIds = [comic.id]

    let store = await TestStore(initialState: initialState) {
        LibraryFeature()
    } withDependencies: {
        $0.comicRepository = StubComicRepo(initial: [comic])
        $0.libraryImporter = StubImporter()
        $0.folderRepository = StubFolderRepo()
    }
    await store.send(.selectionModeToggled) {
        $0.isSelecting = false
        $0.selectedComicIds = []
    }
}

@Test func comicSelectionToggledAddsAndRemoves() async {
    let id = UUID()
    let comic = ComicItem(id: id, url: URL(fileURLWithPath: "/x"), format: .cbz, title: "X",
                          pageCount: 0, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0), fileSizeBytes: 0)
    var initialState = LibraryFeature.State(comics: IdentifiedArray(uniqueElements: [comic]))
    initialState.isSelecting = true

    let store = await TestStore(initialState: initialState) {
        LibraryFeature()
    } withDependencies: {
        $0.comicRepository = StubComicRepo(initial: [comic])
        $0.libraryImporter = StubImporter()
        $0.folderRepository = StubFolderRepo()
    }
    await store.send(.comicSelectionToggled(id)) {
        $0.selectedComicIds = [id]
    }
    await store.send(.comicSelectionToggled(id)) {
        $0.selectedComicIds = []
    }
}

@Test func bulkMoveDestinationChosenUpdatesFolderIds() async {
    let folderId = UUID()
    let folder = Folder(id: folderId, name: "F", dateAdded: .init(timeIntervalSince1970: 0))
    let c1 = ComicItem(id: UUID(), url: URL(fileURLWithPath: "/a"), format: .cbz, title: "A",
                       pageCount: 0, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0), fileSizeBytes: 0)
    let c2 = ComicItem(id: UUID(), url: URL(fileURLWithPath: "/b"), format: .cbz, title: "B",
                       pageCount: 0, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0), fileSizeBytes: 0)

    var initialState = LibraryFeature.State(
        comics: IdentifiedArray(uniqueElements: [c1, c2]),
        folders: IdentifiedArray(uniqueElements: [folder])
    )
    initialState.isSelecting = true
    initialState.selectedComicIds = [c1.id, c2.id]
    initialState.bulkMoveSheet = LibraryFeature.BulkMoveSheet.State(comicIds: [c1.id, c2.id])

    let store = await TestStore(initialState: initialState) {
        LibraryFeature()
    } withDependencies: {
        $0.comicRepository = StubComicRepo(initial: [c1, c2])
        $0.libraryImporter = StubImporter()
        $0.folderRepository = StubFolderRepo()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.bulkMoveDestinationChosen(folderId: folderId)) {
        $0.bulkMoveSheet = nil
        $0.selectedComicIds = []
        $0.isSelecting = false
        let updated1 = ComicItem(id: c1.id, url: c1.url, format: c1.format, title: c1.title,
                                 pageCount: c1.pageCount, coverThumbnail: c1.coverThumbnail,
                                 dateAdded: c1.dateAdded, fileSizeBytes: c1.fileSizeBytes,
                                 readingMode: c1.readingMode, folderId: folderId,
                                 pageProgressionDirection: c1.pageProgressionDirection, pageOffset: c1.pageOffset)
        let updated2 = ComicItem(id: c2.id, url: c2.url, format: c2.format, title: c2.title,
                                 pageCount: c2.pageCount, coverThumbnail: c2.coverThumbnail,
                                 dateAdded: c2.dateAdded, fileSizeBytes: c2.fileSizeBytes,
                                 readingMode: c2.readingMode, folderId: folderId,
                                 pageProgressionDirection: c2.pageProgressionDirection, pageOffset: c2.pageOffset)
        $0.comics.updateOrAppend(updated1)
        $0.comics.updateOrAppend(updated2)
    }
}

@Test func renameComicSubmittedUpdatesTitle() async {
    let comic = ComicItem(id: UUID(), url: URL(fileURLWithPath: "/c"), format: .cbz, title: "Old",
                          pageCount: 0, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0), fileSizeBytes: 0)
    var initialState = LibraryFeature.State(comics: IdentifiedArray(uniqueElements: [comic]))
    initialState.renameComicSheet = LibraryFeature.RenameComicSheet.State(comicId: comic.id, title: "New")

    let store = await TestStore(initialState: initialState) {
        LibraryFeature()
    } withDependencies: {
        $0.comicRepository = StubComicRepo(initial: [comic])
        $0.libraryImporter = StubImporter()
        $0.folderRepository = StubFolderRepo()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.renameComicSubmitted) {
        $0.renameComicSheet = nil
        let renamed = ComicItem(id: comic.id, url: comic.url, format: comic.format, title: "New",
                                pageCount: comic.pageCount, coverThumbnail: comic.coverThumbnail,
                                dateAdded: comic.dateAdded, fileSizeBytes: comic.fileSizeBytes,
                                readingMode: comic.readingMode, folderId: comic.folderId,
                                pageProgressionDirection: comic.pageProgressionDirection, pageOffset: comic.pageOffset)
        $0.comics.updateOrAppend(renamed)
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

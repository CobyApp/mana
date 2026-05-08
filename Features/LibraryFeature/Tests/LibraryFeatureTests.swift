import Testing
import Foundation
import ComposableArchitecture
@testable import LibraryFeature
import Domain

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
        }

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
        }

        await store.send(.importPicked([URL(fileURLWithPath: "/tmp/Imported.cbz")])) {
            $0.isImporting = true
        }
        await store.receive(\.imported) {
            $0.comics = IdentifiedArray(uniqueElements: [imported])
            $0.isImporting = false
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
    func importFiles(_ urls: [URL]) async throws -> [ComicItem] { stubResult }
}

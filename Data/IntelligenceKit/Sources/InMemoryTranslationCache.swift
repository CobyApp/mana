import Foundation
import Domain

public actor InMemoryTranslationCache: TranslationCache {
    private var pages: [String: TranslatedPage] = [:]

    public init() {}

    private func key(_ comicId: UUID, _ pageIndex: Int, _ target: String) -> String {
        "\(comicId.uuidString)|\(pageIndex)|\(target)"
    }

    public func load(comicId: UUID, pageIndex: Int, targetLanguage: String) async -> TranslatedPage? {
        pages[key(comicId, pageIndex, targetLanguage)]
    }

    public func save(_ page: TranslatedPage) async throws {
        pages[key(page.comicId, page.pageIndex, page.targetLanguage)] = page
    }

    public func deleteAll(comicId: UUID) async throws {
        pages = pages.filter { $0.value.comicId != comicId }
    }

    public func deleteEverything() async throws {
        pages.removeAll()
    }
}

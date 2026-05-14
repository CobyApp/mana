import Foundation

public protocol TranslationCache: Sendable {
    func load(comicId: UUID, pageIndex: Int, targetLanguage: String) async -> TranslatedPage?
    func save(_ page: TranslatedPage) async throws
    func deleteAll(comicId: UUID) async throws
    func deleteEverything() async throws
}

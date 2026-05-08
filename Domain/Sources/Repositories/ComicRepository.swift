import Foundation

public protocol ComicRepository: Sendable {
    func all() async -> [ComicItem]
    func comic(id: UUID) async -> ComicItem?
    func upsert(_ item: ComicItem) async throws
    func delete(_ id: UUID) async throws
}

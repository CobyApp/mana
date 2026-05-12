import Foundation

public protocol ProgressRepository: Sendable {
    func all() async -> [ReadingProgress]
    func load(comicId: UUID) async -> ReadingProgress?
    func save(_ progress: ReadingProgress) async throws
}

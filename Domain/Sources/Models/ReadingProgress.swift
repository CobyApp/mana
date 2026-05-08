import Foundation

public struct ReadingProgress: Equatable, Sendable, Hashable {
    public let comicId: UUID
    public let lastPageIndex: Int
    public let totalPages: Int
    public let updatedAt: Date

    public init(comicId: UUID, lastPageIndex: Int, totalPages: Int, updatedAt: Date) {
        self.comicId = comicId
        self.lastPageIndex = lastPageIndex
        self.totalPages = totalPages
        self.updatedAt = updatedAt
    }
}

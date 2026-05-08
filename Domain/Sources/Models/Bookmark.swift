import Foundation

public struct Bookmark: Identifiable, Equatable, Sendable, Hashable {
    public let id: UUID
    public let comicId: UUID
    public let pageIndex: Int
    public let note: String?
    public let createdAt: Date

    public init(id: UUID, comicId: UUID, pageIndex: Int, note: String?, createdAt: Date) {
        self.id = id
        self.comicId = comicId
        self.pageIndex = pageIndex
        self.note = note
        self.createdAt = createdAt
    }
}

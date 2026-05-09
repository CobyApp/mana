import Foundation

public struct Folder: Identifiable, Equatable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let dateAdded: Date

    public init(id: UUID, name: String, dateAdded: Date) {
        self.id = id
        self.name = name
        self.dateAdded = dateAdded
    }
}

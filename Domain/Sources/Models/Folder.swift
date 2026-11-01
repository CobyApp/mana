import Foundation

public struct Folder: Identifiable, Equatable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let dateAdded: Date
    /// The online source series URL this folder was downloaded from, if any (for "get more chapters").
    public let sourceURL: String?

    public init(id: UUID, name: String, dateAdded: Date, sourceURL: String? = nil) {
        self.id = id
        self.name = name
        self.dateAdded = dateAdded
        self.sourceURL = sourceURL
    }
}

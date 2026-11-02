import Foundation

public struct Folder: Identifiable, Equatable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let dateAdded: Date
    /// The online source series URL this folder was downloaded from, if any (for "get more chapters").
    public let sourceURL: String?
    /// User-chosen (or series-art) cover image; nil means "use the most recent comic's cover".
    public let coverImage: Data?

    public init(id: UUID, name: String, dateAdded: Date, sourceURL: String? = nil, coverImage: Data? = nil) {
        self.id = id
        self.name = name
        self.dateAdded = dateAdded
        self.sourceURL = sourceURL
        self.coverImage = coverImage
    }

    /// Copy with a new name, keeping every other field (source URL, cover).
    public func renamed(_ name: String) -> Folder {
        Folder(id: id, name: name, dateAdded: dateAdded, sourceURL: sourceURL, coverImage: coverImage)
    }

    /// Copy with a new custom cover (nil clears it), keeping every other field.
    public func withCover(_ coverImage: Data?) -> Folder {
        Folder(id: id, name: name, dateAdded: dateAdded, sourceURL: sourceURL, coverImage: coverImage)
    }
}

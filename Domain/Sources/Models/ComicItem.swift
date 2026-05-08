import Foundation

public struct ComicItem: Identifiable, Equatable, Sendable, Hashable {
    public let id: UUID
    public let url: URL
    public let format: ComicFormat
    public let title: String
    public let pageCount: Int?
    public let coverThumbnail: Data?
    public let dateAdded: Date
    public let fileSizeBytes: Int64

    public init(
        id: UUID,
        url: URL,
        format: ComicFormat,
        title: String,
        pageCount: Int?,
        coverThumbnail: Data?,
        dateAdded: Date,
        fileSizeBytes: Int64
    ) {
        self.id = id
        self.url = url
        self.format = format
        self.title = title
        self.pageCount = pageCount
        self.coverThumbnail = coverThumbnail
        self.dateAdded = dateAdded
        self.fileSizeBytes = fileSizeBytes
    }
}

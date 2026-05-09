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
    public let readingMode: ReadingMode?
    public let folderId: UUID?
    public let pageProgressionDirection: PageProgressionDirection?
    public let pageOffset: Bool

    public init(
        id: UUID,
        url: URL,
        format: ComicFormat,
        title: String,
        pageCount: Int?,
        coverThumbnail: Data?,
        dateAdded: Date,
        fileSizeBytes: Int64,
        readingMode: ReadingMode? = nil,
        folderId: UUID? = nil,
        pageProgressionDirection: PageProgressionDirection? = nil,
        pageOffset: Bool = false
    ) {
        self.id = id
        self.url = url
        self.format = format
        self.title = title
        self.pageCount = pageCount
        self.coverThumbnail = coverThumbnail
        self.dateAdded = dateAdded
        self.fileSizeBytes = fileSizeBytes
        self.readingMode = readingMode
        self.folderId = folderId
        self.pageProgressionDirection = pageProgressionDirection
        self.pageOffset = pageOffset
    }
}

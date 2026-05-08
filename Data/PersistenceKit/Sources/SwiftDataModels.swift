import Foundation
import SwiftData
import Domain

@Model
public final class ComicEntity {
    @Attribute(.unique) public var id: UUID
    public var urlString: String
    public var formatRaw: String
    public var title: String
    public var pageCount: Int?
    public var coverThumbnail: Data?
    public var dateAdded: Date
    public var fileSizeBytes: Int64

    public init(
        id: UUID,
        urlString: String,
        formatRaw: String,
        title: String,
        pageCount: Int?,
        coverThumbnail: Data?,
        dateAdded: Date,
        fileSizeBytes: Int64
    ) {
        self.id = id
        self.urlString = urlString
        self.formatRaw = formatRaw
        self.title = title
        self.pageCount = pageCount
        self.coverThumbnail = coverThumbnail
        self.dateAdded = dateAdded
        self.fileSizeBytes = fileSizeBytes
    }

    public func toModel() -> ComicItem {
        ComicItem(
            id: id,
            url: URL(string: urlString) ?? URL(fileURLWithPath: urlString),
            format: ComicFormat(rawValue: formatRaw) ?? .zip,
            title: title,
            pageCount: pageCount,
            coverThumbnail: coverThumbnail,
            dateAdded: dateAdded,
            fileSizeBytes: fileSizeBytes
        )
    }

    public static func from(_ item: ComicItem) -> ComicEntity {
        ComicEntity(
            id: item.id,
            urlString: item.url.absoluteString,
            formatRaw: item.format.rawValue,
            title: item.title,
            pageCount: item.pageCount,
            coverThumbnail: item.coverThumbnail,
            dateAdded: item.dateAdded,
            fileSizeBytes: item.fileSizeBytes
        )
    }
}

@Model
public final class ReadingProgressEntity {
    @Attribute(.unique) public var comicId: UUID
    public var lastPageIndex: Int
    public var totalPages: Int
    public var updatedAt: Date

    public init(comicId: UUID, lastPageIndex: Int, totalPages: Int, updatedAt: Date) {
        self.comicId = comicId
        self.lastPageIndex = lastPageIndex
        self.totalPages = totalPages
        self.updatedAt = updatedAt
    }

    public func toModel() -> ReadingProgress {
        ReadingProgress(comicId: comicId, lastPageIndex: lastPageIndex, totalPages: totalPages, updatedAt: updatedAt)
    }
}

@Model
public final class BookmarkEntity {
    @Attribute(.unique) public var id: UUID
    public var comicId: UUID
    public var pageIndex: Int
    public var note: String?
    public var createdAt: Date

    public init(id: UUID, comicId: UUID, pageIndex: Int, note: String?, createdAt: Date) {
        self.id = id
        self.comicId = comicId
        self.pageIndex = pageIndex
        self.note = note
        self.createdAt = createdAt
    }

    public func toModel() -> Bookmark {
        Bookmark(id: id, comicId: comicId, pageIndex: pageIndex, note: note, createdAt: createdAt)
    }
}

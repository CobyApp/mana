import Foundation
import SwiftData
import Domain

@Model
public final class ComicEntity {
    public var id: UUID = UUID()
    public var urlString: String = ""
    public var formatRaw: String = ""
    public var title: String = ""
    public var pageCount: Int?
    public var coverThumbnail: Data?
    public var dateAdded: Date = Date(timeIntervalSince1970: 0)
    public var fileSizeBytes: Int64 = 0
    public var readingModeRaw: String?
    public var urlBookmarkData: Data?
    public var folderId: UUID?
    public var pageProgressionDirectionRaw: String?

    public init(
        id: UUID,
        urlString: String,
        formatRaw: String,
        title: String,
        pageCount: Int?,
        coverThumbnail: Data?,
        dateAdded: Date,
        fileSizeBytes: Int64,
        readingModeRaw: String? = nil,
        urlBookmarkData: Data? = nil,
        folderId: UUID? = nil,
        pageProgressionDirectionRaw: String? = nil
    ) {
        self.id = id
        self.urlString = urlString
        self.formatRaw = formatRaw
        self.title = title
        self.pageCount = pageCount
        self.coverThumbnail = coverThumbnail
        self.dateAdded = dateAdded
        self.fileSizeBytes = fileSizeBytes
        self.readingModeRaw = readingModeRaw
        self.urlBookmarkData = urlBookmarkData
        self.folderId = folderId
        self.pageProgressionDirectionRaw = pageProgressionDirectionRaw
    }

    public func toModel() -> ComicItem {
        let mode = readingModeRaw.flatMap { ReadingMode(rawString: $0) }
        let direction = pageProgressionDirectionRaw.flatMap { PageProgressionDirection(rawValue: $0) }
        return ComicItem(
            id: id,
            url: URL(string: urlString) ?? URL(fileURLWithPath: urlString),
            format: ComicFormat(rawValue: formatRaw) ?? .zip,
            title: title,
            pageCount: pageCount,
            coverThumbnail: coverThumbnail,
            dateAdded: dateAdded,
            fileSizeBytes: fileSizeBytes,
            readingMode: mode,
            urlBookmarkData: urlBookmarkData,
            folderId: folderId,
            pageProgressionDirection: direction
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
            fileSizeBytes: item.fileSizeBytes,
            readingModeRaw: item.readingMode?.rawString,
            urlBookmarkData: item.urlBookmarkData,
            folderId: item.folderId,
            pageProgressionDirectionRaw: item.pageProgressionDirection?.rawValue
        )
    }
}

@Model
public final class FolderEntity {
    public var id: UUID = UUID()
    public var name: String = ""
    public var dateAdded: Date = Date(timeIntervalSince1970: 0)

    public init(id: UUID, name: String, dateAdded: Date) {
        self.id = id
        self.name = name
        self.dateAdded = dateAdded
    }

    public func toModel() -> Folder {
        Folder(id: id, name: name, dateAdded: dateAdded)
    }

    public static func from(_ folder: Folder) -> FolderEntity {
        FolderEntity(id: folder.id, name: folder.name, dateAdded: folder.dateAdded)
    }
}

@Model
public final class ReadingProgressEntity {
    public var comicId: UUID = UUID()
    public var lastPageIndex: Int = 0
    public var totalPages: Int = 0
    public var updatedAt: Date = Date(timeIntervalSince1970: 0)

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


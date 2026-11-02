import Foundation

/// Live status of a chapter download. Completed downloads leave the list (the library becomes
/// the source of truth for "downloaded").
public enum ChapterDownloadStatus: Equatable, Sendable, Hashable {
    /// Waiting in the queue, not started yet.
    case queued
    /// `total == 0` means the page count is not known yet (still resolving).
    case running(done: Int, total: Int)
    case failed
}

/// One download in the queue, with enough metadata to show in the downloads screen.
public struct DownloadEntry: Identifiable, Equatable, Sendable, Hashable {
    public var id: String { chapterURL }
    public let chapterURL: String
    public let seriesTitle: String
    public let chapterName: String
    public let status: ChapterDownloadStatus

    public init(chapterURL: String, seriesTitle: String, chapterName: String, status: ChapterDownloadStatus) {
        self.chapterURL = chapterURL
        self.seriesTitle = seriesTitle
        self.chapterName = chapterName
        self.status = status
    }
}

/// A download request persisted across process death so an interrupted queue can resume.
public struct PersistedDownload: Equatable, Sendable, Hashable, Codable {
    public let chapterURL: String
    public let seriesURL: String
    public let seriesTitle: String
    public let chapterName: String
    public let seriesCoverURL: String?
    public let enqueuedAt: Date

    public init(
        chapterURL: String,
        seriesURL: String,
        seriesTitle: String,
        chapterName: String,
        seriesCoverURL: String?,
        enqueuedAt: Date
    ) {
        self.chapterURL = chapterURL
        self.seriesURL = seriesURL
        self.seriesTitle = seriesTitle
        self.chapterName = chapterName
        self.seriesCoverURL = seriesCoverURL
        self.enqueuedAt = enqueuedAt
    }
}

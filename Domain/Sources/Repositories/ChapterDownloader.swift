import Foundation

/// Downloads a single online chapter into the local library as a .cbz, so it reads fully
/// offline through the existing local reader. Returns the imported `ComicItem`.
public protocol ChapterDownloader: Sendable {
    /// Downloads `chapterURL` into the local library inside a folder named `seriesTitle`, titled
    /// `chapterName`. `onProgress` reports (downloadedPages, totalPages) as pages are fetched.
    func download(
        chapterURL: String,
        seriesURL: String,
        seriesTitle: String,
        chapterName: String,
        seriesCoverURL: String?,
        onProgress: @Sendable @escaping (_ done: Int, _ total: Int) -> Void
    ) async throws -> ComicItem
}

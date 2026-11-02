import Foundation

/// An online manga source. Implementations parse a specific site. Pages are 1-based in the
/// site's own terms but this interface returns ordered image URLs; the reader indexes 0-based.
public protocol MangaSource: Sendable {
    var id: String { get }
    var name: String { get }
    var baseURL: String { get }

    /// Most recently updated series, paginated (page is 1-based).
    func latest(page: Int) async throws -> [SourceManga]

    /// The source's browsable genres.
    func genres() async throws -> [SourceGenre]

    /// Series within a genre, paginated (page is 1-based).
    func byGenre(slug: String, page: Int) async throws -> [SourceManga]

    /// Search series by title, paginated (page is 1-based).
    func search(query: String, page: Int) async throws -> [SourceManga]

    /// Full detail for a series, including its chapters in reading order (oldest first).
    func detail(mangaURL: String) async throws -> SourceDetail

    /// Ordered page image URLs for a chapter.
    func pages(chapterURL: String) async throws -> [String]

    /// Headers (Referer, User-Agent) required to fetch this source's images.
    func imageHeaders() -> [String: String]
}

/// Holds the registered sources. v1 registers only rawkuma.
public protocol SourceRegistry: Sendable {
    func active() -> MangaSource
    func all() -> [MangaSource]
}

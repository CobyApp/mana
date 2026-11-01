import Foundation
import Domain

/// rawkuma online source.
///
/// - latest / byGenre / search: WP REST `manga` collection JSON
/// - genres: WP REST `genre` taxonomy JSON
/// - detail / pages: server-rendered series / chapter HTML
public actor RawkumaSource: MangaSource {
    public nonisolated let id = "rawkuma"
    public nonisolated let name = "Rawkuma"
    public nonisolated let baseURL = "https://rawkuma.net"

    private static let perPage = 24
    private let http: SourceHTTP
    private var genreIds: [String: Int]?

    public init(http: SourceHTTP = SourceHTTP()) {
        self.http = http
    }

    private var genreEndpoint: String { "\(baseURL)/wp-json/wp/v2/genre?per_page=100" }
    private var mangaEndpoint: String { "\(baseURL)/wp-json/wp/v2/manga" }

    public func latest(page: Int) async throws -> [SourceManga] {
        let json = try await getListJson("\(mangaEndpoint)?orderby=modified&order=desc&per_page=\(Self.perPage)&page=\(page)")
        return RawkumaParser.parseMangaRest(json)
    }

    public func genres() async throws -> [SourceGenre] {
        let json = try await http.get(genreEndpoint)
        genreIds = RawkumaParser.parseGenreIds(json)
        return RawkumaParser.parseGenres(json)
    }

    public func byGenre(slug: String, page: Int) async throws -> [SourceManga] {
        guard let id = try await genreIdOf(slug) else { return [] }
        let json = try await getListJson("\(mangaEndpoint)?genre=\(id)&orderby=modified&order=desc&per_page=\(Self.perPage)&page=\(page)")
        return RawkumaParser.parseMangaRest(json)
    }

    public func search(query: String, page: Int) async throws -> [SourceManga] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let json = try await getListJson("\(mangaEndpoint)?search=\(q)&per_page=\(Self.perPage)&page=\(page)")
        return RawkumaParser.parseMangaRest(json)
    }

    public func detail(mangaURL: String) async throws -> SourceDetail {
        RawkumaParser.parseDetail(url: mangaURL, html: try await http.get(mangaURL))
    }

    public func pages(chapterURL: String) async throws -> [String] {
        RawkumaParser.parsePages(try await http.get(chapterURL))
    }

    public nonisolated func imageHeaders() -> [String: String] {
        ["Referer": "\(baseURL)/", "User-Agent": SourceHTTP.userAgent]
    }

    private func genreIdOf(_ slug: String) async throws -> Int? {
        if let cache = genreIds { return cache[slug] }
        let ids = RawkumaParser.parseGenreIds(try await http.get(genreEndpoint))
        genreIds = ids
        return ids[slug]
    }

    /// GETs a REST collection, treating an out-of-range page (HTTP 400) as the end of pagination.
    private func getListJson(_ url: String) async throws -> String {
        do {
            return try await http.get(url)
        } catch let SourceHTTP.HTTPError.status(code, _) where code == 400 {
            return "[]"
        }
    }
}

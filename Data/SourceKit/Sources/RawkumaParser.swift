import Foundation
import Domain
import SwiftSoup

/// Pure parsing for rawkuma — no network. Takes raw HTML/JSON strings, returns domain models.
/// Ported from the Android `RawkumaParser` (Jsoup → SwiftSoup).
public enum RawkumaParser {

    /// Parses the WP REST `manga` collection (used by latest + byGenre) into series entries.
    /// title → `title.rendered`, url → `link`, cover → `meta.meta.thumbnail`.
    public static func parseMangaRest(_ json: String) -> [SourceManga] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        var out: [SourceManga] = []
        for o in arr {
            let url = (o["link"] as? String) ?? ""
            if url.isEmpty { continue }
            let rendered = (o["title"] as? [String: Any])?["rendered"] as? String ?? ""
            let title = unescape(rendered).trimmingCharacters(in: .whitespacesAndNewlines)
            let thumb = ((o["meta"] as? [String: Any])?["meta"] as? [String: Any])?["thumbnail"] as? String
            let cover = (thumb?.isEmpty == false) ? thumb : nil
            out.append(SourceManga(url: url, title: title, coverURL: cover))
        }
        return out
    }

    /// Parses the WP REST taxonomy JSON (/wp-json/wp/v2/genre) into genres (sorted by name).
    public static func parseGenres(_ json: String) -> [SourceGenre] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        var out: [SourceGenre] = []
        for o in arr {
            let slug = (o["slug"] as? String) ?? ""
            let name = (o["name"] as? String) ?? ""
            if !slug.isEmpty && !name.isEmpty { out.append(SourceGenre(slug: slug, name: unescape(name))) }
        }
        return out.sorted { $0.name < $1.name }
    }

    /// Maps genre slug → WP term id, needed to filter the `manga` REST collection by genre.
    public static func parseGenreIds(_ json: String) -> [String: Int] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [:] }
        var out: [String: Int] = [:]
        for o in arr {
            let slug = (o["slug"] as? String) ?? ""
            let id = (o["id"] as? Int) ?? -1
            if !slug.isEmpty && id >= 0 { out[slug] = id }
        }
        return out
    }

    /// Parses a series detail page. Chapters are returned oldest-first (reading order).
    public static func parseDetail(url: String, html: String) -> SourceDetail {
        guard let doc = try? SwiftSoup.parse(html, url) else {
            return SourceDetail(url: url, title: "", coverURL: nil, synopsis: nil, genres: [], chapters: [])
        }
        let title =
            nonBlankText(doc, "h1[itemprop=name]")
            ?? nonBlankText(doc, "h1.entry-title")
            ?? stripSiteSuffix(nonBlankText(doc, "title"))
            ?? ""
        let synopsis = nonBlankText(doc, "[itemprop=description]")
        let cover: String? = {
            guard let imgs = try? doc.select("img[src*=/wp-content/uploads/]") else { return nil }
            for img in imgs.array() {
                let src = (try? img.attr("src")) ?? ""
                if !src.lowercased().contains("logo") {
                    return (try? img.attr("abs:src")).flatMap { $0.isEmpty ? nil : $0 } ?? src
                }
            }
            return nil
        }()
        var genres: [SourceGenre] = []
        if let anchors = try? doc.select("a[href*=/genre/]") {
            var seen = Set<String>()
            for a in anchors.array() {
                let href = (try? a.attr("href")) ?? ""
                let slug = href.components(separatedBy: "/genre/").last?
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    .components(separatedBy: "/").last ?? ""
                if slug.isEmpty || seen.contains(slug) { continue }
                seen.insert(slug)
                genres.append(SourceGenre(slug: slug, name: ((try? a.text()) ?? "").trimmingCharacters(in: .whitespaces)))
            }
        }
        var chapters: [SourceChapter] = []
        if let rows = try? doc.select("#chapter-list div[data-chapter-number]") {
            for row in rows.array() {
                if let ch = parseChapterRow(row) { chapters.append(ch) }
            }
        }
        // site lists newest-first; reading order is oldest-first
        chapters.reverse()
        return SourceDetail(url: url, title: title, coverURL: cover, synopsis: synopsis, genres: genres, chapters: chapters)
    }

    private static func parseChapterRow(_ row: Element) -> SourceChapter? {
        guard let link = try? row.select("a[href*=/chapter-]").first() else { return nil }
        let href = (try? link.attr("abs:href")).flatMap { $0.isEmpty ? nil : $0 } ?? ((try? link.attr("href")) ?? "")
        if href.isEmpty { return nil }
        let number = ((try? row.attr("data-chapter-number")) ?? "").trimmingCharacters(in: .whitespaces)
        let name: String
        if !number.isEmpty {
            name = "Chapter \(number)"
        } else {
            name = ((try? row.select("a").first()?.text()) ?? "")?.trimmingCharacters(in: .whitespaces) ?? ""
        }
        return SourceChapter(url: href, name: name)
    }

    // A numbered page image file, e.g. ".../1.jpg", ".../12.png" (query stripped before matching).
    private static let pageImage = try! NSRegularExpression(
        pattern: "/\\d+\\.(?:jpg|jpeg|png|webp|gif)$", options: [.caseInsensitive]
    )

    /// Parses a chapter page into ordered page-image URLs. rawkuma serves pages from several
    /// off-site CDN hosts, so we take numbered image files hosted anywhere except rawkuma.net
    /// (logo/cover) and trackers.
    public static func parsePages(_ html: String) -> [String] {
        guard let doc = try? SwiftSoup.parse(html), let imgs = try? doc.select("img") else { return [] }
        var seen: [String] = []
        var set = Set<String>()
        for img in imgs.array() {
            let dataSrc = ((try? img.attr("data-src")) ?? "").trimmingCharacters(in: .whitespaces)
            let plain = ((try? img.attr("src")) ?? "").trimmingCharacters(in: .whitespaces)
            let src = dataSrc.isEmpty ? plain : dataSrc
            if !src.hasPrefix("https://") { continue }
            guard let host = URL(string: src)?.host?.lowercased() else { continue }
            if host == "rawkuma.net" || host.contains("gravatar") || host.contains("histats") { continue }
            let beforeQuery = src.components(separatedBy: "?").first ?? src
            let range = NSRange(beforeQuery.startIndex..., in: beforeQuery)
            if pageImage.firstMatch(in: beforeQuery, range: range) == nil { continue }
            if set.insert(src).inserted { seen.append(src) }
        }
        return seen
    }

    // MARK: - Helpers

    private static func nonBlankText(_ doc: Document, _ selector: String) -> String? {
        guard let el = try? doc.select(selector).first(), let text = try? el.text() else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func stripSiteSuffix(_ title: String?) -> String? {
        guard let title else { return nil }
        let cleaned = title.replacingOccurrences(
            of: "\\s*[–\\-|]\\s*Rawkuma.*$", with: "", options: [.regularExpression, .caseInsensitive]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func unescape(_ s: String) -> String {
        (try? Entities.unescape(s)) ?? s
    }
}

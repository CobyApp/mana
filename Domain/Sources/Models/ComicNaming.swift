import Foundation

/// Naming for a downloaded chapter. A downloaded chapter becomes a comic titled after the chapter
/// (e.g. "Chapter 1") inside a library folder named after the series, so the library groups a
/// series' chapters together.
public enum ComicNaming {
    /// Filesystem-safe base name for the temporary .cbz (the title is set explicitly after import).
    public static func cbzBaseName(chapterName: String) -> String {
        sanitize(chapterName).isEmpty ? "chapter" : sanitize(chapterName)
    }

    /// The library folder name for a downloaded series. Uses the series `title`; when the source
    /// didn't give one (blank), falls back to a readable name derived from the series `url` slug so
    /// a download never lands in a folder named "".
    public static func seriesFolderName(title: String, url: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? slugName(url) : trimmed
    }

    /// Turns ".../manga/one-piece-wano/" into "One Piece Wano".
    private static func slugName(_ url: String) -> String {
        let beforeQuery = url.split(separator: "?", maxSplits: 1).first.map(String.init) ?? url
        let slug = beforeQuery
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/").last.map(String.init) ?? ""
        let words = slug
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: { $0 == " " })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        let joined = words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return joined.isEmpty ? "Series" : joined
    }

    private static func sanitize(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let replaced = String(name.unicodeScalars.map { illegal.contains($0) ? " " : Character($0) })
        return replaced
            .split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

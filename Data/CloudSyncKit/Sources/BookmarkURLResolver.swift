import Foundation

public enum BookmarkURLResolver {

    /// Encodes a security-scoped bookmark for `url`. The caller must already have access
    /// (e.g., via Files-app picker that returned the URL).
    public static func bookmarkData(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// Resolves a previously stored bookmark. Returns the URL and whether the bookmark
    /// is stale (caller should refresh by calling `bookmarkData(for:)` and persisting).
    public static func resolve(bookmarkData: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return (url, isStale)
    }
}

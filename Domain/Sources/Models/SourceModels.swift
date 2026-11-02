import Foundation

/// A manga entry as seen in a source's browse/listing view.
public struct SourceManga: Identifiable, Equatable, Sendable, Hashable {
    public var id: String { url }
    public let url: String
    public let title: String
    public let coverURL: String?

    public init(url: String, title: String, coverURL: String?) {
        self.url = url
        self.title = title
        self.coverURL = coverURL
    }
}

/// A browsable category on a source.
public struct SourceGenre: Identifiable, Equatable, Sendable, Hashable {
    public var id: String { slug }
    public let slug: String
    public let name: String

    public init(slug: String, name: String) {
        self.slug = slug
        self.name = name
    }
}

/// A single chapter link on a source.
public struct SourceChapter: Identifiable, Equatable, Sendable, Hashable {
    public var id: String { url }
    public let url: String
    public let name: String

    public init(url: String, name: String) {
        self.url = url
        self.name = name
    }
}

/// Full series detail: header fields plus the chapter list in reading order (oldest first).
public struct SourceDetail: Equatable, Sendable, Hashable {
    public let url: String
    public let title: String
    public let coverURL: String?
    public let synopsis: String?
    public let genres: [SourceGenre]
    public let chapters: [SourceChapter]

    public init(
        url: String,
        title: String,
        coverURL: String?,
        synopsis: String?,
        genres: [SourceGenre],
        chapters: [SourceChapter]
    ) {
        self.url = url
        self.title = title
        self.coverURL = coverURL
        self.synopsis = synopsis
        self.genres = genres
        self.chapters = chapters
    }
}

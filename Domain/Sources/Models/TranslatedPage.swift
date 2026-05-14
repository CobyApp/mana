import Foundation

public struct TranslatedPage: Equatable, Sendable, Hashable, Codable {
    public let comicId: UUID
    public let pageIndex: Int
    /// BCP-47 of the detected source language. "und" when detection failed.
    public let sourceLanguage: String
    /// BCP-47 of the target language used when the page was translated.
    public let targetLanguage: String
    public let lines: [TranslatedLine]
    public let createdAt: Date

    public init(
        comicId: UUID,
        pageIndex: Int,
        sourceLanguage: String,
        targetLanguage: String,
        lines: [TranslatedLine],
        createdAt: Date
    ) {
        self.comicId = comicId
        self.pageIndex = pageIndex
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.lines = lines
        self.createdAt = createdAt
    }
}

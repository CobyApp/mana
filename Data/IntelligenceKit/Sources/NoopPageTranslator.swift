import Foundation
import Domain

public struct NoopPageTranslator: PageTranslator {
    public init() {}

    public func translate(
        imageData: Data,
        comicId: UUID,
        pageIndex: Int,
        targetLanguage: String
    ) async throws -> TranslatedPage {
        TranslatedPage(
            comicId: comicId, pageIndex: pageIndex,
            sourceLanguage: "und", targetLanguage: targetLanguage,
            lines: [], createdAt: Date()
        )
    }
}

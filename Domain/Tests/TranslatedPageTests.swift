import Testing
import Foundation
import CoreGraphics
@testable import Domain

@Suite struct TranslatedPageTests {
    @Test func emptyPageHasNoLines() {
        let page = TranslatedPage(
            comicId: UUID(), pageIndex: 0,
            sourceLanguage: "und", targetLanguage: "ko",
            lines: [], createdAt: Date()
        )
        #expect(page.lines.isEmpty)
    }

    @Test func codableRoundTrip() throws {
        let comicId = UUID()
        let box = TextLineBox(id: UUID(), text: "こんにちは",
                              boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.05),
                              confidence: 0.9)
        let line = TranslatedLine(original: box, translated: "안녕하세요", backgroundColorARGB: 0xFFEEEEEE)
        let page = TranslatedPage(
            comicId: comicId, pageIndex: 3,
            sourceLanguage: "ja", targetLanguage: "ko",
            lines: [line], createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(page)
        let decoded = try JSONDecoder().decode(TranslatedPage.self, from: data)
        #expect(decoded == page)
    }
}

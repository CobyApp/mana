import Testing
import Foundation
import CoreGraphics
import SwiftData
import Domain
@testable import PersistenceKit

@Suite struct TranslationCacheLiveTests {

    private func makeCache() throws -> TranslationCacheLive {
        let stack = try SwiftDataStack.inMemory()
        return TranslationCacheLive(stack: stack)
    }

    private func makePage(_ comicId: UUID, _ pageIndex: Int, target: String = "ko") -> TranslatedPage {
        let box = TextLineBox(id: UUID(), text: "こんにちは",
                              boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1),
                              confidence: 0.9)
        let line = TranslatedLine(original: box, translated: "안녕", backgroundColorARGB: 0xFFFFFFFF)
        return TranslatedPage(
            comicId: comicId, pageIndex: pageIndex,
            sourceLanguage: "ja", targetLanguage: target,
            lines: [line], createdAt: Date()
        )
    }

    @Test func saveAndLoadRoundTrip() async throws {
        let cache = try makeCache()
        let comicId = UUID()
        let page = makePage(comicId, 5)
        try await cache.save(page)

        let loaded = await cache.load(comicId: comicId, pageIndex: 5, targetLanguage: "ko")
        #expect(loaded == page)
    }

    @Test func loadMissReturnsNil() async throws {
        let cache = try makeCache()
        let result = await cache.load(comicId: UUID(), pageIndex: 0, targetLanguage: "ko")
        #expect(result == nil)
    }

    @Test func saveOverwritesByCompositeKey() async throws {
        let cache = try makeCache()
        let comicId = UUID()
        try await cache.save(makePage(comicId, 0))

        let newer = TranslatedPage(
            comicId: comicId, pageIndex: 0,
            sourceLanguage: "ja", targetLanguage: "ko",
            lines: [], createdAt: Date()
        )
        try await cache.save(newer)
        let loaded = await cache.load(comicId: comicId, pageIndex: 0, targetLanguage: "ko")
        #expect(loaded?.lines.isEmpty == true)
    }

    @Test func deleteAllForComicScopesToThatComic() async throws {
        let cache = try makeCache()
        let a = UUID(), b = UUID()
        try await cache.save(makePage(a, 0))
        try await cache.save(makePage(a, 1))
        try await cache.save(makePage(b, 0))

        try await cache.deleteAll(comicId: a)

        #expect(await cache.load(comicId: a, pageIndex: 0, targetLanguage: "ko") == nil)
        #expect(await cache.load(comicId: a, pageIndex: 1, targetLanguage: "ko") == nil)
        #expect(await cache.load(comicId: b, pageIndex: 0, targetLanguage: "ko") != nil)
    }

    @Test func deleteEverythingClearsAll() async throws {
        let cache = try makeCache()
        try await cache.save(makePage(UUID(), 0))
        try await cache.save(makePage(UUID(), 0))

        try await cache.deleteEverything()

        let comicId = UUID()
        #expect(await cache.load(comicId: comicId, pageIndex: 0, targetLanguage: "ko") == nil)
    }
}

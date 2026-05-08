import Testing
import Foundation
@testable import ImageCacheKit

@Suite struct ImageCacheTests {

    @Test func storeAndRetrieveBytesInMemory() async {
        let cache = ImageCache.inMemoryOnly()
        let key = PageKey(comicId: UUID(), pageIndex: 0)
        let bytes = Data([0x01, 0x02, 0x03])
        await cache.store(bytes, for: key)
        let got = await cache.data(for: key)
        #expect(got == bytes)
    }

    @Test func missingKeyReturnsNil() async {
        let cache = ImageCache.inMemoryOnly()
        let got = await cache.data(for: PageKey(comicId: UUID(), pageIndex: 5))
        #expect(got == nil)
    }

    @Test func diskRoundTrip() async throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "imgcache-\(UUID().uuidString)")
        let cache = ImageCache(diskDirectory: dir, diskCapacityBytes: 10_000_000)
        let key = PageKey(comicId: UUID(), pageIndex: 7)
        let bytes = Data(repeating: 0xAB, count: 1024)
        await cache.store(bytes, for: key)
        // Force memory eviction to test disk fallback
        await cache.evictMemory()
        let got = await cache.data(for: key)
        #expect(got == bytes)
        try? FileManager.default.removeItem(at: dir)
    }
}

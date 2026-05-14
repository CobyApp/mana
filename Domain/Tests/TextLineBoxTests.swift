import Testing
import Foundation
import CoreGraphics
@testable import Domain

@Suite struct TextLineBoxTests {
    @Test func codableRoundTrip() throws {
        let id = UUID()
        let original = TextLineBox(
            id: id,
            text: "こんにちは",
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.05),
            confidence: 0.93
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TextLineBox.self, from: data)
        #expect(decoded == original)
    }

    @Test func equalityIgnoresIdentity() {
        let a = TextLineBox(id: UUID(), text: "x", boundingBox: .zero, confidence: 0)
        let b = TextLineBox(id: a.id, text: "x", boundingBox: .zero, confidence: 0)
        let c = TextLineBox(id: UUID(), text: "x", boundingBox: .zero, confidence: 0)
        #expect(a == b)
        #expect(a != c)  // id differs
    }
}

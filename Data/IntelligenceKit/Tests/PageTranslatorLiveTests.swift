import Testing
import Foundation
import CoreGraphics
import UIKit
import Domain
@testable import IntelligenceKit

@MainActor
@Suite struct PageTranslatorLiveTests {

    private func textImagePNG(_ text: String) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 120))
        let img = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 120))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            NSAttributedString(string: text, attributes: attrs)
                .draw(at: CGPoint(x: 20, y: 30))
        }
        return img.pngData()!
    }

    private final class FakeLLM: LLMTranslator, @unchecked Sendable {
        var calls: [(source: String, target: String, lines: [String])] = []
        /// Per-line response. Return nil to simulate a per-line failure
        /// (e.g. safety guardrail).
        var nextResponse: ([String]) -> [String?] = { $0.map { "[T] " + $0 } }

        func translateLines(_ lines: [String], from source: String, to target: String) async -> [String?] {
            calls.append((source, target, lines))
            return nextResponse(lines)
        }
    }

    @Test func translatesEveryOCRLineAsJapanese() async throws {
        let llm = FakeLLM()
        let translator = PageTranslatorLive(llm: llm)
        let data = textImagePNG("Hello")

        let page = try await translator.translate(
            imageData: data, comicId: UUID(), pageIndex: 0, targetLanguage: "ko"
        )

        #expect(!page.lines.isEmpty)
        #expect(page.sourceLanguage == "ja")
        #expect(page.targetLanguage == "ko")
        #expect(llm.calls.count == 1)
        #expect(llm.calls.first?.source == "ja")
        #expect(llm.calls.first?.target == "ko")
        // Every OCR line was sent to the LLM and (since the fake returns
        // non-nil for everything) every line round-trips back as an overlay.
        #expect(llm.calls.first?.lines.count == page.lines.count)
    }

    @Test func skipsLLMWhenTargetIsJapanese() async throws {
        let llm = FakeLLM()
        let translator = PageTranslatorLive(llm: llm)
        let data = textImagePNG("Hello")

        let page = try await translator.translate(
            imageData: data, comicId: UUID(), pageIndex: 0, targetLanguage: "ja"
        )

        #expect(page.lines.isEmpty)
        #expect(page.sourceLanguage == "ja")
        #expect(llm.calls.isEmpty)
    }

    @Test func emptyOCRReturnsEmptyPage() async throws {
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
            .image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            }.pngData()!

        let llm = FakeLLM()
        let translator = PageTranslatorLive(llm: llm)
        let page = try await translator.translate(
            imageData: blank, comicId: UUID(), pageIndex: 0, targetLanguage: "ko"
        )
        #expect(page.lines.isEmpty)
        #expect(page.sourceLanguage == "ja")
        #expect(llm.calls.isEmpty)
    }

    /// When the LLM returns nil for every line (e.g. the Apple Translation
    /// session hasn't attached yet), `PageTranslatorLive` throws
    /// `silentFailure` instead of caching an empty page. This lets the
    /// caller retry once the session becomes available.
    @Test func allNilTranslationsThrowSilentFailure() async throws {
        let llm = FakeLLM()
        llm.nextResponse = { lines in Array(repeating: nil, count: lines.count) }
        let translator = PageTranslatorLive(llm: llm)
        let data = textImagePNG("Hello")

        do {
            _ = try await translator.translate(
                imageData: data, comicId: UUID(), pageIndex: 0, targetLanguage: "ko"
            )
            Issue.record("Expected silentFailure but got success")
        } catch PageTranslatorError.silentFailure {
            // Expected — all-nil from non-empty OCR is a recoverable failure.
        }
        #expect(llm.calls.count == 1)  // LLM was called; it just returned nils
    }


}

// Data/IntelligenceKit/Tests/PageTranslatorLiveTests.swift
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
        var nextResponse: ([String]) -> [String] = { $0.map { "[T] " + $0 } }
        var nextError: LLMTranslatorError?

        func translateLines(_ lines: [String], from source: String, to target: String) async throws -> [String] {
            calls.append((source, target, lines))
            if let err = nextError { throw err }
            return nextResponse(lines)
        }
    }

    @Test func translatesWhenSourceDiffersFromTarget() async throws {
        let llm = FakeLLM()
        let translator = PageTranslatorLive(llm: llm)
        let data = textImagePNG("Hello")

        let page = try await translator.translate(
            imageData: data, comicId: UUID(), pageIndex: 0, targetLanguage: "ja"
        )

        #expect(!page.lines.isEmpty)
        #expect(page.targetLanguage == "ja")
        #expect(page.sourceLanguage == "en")
        #expect(llm.calls.count == 1)
        #expect(llm.calls.first?.target == "ja")
        #expect(page.lines.first?.translated.hasPrefix("[T] ") == true)
    }

    @Test func skipsLLMWhenSourceEqualsTarget() async throws {
        let llm = FakeLLM()
        let translator = PageTranslatorLive(llm: llm)
        let data = textImagePNG("Hello")

        let page = try await translator.translate(
            imageData: data, comicId: UUID(), pageIndex: 0, targetLanguage: "en"
        )

        #expect(page.lines.isEmpty)
        #expect(page.sourceLanguage == "en")
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
        #expect(llm.calls.isEmpty)
    }

    @Test func llmFailureBubblesAsSilentFailure() async throws {
        let llm = FakeLLM()
        llm.nextError = .protocolViolation
        let translator = PageTranslatorLive(llm: llm)
        let data = textImagePNG("Hello")

        do {
            _ = try await translator.translate(
                imageData: data, comicId: UUID(), pageIndex: 0, targetLanguage: "ja"
            )
            Issue.record("expected silent failure")
        } catch PageTranslatorError.silentFailure {
            // expected
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }
}

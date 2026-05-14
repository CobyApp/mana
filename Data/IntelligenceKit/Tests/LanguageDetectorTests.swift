// Data/IntelligenceKit/Tests/LanguageDetectorTests.swift
import Testing
import Foundation
@testable import IntelligenceKit

@Suite struct LanguageDetectorTests {
    private let detector = LanguageDetector()

    @Test func detectsJapaneseHiragana() {
        let lang = detector.detect("こんにちは、元気ですか？")
        #expect(lang == "ja")
    }

    @Test func detectsKorean() {
        let lang = detector.detect("안녕하세요. 오늘 날씨가 좋네요.")
        #expect(lang == "ko")
    }

    @Test func detectsEnglish() {
        let lang = detector.detect("Hello there, how are you doing today?")
        #expect(lang == "en")
    }

    @Test func returnsUndForEmpty() {
        #expect(detector.detect("") == "und")
    }

    @Test func returnsUndForOnlyPunctuation() {
        let lang = detector.detect("!!!???")
        #expect(lang == "und")
    }
}

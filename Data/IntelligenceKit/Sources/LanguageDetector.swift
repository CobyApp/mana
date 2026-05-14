// Data/IntelligenceKit/Sources/LanguageDetector.swift
import Foundation
import NaturalLanguage

public struct LanguageDetector: Sendable {
    public init() {}

    /// Detects the dominant language of `text`, constrained to {ja, ko, en}.
    /// Returns BCP-47: "ja", "ko", "en", or "und" if no signal exists or the
    /// result falls outside the constraint set.
    public func detect(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "und" }

        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.japanese, .korean, .english]
        recognizer.processString(trimmed)

        guard let lang = recognizer.dominantLanguage else { return "und" }
        switch lang {
        case .japanese: return "ja"
        case .korean:   return "ko"
        case .english:  return "en"
        default:        return "und"
        }
    }
}

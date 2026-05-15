// Data/IntelligenceKit/Sources/LLMTranslator.swift
import Foundation

/// Internal seam over the on-device LLM so PageTranslatorLive can be tested
/// without a real Foundation Models call.
///
/// The return shape is `[String?]` — same length as the input. `nil` entries
/// indicate a per-line failure (safety guardrails, model error, etc.). The
/// caller drops those rather than failing the whole page.
public protocol LLMTranslator: Sendable {
    func translateLines(_ lines: [String], from source: String, to target: String) async -> [String?]
}

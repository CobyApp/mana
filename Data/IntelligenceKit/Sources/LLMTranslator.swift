// Data/IntelligenceKit/Sources/LLMTranslator.swift
import Foundation

/// Internal seam over the on-device LLM so PageTranslatorLive can be tested
/// without a real Foundation Models call.
package protocol LLMTranslator: Sendable {
    /// Translates `lines` from `source` (BCP-47) to `target` (BCP-47).
    /// MUST return an array of the same length as `lines`.
    /// Throws `LLMTranslatorError.protocolViolation` on count mismatch /
    /// parse failure, or rethrows underlying model errors.
    func translateLines(_ lines: [String], from source: String, to target: String) async throws -> [String]
}

package enum LLMTranslatorError: Error, Sendable {
    case protocolViolation
    case modelUnavailable
}

// Data/IntelligenceKit/Sources/FoundationModelsTranslator.swift
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

@available(iOS 26.0, *)
package struct FoundationModelsTranslator: LLMTranslator {
    package init() {}

    // `fileprivate` instead of `private`: @Generable expands a top-level extension
    // conformance that requires at least fileprivate visibility.
    @Generable
    fileprivate struct TranslationResponse {
        let lines: [String]
    }

    package func translateLines(_ lines: [String], from source: String, to target: String) async throws -> [String] {
        guard !lines.isEmpty else { return [] }
        let instructions = """
        You translate manga dialogue from \(humanReadable(source)) to \(humanReadable(target)).
        Rules:
        - Source language is one of: Japanese, Korean, English.
        - Target language is one of: Japanese, Korean, English.
        - Translate each line independently. Preserve speaker tone.
        - Keep onomatopoeia (e.g. ドキドキ) untranslated; copy them verbatim.
        - Do not merge or split lines.
        - Output an array `lines` of the same length as the input.
        """

        let inputJSON: String
        do {
            let data = try JSONEncoder().encode(["lines": lines])
            inputJSON = String(decoding: data, as: UTF8.self)
        } catch {
            throw LLMTranslatorError.protocolViolation
        }

        let session = LanguageModelSession(
            model: SystemLanguageModel.default,
            instructions: instructions
        )
        let response: LanguageModelSession.Response<TranslationResponse>
        do {
            response = try await session.respond(
                to: "Input: \(inputJSON)\nReturn JSON only.",
                generating: TranslationResponse.self
            )
        } catch {
            throw LLMTranslatorError.modelUnavailable
        }

        let translated = response.content.lines
        guard translated.count == lines.count else {
            throw LLMTranslatorError.protocolViolation
        }
        return translated
    }

    private func humanReadable(_ bcp47: String) -> String {
        switch bcp47 {
        case "ja": return "Japanese"
        case "ko": return "Korean"
        case "en": return "English"
        default:   return bcp47
        }
    }
}

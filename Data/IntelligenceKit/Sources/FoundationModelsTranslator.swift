// Data/IntelligenceKit/Sources/FoundationModelsTranslator.swift
import Foundation
import os
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Translates lines via Apple's on-device language model, one line per LLM call.
///
/// Per-line (rather than batch) is the strategy because:
/// - Apple Intelligence's safety guardrails fire frequently on manga content.
///   Per-line isolation means one tripped line doesn't poison the whole page.
/// - Batch responses sometimes return a different count than requested,
///   forcing us to drop the entire page. Per-line is always 1:1.
///
/// Concurrency is bounded so we don't slam the model with 30+ simultaneous
/// requests on a long page.
@available(iOS 26.0, *)
public struct FoundationModelsTranslator: LLMTranslator {
    private static let log = Logger(subsystem: "com.coby.mana", category: "translation.llm")
    private static let maxConcurrent = 4

    public init() {}

    public func translateLines(_ lines: [String], from source: String, to target: String) async -> [String?] {
        guard !lines.isEmpty else { return [] }

        // The instructions are intentionally bland — words like "manga" or
        // "dialogue" raised the rate at which Apple Intelligence's safety
        // layer rejected requests. Plain "translate text" works better.
        let instructions = """
        You translate \(humanReadable(source)) text into \(humanReadable(target)). \
        Reply with only the translated text, nothing else. \
        Keep onomatopoeia and sound effects as-is without translating them.
        """

        return await withTaskGroup(of: (Int, String?).self) { group in
            var pending = lines.enumerated().makeIterator()
            var inFlight = 0
            var results: [String?] = Array(repeating: nil, count: lines.count)

            func spawnNext() {
                guard let (idx, line) = pending.next() else { return }
                group.addTask {
                    let result = await Self.translateOne(line, instructions: instructions)
                    return (idx, result)
                }
                inFlight += 1
            }

            // Seed.
            for _ in 0..<min(Self.maxConcurrent, lines.count) {
                spawnNext()
            }

            // Drain + refill.
            while inFlight > 0 {
                if let (idx, value) = await group.next() {
                    results[idx] = value
                    inFlight -= 1
                    spawnNext()
                }
            }
            return results
        }
    }

    private static func translateOne(_ line: String, instructions: String) async -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let session = LanguageModelSession(
            model: SystemLanguageModel.default,
            instructions: instructions
        )
        do {
            let response = try await session.respond(to: trimmed)
            let translated = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return translated.isEmpty ? nil : translated
        } catch {
            // Safety guardrails, transient model failure, anything else —
            // log at info, drop this line. The page renders without an
            // overlay on that bbox; the rest still get their translation.
            log.info("per-line LLM failure for \(trimmed.prefix(40), privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
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

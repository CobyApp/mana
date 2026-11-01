import Foundation
import Domain

/// Routes per-page line translation to the engine chosen in settings: Apple's on-device
/// Translation framework, or Gemini (cloud). Gemini gets the whole page's lines in one call for
/// panel context; on any Gemini failure or a missing key it falls back to Apple, mirroring the
/// Android `DefaultMangaTranslator` behaviour.
public struct EngineRoutingTranslator: LLMTranslator {
    public struct Config: Sendable {
        public let engine: TranslationEngine
        public let apiKey: String
        public let model: String
        /// Optional key bundled at build time (used when the user hasn't entered one).
        public let defaultKey: String

        public init(engine: TranslationEngine, apiKey: String, model: String, defaultKey: String) {
            self.engine = engine
            self.apiKey = apiKey
            self.model = model
            self.defaultKey = defaultKey
        }
    }

    private let configProvider: @Sendable () -> Config
    private let apple: AppleTranslator
    private let gemini: GeminiTranslator

    public init(
        configProvider: @escaping @Sendable () -> Config,
        apple: AppleTranslator = AppleTranslator(),
        gemini: GeminiTranslator = GeminiTranslator()
    ) {
        self.configProvider = configProvider
        self.apple = apple
        self.gemini = gemini
    }

    public func translateLines(_ lines: [String], from source: String, to target: String) async -> [String?] {
        guard !lines.isEmpty else { return [] }
        let cfg = configProvider()
        let key = cfg.apiKey.isEmpty ? cfg.defaultKey : cfg.apiKey
        if cfg.engine == .gemini, !key.isEmpty {
            do {
                let out = try await gemini.translate(lines, targetLanguage: target, apiKey: key, model: cfg.model)
                // Map empty strings (watermarks / blanks) to nil so the caller drops them.
                return out.map { $0.isEmpty ? nil : $0 }
            } catch {
                // Fall back to on-device translation on any API error.
                return await apple.translateLines(lines, from: source, to: target)
            }
        }
        return await apple.translateLines(lines, from: source, to: target)
    }
}

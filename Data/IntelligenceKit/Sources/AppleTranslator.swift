import Foundation
import Domain

public struct AppleTranslator: LLMTranslator {
    public init() {}

    public func translateLines(_ lines: [String], from source: String, to target: String) async -> [String?] {
        guard !lines.isEmpty else { return [] }
        if #available(iOS 18.0, *) {
            return await TranslationSessionHolder.shared.translate(lines)
        }
        return Array(repeating: nil, count: lines.count)
    }
}

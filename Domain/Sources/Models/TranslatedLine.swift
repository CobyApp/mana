import Foundation

public struct TranslatedLine: Equatable, Sendable, Hashable, Codable {
    public let original: TextLineBox
    public let translated: String
    /// ARGB packed UInt32 (alpha in the high byte).
    public let backgroundColorARGB: UInt32

    public init(original: TextLineBox, translated: String, backgroundColorARGB: UInt32) {
        self.original = original
        self.translated = translated
        self.backgroundColorARGB = backgroundColorARGB
    }
}

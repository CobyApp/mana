import Foundation

/// Which engine translates recognized manga text.
///
/// The iOS counterpart of Android's engine choice. Android offers on-device ML Kit vs Gemini;
/// iOS has no ML Kit JA→KO model, so the on-device slot is Apple's own stack (Vision OCR +
/// the Apple Translation framework). The choice is therefore Apple (on-device, free, iOS 18+)
/// vs Gemini (cloud, needs a key, higher quality with whole-page panel context).
public enum TranslationEngine: String, Sendable, Equatable, Hashable, CaseIterable {
    /// On-device Apple Translation framework (free, offline, iOS 18+).
    case apple

    /// Google Gemini via the Generative Language API (needs network + key, much higher quality).
    case gemini

    public init(rawStringOrDefault raw: String) {
        self = TranslationEngine(rawValue: raw) ?? .apple
    }
}

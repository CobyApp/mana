import Foundation

public protocol PageTranslator: Sendable {
    /// OCR + language detection + LLM translation for one page.
    ///
    /// Returns a `TranslatedPage` on success. The result may have an empty
    /// `lines` array — that is a valid "no work to do" outcome (no text on
    /// page, or source language already matches target). Empty results are
    /// still meant to be cached so we don't re-OCR on revisit.
    ///
    /// Throws only on unrecoverable errors (e.g. `CancellationError`).
    /// Recoverable failures (model unavailable, LLM mismatch) are surfaced
    /// by throwing `PageTranslatorError.silentFailure` so callers can
    /// distinguish "no cache" from "empty result".
    func translate(
        imageData: Data,
        comicId: UUID,
        pageIndex: Int,
        targetLanguage: String
    ) async throws -> TranslatedPage
}

public enum PageTranslatorError: Error, Sendable {
    /// Recoverable failure. The caller should not cache the result.
    case silentFailure
}

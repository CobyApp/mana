import Foundation
#if canImport(Translation)
@preconcurrency import Translation
#endif

/// Holds the active `TranslationSession` produced by a SwiftUI `.translationTask`
/// modifier so non-SwiftUI code (our LLM translator) can use it.
///
/// The session is stored as `Any?` so that the property declaration compiles at
/// iOS 17.0 deployment target — `TranslationSession` is iOS 18.0+ only.
///
/// When no session is attached (the Reader view is off-screen or the first-time
/// language-pack download UI hasn't completed), `translate(_:)` returns all-nil
/// for every input. The caller (`PageTranslatorLive`) treats an all-nil result
/// from a non-empty OCR output as `silentFailure`, so the page is never cached
/// as empty and the translation is retried once the session becomes available.
@MainActor
public final class TranslationSessionHolder: @unchecked Sendable {
    public static let shared = TranslationSessionHolder()

    /// Stores a `TranslationSession` as `Any?` to avoid an `@available`
    /// annotation on the property, which Swift does not support.
    private var anySession: Any?

    public init() {}

    /// Set or clear the currently active session. Called from
    /// `ReaderView.translationTask`.
    public func set(_ session: Any?) {
        self.anySession = session
    }

    /// Translate a batch of strings using the currently attached session.
    /// Returns `[String?]` aligned with the input — nil for any per-line
    /// failure. Returns all-nil if no session is attached.
    ///
    /// Implementation note: `TranslationSession` and its `Request` type are
    /// not `Sendable`. All work runs on the `@MainActor`. The actor is
    /// released during the `await` suspension point, so this does not block
    /// the UI thread. We use `withCheckedContinuation` to avoid Swift 6
    /// data-race diagnostics caused by sending non-Sendable values across
    /// async boundaries.
    @available(iOS 18.0, *)
    public func translate(_ lines: [String]) async -> [String?] {
        guard let session = anySession as? TranslationSession else {
            return Array(repeating: nil, count: lines.count)
        }
        // Build requests on the MainActor; the `nonisolated(unsafe)` local
        // lets us carry them into the continuation without triggering Swift 6
        // "sending non-Sendable" errors.
        let requests = lines.map { TranslationSession.Request(sourceText: $0) }
        nonisolated(unsafe) let safeRequests = requests
        nonisolated(unsafe) let safeSession = session
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                do {
                    let responses = try await safeSession.translations(from: safeRequests)
                    continuation.resume(returning: responses.map { $0.targetText })
                } catch {
                    continuation.resume(returning: Array(repeating: nil, count: lines.count))
                }
            }
        }
    }
}

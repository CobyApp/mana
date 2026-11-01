import Foundation

/// Tracks chapters read while streaming online (so the detail can mark them even if not downloaded).
public protocol ReadChapterRepository: Sendable {
    func readURLs() async -> Set<String>
    func observeReadURLs() -> AsyncStream<Set<String>>
    func markRead(chapterURL: String) async
}

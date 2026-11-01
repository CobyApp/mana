import Foundation
import os
import Domain
import SourceKit
import LibraryFeature
import ZIPFoundation
import UserNotifications

// MARK: - Array chunking

private extension Array {
    func chunked(_ size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

// MARK: - ChapterDownloader

/// Downloads a chapter's page images (with the source's required headers), packs them into a
/// zero-padded .cbz, imports it, titles it after the chapter, and files it into a library folder
/// named after the series. Ported from Android `DefaultChapterDownloader`.
public struct ChapterDownloaderLive: ChapterDownloader {
    private let source: any MangaSource
    private let http: SourceHTTP
    private let importer: any LibraryImporter
    private let comicRepo: any ComicRepository
    private let folderRepo: any FolderRepository

    private static let maxConcurrentPages = 6
    private static let maxFetchAttempts = 3
    private static let retryBackoffMillis: UInt64 = 600

    public init(
        source: any MangaSource,
        http: SourceHTTP,
        importer: any LibraryImporter,
        comicRepo: any ComicRepository,
        folderRepo: any FolderRepository
    ) {
        self.source = source
        self.http = http
        self.importer = importer
        self.comicRepo = comicRepo
        self.folderRepo = folderRepo
    }

    public func download(
        chapterURL: String,
        seriesURL: String,
        seriesTitle: String,
        chapterName: String,
        seriesCoverURL: String?,
        onProgress: @Sendable @escaping (Int, Int) -> Void
    ) async throws -> ComicItem {
        let urls = try await source.pages(chapterURL: chapterURL)
        guard !urls.isEmpty else { throw DownloadError.noPages }
        let headers = source.imageHeaders()
        let total = urls.count
        onProgress(0, total)

        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appending(path: "mana-dl-\(UUID().uuidString)")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        var written = 0
        for (chunkIndex, chunk) in urls.chunked(Self.maxConcurrentPages).enumerated() {
            let fetched = try await withThrowingTaskGroup(of: (Int, Data).self) { group -> [Int: Data] in
                for (i, u) in chunk.enumerated() {
                    group.addTask { (i, try await fetchPage(u, headers: headers)) }
                }
                var dict: [Int: Data] = [:]
                for try await (i, data) in group { dict[i] = data }
                return dict
            }
            for i in 0..<chunk.count {
                guard let data = fetched[i] else { continue }
                let index = chunkIndex * Self.maxConcurrentPages + i
                let name = String(format: "%03d.%@", index + 1, extensionOf(urls[index]))
                try data.write(to: tmp.appending(path: name))
                written += 1
                onProgress(written, total)
            }
        }

        let cbz = fm.temporaryDirectory
            .appending(path: "\(ComicNaming.cbzBaseName(chapterName: chapterName))-\(UUID().uuidString).cbz")
        try? fm.removeItem(at: cbz)
        try fm.zipItem(at: tmp, to: cbz, shouldKeepParent: false)
        defer { try? fm.removeItem(at: cbz) }

        let folder = try await findOrCreateFolder(name: ComicNaming.seriesFolderName(title: seriesTitle, url: seriesURL), sourceURL: seriesURL)
        let imported = try await importer.importFiles([cbz], folderId: folder.id)
        guard let comic = imported.first else { throw DownloadError.importFailed }

        // Retitle to the clean chapter name (importer titles from the temp file name).
        let titled = ComicItem(
            id: comic.id, url: comic.url, format: comic.format, title: chapterName,
            pageCount: comic.pageCount, coverThumbnail: comic.coverThumbnail, dateAdded: comic.dateAdded,
            fileSizeBytes: comic.fileSizeBytes, readingMode: comic.readingMode, folderId: folder.id,
            pageProgressionDirection: comic.pageProgressionDirection, pageOffset: comic.pageOffset
        )
        try await comicRepo.upsert(titled)
        return titled
    }

    private func fetchPage(_ url: String, headers: [String: String]) async throws -> Data {
        var lastError: Error?
        for attempt in 0..<Self.maxFetchAttempts {
            do {
                return try await http.getBytes(url, headers: headers)
            } catch {
                lastError = error
                if attempt < Self.maxFetchAttempts - 1 {
                    try? await Task.sleep(nanoseconds: Self.retryBackoffMillis * UInt64(attempt + 1) * 1_000_000)
                }
            }
        }
        throw lastError ?? DownloadError.fetchFailed(url)
    }

    private func findOrCreateFolder(name: String, sourceURL: String) async throws -> Folder {
        let all = await folderRepo.all()
        if let existing = all.first(where: { $0.name == name }) { return existing }
        let folder = Folder(id: UUID(), name: name, dateAdded: Date(), sourceURL: sourceURL)
        try await folderRepo.upsert(folder)
        return folder
    }

    private func extensionOf(_ url: String) -> String {
        let beforeQuery = url.components(separatedBy: "?").first ?? url
        let ext = (beforeQuery as NSString).pathExtension.lowercased()
        let ok = (1...4).contains(ext.count) && ext.allSatisfy { $0.isLetter || $0.isNumber }
        return ok ? ext : "jpg"
    }

    public enum DownloadError: Error, Sendable { case noPages, importFailed, fetchFailed(String) }
}

// MARK: - DownloadQueueStore

/// JSON-file-backed durable queue (Application Support). Ported from Android `DownloadQueueStore`.
public actor DownloadQueueStoreLive: DownloadQueueStore {
    private let fileURL: URL
    private var cache: [PersistedDownload]?

    public init(fileURL: URL = URL.applicationSupportDirectory.appending(path: "mana-download-queue.json")) {
        self.fileURL = fileURL
    }

    private func loaded() -> [PersistedDownload] {
        if let cache { return cache }
        let data = (try? Data(contentsOf: fileURL)) ?? Data()
        let list = (try? JSONDecoder().decode([PersistedDownload].self, from: data)) ?? []
        cache = list
        return list
    }

    private func persist(_ list: [PersistedDownload]) {
        cache = list
        if let data = try? JSONEncoder().encode(list) { try? data.write(to: fileURL) }
    }

    public func add(_ download: PersistedDownload) async {
        var list = loaded()
        guard !list.contains(where: { $0.chapterURL == download.chapterURL }) else { return }
        list.append(download)
        persist(list)
    }

    public func remove(chapterURL: String) async {
        persist(loaded().filter { $0.chapterURL != chapterURL })
    }

    public func clear() async { persist([]) }

    public func all() async -> [PersistedDownload] { loaded() }
}

// MARK: - DownloadNotifier

/// Posts a local notification when a chapter download completes. iOS has no persistent progress
/// notification like Android, so this surfaces completion only. No-ops gracefully if not authorized.
public struct DownloadNotifier: Sendable {
    public init() {}

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func notifyCompleted(series: String, chapter: String) {
        let content = UNMutableNotificationContent()
        content.title = series
        content.body = chapter
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - ReadChapterRepository

/// Tracks chapters read while streaming online, persisted to UserDefaults. Ported from Android
/// `ReadChapterRepository`.
public final class ReadChapterRepositoryLive: ReadChapterRepository, @unchecked Sendable {
    private let key = "mana.readChapterURLs"
    private let lock = NSLock()
    private var urls: Set<String>
    private var continuations: [UUID: AsyncStream<Set<String>>.Continuation] = [:]

    public init() {
        let stored = UserDefaults.standard.stringArray(forKey: key) ?? []
        urls = Set(stored)
    }

    private func withLockSync<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }; return body()
    }

    public func readURLs() async -> Set<String> {
        withLockSync { urls }
    }

    public func observeReadURLs() -> AsyncStream<Set<String>> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            continuation.yield(urls)
            lock.unlock()
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.lock(); self.continuations[id] = nil; self.lock.unlock()
            }
        }
    }

    public func markRead(chapterURL: String) async {
        let (snapshot, conts): (Set<String>, [AsyncStream<Set<String>>.Continuation]) = withLockSync {
            urls.insert(chapterURL)
            UserDefaults.standard.set(Array(urls), forKey: key)
            return (urls, Array(continuations.values))
        }
        for c in conts { c.yield(snapshot) }
    }
}

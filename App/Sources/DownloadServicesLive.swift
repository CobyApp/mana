import Foundation
import os
import Domain
import SourceKit
import LibraryFeature
import ZIPFoundation
import UserNotifications
import UIKit
import ImageIO

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

    private static let maxConcurrentPages = 8
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

        // Sliding window: keep `maxConcurrentPages` fetches in flight at all times so one slow page
        // doesn't stall a whole batch, and write each page to disk as soon as it lands.
        try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            var next = 0
            func addNext() {
                guard next < total else { return }
                let index = next
                let url = urls[index]
                group.addTask { (index, try await fetchPage(url, headers: headers)) }
                next += 1
            }
            for _ in 0..<min(Self.maxConcurrentPages, total) { addNext() }
            var written = 0
            while let (index, data) = try await group.next() {
                let name = String(format: "%03d.%@", index + 1, extensionOf(urls[index]))
                try data.write(to: tmp.appending(path: name))
                written += 1
                onProgress(written, total)
                addNext()
            }
        }

        let cbz = fm.temporaryDirectory
            .appending(path: "\(ComicNaming.cbzBaseName(chapterName: chapterName))-\(UUID().uuidString).cbz")
        try? fm.removeItem(at: cbz)
        try fm.zipItem(at: tmp, to: cbz, shouldKeepParent: false)
        defer { try? fm.removeItem(at: cbz) }

        let folder = try await findOrCreateFolder(name: ComicNaming.seriesFolderName(title: seriesTitle, url: seriesURL), sourceURL: seriesURL)
        // Auto folder cover: the first time we download into a folder without a cover, use the
        // online series' cover art (downsampled) so it shows the book cover. Failures are ignored.
        if folder.coverImage == nil, let seriesCoverURL {
            if let bytes = try? await http.getBytes(seriesCoverURL, headers: headers),
               let cover = Self.downsampledJPEG(bytes, maxPixel: 512) {
                try? await folderRepo.setCover(folderId: folder.id, image: cover)
            }
        }
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
        // Let an open library pick up the new comic + series folder.
        await MainActor.run { NotificationCenter.default.post(name: .manaLibraryReconciled, object: nil) }
        return titled
    }

    private func fetchPage(_ url: String, headers: [String: String]) async throws -> Data {
        var lastError: Error?
        for attempt in 0..<Self.maxFetchAttempts {
            do {
                return try await http.getBytes(url, headers: headers)
            } catch let SourceHTTP.HTTPError.status(code, _) where (400..<500).contains(code) && code != 408 && code != 429 {
                // Permanent client error (missing page, forbidden) — retrying won't help.
                throw DownloadError.fetchFailed(url)
            } catch {
                try Task.checkCancellation()
                lastError = error
                if attempt < Self.maxFetchAttempts - 1 {
                    try? await Task.sleep(nanoseconds: Self.retryBackoffMillis * UInt64(attempt + 1) * 1_000_000)
                }
            }
        }
        throw lastError ?? DownloadError.fetchFailed(url)
    }

    private func findOrCreateFolder(name: String, sourceURL: String) async throws -> Folder {
        try await SeriesFolderGate.shared.findOrCreate(name: name, sourceURL: sourceURL, repo: folderRepo)
    }

    private func extensionOf(_ url: String) -> String {
        let beforeQuery = url.components(separatedBy: "?").first ?? url
        let ext = (beforeQuery as NSString).pathExtension.lowercased()
        let ok = (1...4).contains(ext.count) && ext.allSatisfy { $0.isLetter || $0.isNumber }
        return ok ? ext : "jpg"
    }

    /// Decodes `data` at most `maxPixel` on its long edge (ImageIO thumbnailing, no full decode)
    /// and re-encodes it as JPEG. Returns nil if the bytes aren't a decodable image.
    static func downsampledJPEG(_ data: Data, maxPixel: Int) -> Data? {
        guard !data.isEmpty,
              let src = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg).jpegData(compressionQuality: 0.85)
    }

    public enum DownloadError: Error, Sendable { case noPages, importFailed, fetchFailed(String) }
}

/// Serialises series-folder lookup/creation so two chapters of the same series downloading in
/// parallel can't both create the folder.
private actor SeriesFolderGate {
    static let shared = SeriesFolderGate()

    /// Actor methods are re-entrant across `await`, so chain each call behind the previous one.
    private var tail: Task<Void, Never>?

    func findOrCreate(name: String, sourceURL: String, repo: any FolderRepository) async throws -> Folder {
        let previous = tail
        let work = Task { () async throws -> Folder in
            await previous?.value
            let all = await repo.all()
            if let existing = all.first(where: { $0.name == name }) { return existing }
            let folder = Folder(id: UUID(), name: name, dateAdded: Date(), sourceURL: sourceURL)
            try await repo.upsert(folder)
            return folder
        }
        tail = Task { _ = try? await work.value }
        return try await work.value
    }
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

    /// Routes notification taps to `noiz://downloads` and lets completions show while the app is
    /// in the foreground.

    public func installTapHandler() {
        UNUserNotificationCenter.current().delegate = DownloadNotificationDelegate.shared
    }

    public func notifyCompleted(series: String, chapter: String) {
        let content = UNMutableNotificationContent()
        content.title = series
        content.body = chapter
        content.userInfo = ["url": "noiz://downloads"]
        content.threadIdentifier = series
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

final class DownloadNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = DownloadNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let raw = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: raw) else { return }
        await MainActor.run { UIApplication.shared.open(url) }
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

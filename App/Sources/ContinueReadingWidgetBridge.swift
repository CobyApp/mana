import Foundation
import WidgetKit
import Domain
import LibraryFeature

/// Feeds the "continue reading" home-screen widget: writes the most recently read comic (title,
/// page, cover thumbnail) into the shared App Group container and reloads widget timelines
/// whenever reading progress or the library changes. The widget target reads the same files —
/// keep `ContinueReadingSnapshot` / file names in sync with `App/Widget/Sources`.
struct ContinueReadingWidgetBridge: Sendable {
    static let appGroup = "group.com.coby.mana"
    static let snapshotFile = "continue-reading.json"
    static let coverFile = "continue-reading-cover.dat"

    private struct Snapshot: Codable {
        let comicId: String
        let title: String
        let page: Int
        let total: Int
        let updatedAt: Date
    }

    let progressRepo: any ProgressRepository
    let comicRepo: any ComicRepository

    /// Writes an initial snapshot, then keeps it fresh for the app's lifetime.
    func start() {
        Task.detached(priority: .utility) {
            await refresh()
            await withTaskGroup(of: Void.self) { group in
                for name in [Notification.Name.manaProgressUpdated, .manaLibraryReconciled] {
                    group.addTask {
                        for await _ in NotificationCenter.default.notifications(named: name).map({ _ in () }) {
                            await refresh()
                        }
                    }
                }
            }
        }
    }

    func refresh() async {
        guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup) else { return }
        let snapshotURL = dir.appending(path: Self.snapshotFile)
        let coverURL = dir.appending(path: Self.coverFile)

        var latest: (ReadingProgress, ComicItem)?
        for p in await progressRepo.all().sorted(by: { $0.updatedAt > $1.updatedAt }) {
            if let comic = await comicRepo.comic(id: p.comicId) { latest = (p, comic); break }
        }

        if let (progress, comic) = latest {
            let snap = Snapshot(
                comicId: comic.id.uuidString, title: comic.title,
                page: progress.lastPageIndex, total: max(progress.totalPages, comic.pageCount ?? 0),
                updatedAt: progress.updatedAt
            )
            if let data = try? JSONEncoder().encode(snap) { try? data.write(to: snapshotURL, options: .atomic) }
            if let cover = comic.coverThumbnail {
                try? cover.write(to: coverURL, options: .atomic)
            } else {
                try? FileManager.default.removeItem(at: coverURL)
            }
        } else {
            try? FileManager.default.removeItem(at: snapshotURL)
            try? FileManager.default.removeItem(at: coverURL)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

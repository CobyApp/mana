import Foundation
import Domain
import LibraryFeature

/// Runs once at app launch to keep the SwiftData catalog and the on-disk
/// library folder in sync.
///
/// Handles three cases:
/// 1. **Legacy migration** — moves files left in the old `Documents/Mana
///    Library/` location to the new Application Support location and rewrites
///    affected catalog entries.
/// 2. **Reindex** — picks up files that exist on disk but have no catalog
///    entry (e.g. after a reinstall that preserved Application Support via
///    backup) and imports them.
/// 3. **Orphan cleanup** — deletes catalog entries whose backing file no
///    longer exists.
public struct LibraryReconcileService: Sendable {
    let repo: any ComicRepository
    let importer: any LibraryImporter

    public init(repo: any ComicRepository, importer: any LibraryImporter) {
        self.repo = repo
        self.importer = importer
    }

    public func reconcile() async {
        let fm = FileManager.default
        let libraryDir = LibraryStorage.libraryDirectory
        let legacyDir = LibraryStorage.legacyLibraryDirectory
        try? fm.createDirectory(at: libraryDir, withIntermediateDirectories: true)

        migrateLegacyFiles(fm: fm, legacyDir: legacyDir, libraryDir: libraryDir)

        let comics = await repo.all()
        await rewriteLegacyURLs(comics: comics, legacyDir: legacyDir, libraryDir: libraryDir)

        // Refresh catalog snapshot after URL rewrites.
        let refreshedComics = await repo.all()
        await deleteOrphans(comics: refreshedComics, fm: fm)

        await importNewFiles(libraryDir: libraryDir, fm: fm)

        await MainActor.run {
            NotificationCenter.default.post(name: .manaLibraryReconciled, object: nil)
        }
    }

    private func migrateLegacyFiles(fm: FileManager, legacyDir: URL, libraryDir: URL) {
        guard fm.fileExists(atPath: legacyDir.path) else { return }
        let contents = (try? fm.contentsOfDirectory(at: legacyDir, includingPropertiesForKeys: nil)) ?? []
        for url in contents {
            let dest = libraryDir.appending(path: url.lastPathComponent)
            if fm.fileExists(atPath: dest.path) {
                try? fm.removeItem(at: url)
            } else {
                try? fm.moveItem(at: url, to: dest)
            }
        }
        try? fm.removeItem(at: legacyDir)
    }

    private func rewriteLegacyURLs(comics: [ComicItem], legacyDir: URL, libraryDir: URL) async {
        let legacyPath = legacyDir.standardizedFileURL.path
        for comic in comics {
            let comicPath = comic.url.standardizedFileURL.path
            guard comicPath.hasPrefix(legacyPath) else { continue }
            let newURL = libraryDir.appending(path: comic.url.lastPathComponent)
            let rewritten = ComicItem(
                id: comic.id,
                url: newURL,
                format: comic.format,
                title: comic.title,
                pageCount: comic.pageCount,
                coverThumbnail: comic.coverThumbnail,
                dateAdded: comic.dateAdded,
                fileSizeBytes: comic.fileSizeBytes,
                readingMode: comic.readingMode,
                folderId: comic.folderId,
                pageProgressionDirection: comic.pageProgressionDirection
            )
            try? await repo.upsert(rewritten)
        }
    }

    private func deleteOrphans(comics: [ComicItem], fm: FileManager) async {
        for comic in comics where !fm.fileExists(atPath: comic.url.path) {
            try? await repo.delete(comic.id)
        }
    }

    private func importNewFiles(libraryDir: URL, fm: FileManager) async {
        let onDisk = (try? fm.contentsOfDirectory(at: libraryDir, includingPropertiesForKeys: nil)) ?? []
        // The library is a single flat directory, so the file name is enough
        // to identify a comic. Comparing absolute paths is fragile because
        // iOS sometimes hands us /var paths and sometimes /private/var paths
        // for the same file, and because external importers can supply NFD
        // filenames while APFS reports NFC ones. Either mismatch made
        // reconcile re-import every comic on launch.
        let catalogedNames: Set<String> = Set(
            await repo.all().map { Self.canonicalName($0.url) }
        )
        let unknown = onDisk.filter { !catalogedNames.contains(Self.canonicalName($0)) }
        guard !unknown.isEmpty else { return }
        _ = try? await importer.importFiles(unknown, folderId: nil)
    }

    private static func canonicalName(_ url: URL) -> String {
        url.lastPathComponent.precomposedStringWithCanonicalMapping
    }
}


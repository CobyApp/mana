# Mana — Plan 3: iCloud Sync (Metadata + Files)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use `- [ ]` checkboxes.

**Goal:** Add iCloud sync of comic metadata (via SwiftData + CloudKit) AND archive files (via iCloud Drive ubiquity container). Cross-device pickup: a comic imported on one device shows up on another with a download indicator until the archive is fetched from iCloud.

**Architecture:** Pure additions on top of Plan 2's foundation. Plan 1's `FileSyncService` Domain protocol is finally implemented in a new `Data/CloudSyncKit` module. `SwiftDataStack.cloudKit(...)` factory replaces the on-disk one in production. `ComicEntity` gains `urlBookmarkData: Data?` (resolves stale-bookmark cases). `LibraryImporterLive` ingests through `FileSyncService` so files land in the ubiquity container instead of an arbitrary picker URL.

**Tech Stack:** Same as Plan 2, plus `CloudKit` (system framework — no SPM dep). Required entitlements: `com.apple.developer.icloud-services = ["CloudKit"]`, `com.apple.developer.icloud-container-identifiers = ["iCloud.com.example.mana"]`, `com.apple.developer.ubiquity-container-identifiers = ["iCloud.com.example.mana"]`.

**Important runtime caveat:** iCloud features only work on a code-signed build with a real Apple Developer account configured. Without it (e.g. `CODE_SIGNING_ALLOWED=NO`), the app falls back to local-only mode and `FileSyncService.isAvailable` returns false. Tests use `FileSyncServiceMock`; integration test stays in-memory.

---

## File Structure (added/modified)

```
Mana/
├── App/
│   ├── Project.swift                              [M] — entitlements + CloudSyncKit dep
│   ├── Resources/Mana.entitlements                [+]
│   └── Sources/
│       ├── DependenciesLive.swift                 [M] — choose CloudKit or local stack at boot
│       └── LibraryImporterLive.swift              [M] — ingest via FileSyncService, store bookmark data
├── Data/
│   ├── CloudSyncKit/                              [+] — new module
│   │   ├── Project.swift
│   │   ├── Sources/
│   │   │   ├── FileSyncServiceLive.swift          — NSFileCoordinator + NSMetadataQuery impl
│   │   │   ├── UbiquityContainer.swift            — small wrapper around URL.forUbiquityContainerIdentifier
│   │   │   └── BookmarkURLResolver.swift          — security-scoped bookmark encode/decode
│   │   └── Tests/
│   │       ├── BookmarkURLResolverTests.swift
│   │       └── FileSyncServiceLiveTests.swift     — uses local temp dir as fake ubiquity
│   └── PersistenceKit/
│       ├── Sources/
│       │   ├── SwiftDataStack.swift               [M] — add cloudKit(containerIdentifier:) factory
│       │   ├── SwiftDataModels.swift              [M] — add urlBookmarkData: Data?
│       │   └── ComicRepositoryLive.swift          [M] — round-trip new field
│       └── Tests/
│           └── ComicRepositoryLiveTests.swift     [M] — bookmark data round-trip
├── Domain/
│   └── Sources/Models/ComicItem.swift             [M] — add urlBookmarkData: Data? field
├── Features/
│   ├── LibraryFeature/Sources/LibraryFeature.swift [M] — observe FileSyncService changes
│   ├── LibraryFeature/Sources/LibraryRow.swift     [M] — show download indicator for non-local items
│   └── ReaderFeature/Sources/ReaderFeature.swift   [M] — ensureLocal + security scope before openArchive
└── Workspace.swift                                  [M] — add Data/CloudSyncKit
```

---

## Conventions (continued from Plan 2)

- Module helper from `Tuist/ProjectDescriptionHelpers/Module.swift` (with `hasTests:` parameter)
- Test pattern: `@MainActor @Suite struct`, `Bundle(for: BundleAnchor.self)` for resources
- Run module tests: `xcodebuild test -workspace Mana.xcworkspace -scheme <Module> CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)'`
- Run integration: `xcodebuild test -workspace Mana.xcworkspace -scheme Mana CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)'`
- After each task: `./Scripts/setup.sh` to regenerate the workspace if module structure changed

---

## Task 1: Add iCloud entitlements + CloudKit capability to App target

**Files:**
- Create: `App/Resources/Mana.entitlements`
- Modify: `App/Project.swift`

- [ ] **Step 1: Write `App/Resources/Mana.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.example.mana</string>
    </array>
    <key>com.apple.developer.ubiquity-container-identifiers</key>
    <array>
        <string>iCloud.com.example.mana</string>
    </array>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.example.mana</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 2: Modify `App/Project.swift`**

In the `Mana` target's `settings:`, add `entitlements:` reference and ensure the existing build settings are preserved. Use `.entitlements(.file(path:))`:

```swift
.target(
    name: "Mana",
    destinations: .iOS,
    product: .app,
    bundleId: "com.example.mana",
    deploymentTargets: .iOS("26.0"),
    infoPlist: .file(path: "Resources/Info.plist"),
    entitlements: .file(path: "Resources/Mana.entitlements"),
    sources: ["Sources/**"],
    resources: [.glob(pattern: "Resources/**", excluding: ["Resources/Info.plist", "Resources/Mana.entitlements"])],
    dependencies: [
        // ... existing list ...
        .project(target: "CloudSyncKit", path: "../Data/CloudSyncKit"),  // NEW
    ],
    settings: .settings(base: [
        "TARGETED_DEVICE_FAMILY": "1,2",
        "SUPPORTS_MACCATALYST": "NO",
        "DEVELOPMENT_TEAM": "$(MANA_DEV_TEAM)"   // can be unset for CODE_SIGNING_ALLOWED=NO builds
    ])
)
```

The `.entitlements` glob exclusion mirrors the Info.plist exclusion from Plan 1 Task 11.

- [ ] **Step 3: Generate and verify build still works without code signing**

```bash
./Scripts/setup.sh
xcodebuild build -workspace Mana.xcworkspace -scheme Mana CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED. Without code signing, the entitlements file is referenced but not enforced — runtime CloudKit/ubiquity calls will fail gracefully.

If the build fails because of the missing CloudSyncKit project, that's expected — just verify the failure mentions `Data/CloudSyncKit` and not entitlements. Task 2 creates it.

- [ ] **Step 4: Commit**

```bash
git add App/Resources/Mana.entitlements App/Project.swift
git commit -m "chore(app): add iCloud + CloudKit entitlements"
```

---

## Task 2: CloudSyncKit module + BookmarkURLResolver

**Files:**
- Create: `Data/CloudSyncKit/Project.swift`
- Create: `Data/CloudSyncKit/Sources/UbiquityContainer.swift`
- Create: `Data/CloudSyncKit/Sources/BookmarkURLResolver.swift`
- Create: `Data/CloudSyncKit/Tests/BookmarkURLResolverTests.swift`
- Modify: `Workspace.swift` — add `"Data/CloudSyncKit"` in alphabetical position

- [ ] **Step 1: Update `Workspace.swift`** to include `"Data/CloudSyncKit"`.

- [ ] **Step 2: Write `Data/CloudSyncKit/Project.swift`**

```swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "CloudSyncKit",
    kind: .data,
    dependencies: [.project(target: "Domain", path: "../../Domain")],
    hasTests: true
).project()
```

- [ ] **Step 3: Write `Data/CloudSyncKit/Sources/UbiquityContainer.swift`**

```swift
import Foundation

/// Resolves and gates access to the iCloud ubiquity container.
/// `containerURL` is `nil` when iCloud is unavailable (no signed-in account, missing entitlements,
/// or development build without code signing).
public struct UbiquityContainer: Sendable {
    public let identifier: String
    public let containerURL: URL?

    public init(identifier: String) {
        self.identifier = identifier
        self.containerURL = FileManager.default
            .url(forUbiquityContainerIdentifier: identifier)?
            .appending(path: "Documents")
    }

    public var isAvailable: Bool { containerURL != nil }
}
```

- [ ] **Step 4: Write failing tests `Data/CloudSyncKit/Tests/BookmarkURLResolverTests.swift`**

```swift
import Testing
import Foundation
@testable import CloudSyncKit

@Suite struct BookmarkURLResolverTests {

    @Test func encodesAndResolvesLocalFile() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "br-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appending(path: "test.txt")
        try Data("hello".utf8).write(to: file)

        let bookmark = try BookmarkURLResolver.bookmarkData(for: file)
        #expect(!bookmark.isEmpty)

        let (resolved, isStale) = try BookmarkURLResolver.resolve(bookmarkData: bookmark)
        #expect(isStale == false)
        #expect(resolved.standardizedFileURL == file.standardizedFileURL)

        try? FileManager.default.removeItem(at: dir)
    }

    @Test func resolvingGarbageThrows() {
        let garbage = Data([0x00, 0x01, 0x02])
        #expect(throws: (any Error).self) {
            _ = try BookmarkURLResolver.resolve(bookmarkData: garbage)
        }
    }
}
```

- [ ] **Step 5: Run tests to fail**

`./Scripts/setup.sh && xcodebuild test -workspace Mana.xcworkspace -scheme CloudSyncKit CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -20`
Expected: compile failure ("BookmarkURLResolver" not in scope).

- [ ] **Step 6: Write `Data/CloudSyncKit/Sources/BookmarkURLResolver.swift`**

```swift
import Foundation

public enum BookmarkURLResolver {

    /// Encodes a security-scoped bookmark for `url`. The caller must already have access
    /// (e.g., via Files-app picker that returned the URL).
    public static func bookmarkData(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// Resolves a previously stored bookmark. Returns the URL and whether the bookmark
    /// is stale (caller should refresh by calling `bookmarkData(for:)` and persisting).
    public static func resolve(bookmarkData: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return (url, isStale)
    }
}
```

- [ ] **Step 7: Run tests** — expect 2/2 PASS.

- [ ] **Step 8: Commit**

```bash
git add Data/CloudSyncKit/ Workspace.swift
git commit -m "feat(cloud-sync-kit): bookmark URL resolver + ubiquity container wrapper"
```

---

## Task 3: FileSyncServiceLive

This is the meat of Plan 3 — the implementation of `Domain.FileSyncService`.

**Files:**
- Create: `Data/CloudSyncKit/Sources/FileSyncServiceLive.swift`
- Create: `Data/CloudSyncKit/Tests/FileSyncServiceLiveTests.swift`

The protocol (from Plan 1):
```swift
public protocol FileSyncService: Sendable {
    var isAvailable: Bool { get async }
    func ingest(localURL: URL) async throws -> URL
    func ensureLocal(url: URL) async throws
    func observeChanges() -> AsyncStream<FileSyncEvent>
}
public enum FileSyncEvent: Sendable, Equatable {
    case added(URL), removed(URL), updated(URL)
}
public enum SyncError: Error, Equatable, Sendable {
    case iCloudUnavailable
    case quotaExceeded
    case downloadFailed(reason: String)
}
```

**Strategy:**
- `ingest(localURL:)` copies the source file into the ubiquity container's `Documents/` and returns the destination URL
- `ensureLocal(url:)` calls `FileManager.startDownloadingUbiquitousItem` and polls for `NSURLUbiquitousItemDownloadingStatusKey == .current`
- `observeChanges()` wraps `NSMetadataQuery` and emits add/remove/update events for `Documents/`

For tests, parameterize the service over a `containerURL: URL` so we can use a local temp dir as a fake ubiquity container.

- [ ] **Step 1: Write failing tests `Data/CloudSyncKit/Tests/FileSyncServiceLiveTests.swift`**

```swift
import Testing
import Foundation
@testable import CloudSyncKit
import Domain

@Suite struct FileSyncServiceLiveTests {

    private func makeFakeContainer() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "ubi-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func ingestCopiesFileIntoContainer() async throws {
        let container = try makeFakeContainer()
        let service = FileSyncServiceLive(containerURL: container, isAvailable: true)

        let source = FileManager.default.temporaryDirectory.appending(path: "src-\(UUID()).cbz")
        try Data("zip-bytes".utf8).write(to: source)

        let dest = try await service.ingest(localURL: source)

        #expect(dest.deletingLastPathComponent().standardizedFileURL == container.standardizedFileURL)
        #expect(dest.lastPathComponent == source.lastPathComponent)
        #expect(FileManager.default.fileExists(atPath: dest.path))

        try? FileManager.default.removeItem(at: container)
        try? FileManager.default.removeItem(at: source)
    }

    @Test func ingestRenamesOnConflict() async throws {
        let container = try makeFakeContainer()
        let service = FileSyncServiceLive(containerURL: container, isAvailable: true)

        // Pre-place a file with the same name
        let existing = container.appending(path: "book.cbz")
        try Data("v1".utf8).write(to: existing)

        let source = FileManager.default.temporaryDirectory.appending(path: "book.cbz")
        try Data("v2".utf8).write(to: source)

        let dest = try await service.ingest(localURL: source)

        #expect(dest.lastPathComponent != "book.cbz")  // renamed e.g. book 2.cbz
        #expect(dest.lastPathComponent.hasPrefix("book"))
        #expect(dest.lastPathComponent.hasSuffix(".cbz"))

        try? FileManager.default.removeItem(at: container)
        try? FileManager.default.removeItem(at: source)
    }

    @Test func unavailableServiceThrowsOnIngest() async throws {
        let service = FileSyncServiceLive(containerURL: nil, isAvailable: false)
        let source = FileManager.default.temporaryDirectory.appending(path: "x.cbz")
        try? Data("x".utf8).write(to: source)
        await #expect(throws: SyncError.iCloudUnavailable) {
            _ = try await service.ingest(localURL: source)
        }
        try? FileManager.default.removeItem(at: source)
    }

    @Test func ensureLocalNoOpsForLocalFile() async throws {
        let container = try makeFakeContainer()
        let service = FileSyncServiceLive(containerURL: container, isAvailable: true)

        let file = container.appending(path: "local.cbz")
        try Data("ok".utf8).write(to: file)

        // Should not throw on a file that is already local
        try await service.ensureLocal(url: file)
        #expect(FileManager.default.fileExists(atPath: file.path))

        try? FileManager.default.removeItem(at: container)
    }
}
```

- [ ] **Step 2: Write `Data/CloudSyncKit/Sources/FileSyncServiceLive.swift`**

```swift
import Foundation
import Domain

public actor FileSyncServiceLive: FileSyncService {

    private let containerURL: URL?
    private let _isAvailable: Bool
    private var continuations: [UUID: AsyncStream<FileSyncEvent>.Continuation] = [:]
    private var metadataQuery: NSMetadataQuery?

    public init(containerURL: URL?, isAvailable: Bool) {
        self.containerURL = containerURL
        self._isAvailable = isAvailable && containerURL != nil
    }

    public var isAvailable: Bool { _isAvailable }

    public func ingest(localURL: URL) async throws -> URL {
        guard _isAvailable, let container = containerURL else {
            throw SyncError.iCloudUnavailable
        }
        let fm = FileManager.default
        let target = uniqueDestination(for: localURL.lastPathComponent, in: container)
        do {
            try fm.copyItem(at: localURL, to: target)
            return target
        } catch {
            throw SyncError.downloadFailed(reason: error.localizedDescription)
        }
    }

    public func ensureLocal(url: URL) async throws {
        guard _isAvailable else { throw SyncError.iCloudUnavailable }
        let fm = FileManager.default
        // If file already exists on local disk, no-op.
        if fm.fileExists(atPath: url.path) {
            return
        }
        do {
            try fm.startDownloadingUbiquitousItem(at: url)
        } catch {
            throw SyncError.downloadFailed(reason: error.localizedDescription)
        }
        // Poll for download status (max ~30 seconds)
        for _ in 0..<60 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            let resourceValues = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if resourceValues?.ubiquitousItemDownloadingStatus == .current { return }
            if fm.fileExists(atPath: url.path) { return }
        }
        throw SyncError.downloadFailed(reason: "timeout")
    }

    public nonisolated func observeChanges() -> AsyncStream<FileSyncEvent> {
        AsyncStream { continuation in
            Task { await self.startObservation(continuation: continuation) }
        }
    }

    private func startObservation(continuation: AsyncStream<FileSyncEvent>.Continuation) {
        let id = UUID()
        continuations[id] = continuation
        if metadataQuery == nil, _isAvailable {
            startMetadataQuery()
        }
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id: id) }
        }
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
        if continuations.isEmpty {
            stopMetadataQuery()
        }
    }

    private func startMetadataQuery() {
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "*")

        let center = NotificationCenter.default
        center.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: .main) { [weak self] note in
            Task { await self?.handleQueryUpdate(note) }
        }
        center.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main) { [weak self] note in
            Task { await self?.handleQueryUpdate(note) }
        }
        query.start()
        metadataQuery = query
    }

    private func stopMetadataQuery() {
        metadataQuery?.stop()
        metadataQuery = nil
        NotificationCenter.default.removeObserver(self)
    }

    private func handleQueryUpdate(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }
        query.disableUpdates()
        defer { query.enableUpdates() }

        let added = (notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem]) ?? []
        let removed = (notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem]) ?? []
        let changed = (notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem]) ?? []

        for item in added {
            if let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                emit(.added(url))
            }
        }
        for item in removed {
            if let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                emit(.removed(url))
            }
        }
        for item in changed {
            if let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                emit(.updated(url))
            }
        }
    }

    private func emit(_ event: FileSyncEvent) {
        for (_, continuation) in continuations {
            continuation.yield(event)
        }
    }

    private func uniqueDestination(for filename: String, in container: URL) -> URL {
        let fm = FileManager.default
        var candidate = container.appending(path: filename)
        var counter = 2
        while fm.fileExists(atPath: candidate.path) {
            let stem = (filename as NSString).deletingPathExtension
            let ext = (filename as NSString).pathExtension
            let newName = ext.isEmpty ? "\(stem) \(counter)" : "\(stem) \(counter).\(ext)"
            candidate = container.appending(path: newName)
            counter += 1
        }
        return candidate
    }
}
```

- [ ] **Step 3: Run tests** — expect 4/4 PASS.

- [ ] **Step 4: Commit**

```bash
git add Data/CloudSyncKit/Sources/FileSyncServiceLive.swift Data/CloudSyncKit/Tests/FileSyncServiceLiveTests.swift
git commit -m "feat(cloud-sync-kit): FileSyncServiceLive (NSFileCoordinator + NSMetadataQuery)"
```

---

## Task 4: Add `urlBookmarkData` to ComicItem + ComicEntity

Plan 2 review issue I4: store URL as security-scoped bookmark instead of (only) absoluteString.

**Files:**
- Modify: `Domain/Sources/Models/ComicItem.swift`
- Modify: `Data/PersistenceKit/Sources/SwiftDataModels.swift`
- Modify: `Data/PersistenceKit/Sources/ComicRepositoryLive.swift`
- Modify: `Data/PersistenceKit/Tests/ComicRepositoryLiveTests.swift`

- [ ] **Step 1: Add field to `ComicItem`**

In `Domain/Sources/Models/ComicItem.swift`, add a new optional field. Append it to the init AFTER `readingMode` (the last existing parameter) so older callers stay compatible:

```swift
public struct ComicItem: Identifiable, Equatable, Sendable, Hashable {
    public let id: UUID
    public let url: URL
    public let format: ComicFormat
    public let title: String
    public let pageCount: Int?
    public let coverThumbnail: Data?
    public let dateAdded: Date
    public let fileSizeBytes: Int64
    public let readingMode: ReadingMode?
    public let urlBookmarkData: Data?    // NEW

    public init(
        id: UUID,
        url: URL,
        format: ComicFormat,
        title: String,
        pageCount: Int?,
        coverThumbnail: Data?,
        dateAdded: Date,
        fileSizeBytes: Int64,
        readingMode: ReadingMode? = nil,
        urlBookmarkData: Data? = nil
    ) {
        self.id = id
        self.url = url
        self.format = format
        self.title = title
        self.pageCount = pageCount
        self.coverThumbnail = coverThumbnail
        self.dateAdded = dateAdded
        self.fileSizeBytes = fileSizeBytes
        self.readingMode = readingMode
        self.urlBookmarkData = urlBookmarkData
    }
}
```

- [ ] **Step 2: Add field to `ComicEntity`**

In `Data/PersistenceKit/Sources/SwiftDataModels.swift`, add `public var urlBookmarkData: Data?` to `ComicEntity`. Update the init's parameters and the `toModel()`/`from(_:)` conversions to round-trip it.

- [ ] **Step 3: Update `ComicRepositoryLive.upsert(_:)`**

In the existing-entity update path, also assign `existing.urlBookmarkData = item.urlBookmarkData`.

- [ ] **Step 4: Add test**

In `Data/PersistenceKit/Tests/ComicRepositoryLiveTests.swift`, add:

```swift
@Test func roundTripsBookmarkData() async throws {
    let stack = try makeStack()
    let repo = ComicRepositoryLive(stack: stack)
    let id = UUID()
    let bookmark = Data([0x42, 0x43, 0x44])
    let item = ComicItem(
        id: id,
        url: URL(fileURLWithPath: "/tmp/q.cbz"),
        format: .cbz,
        title: "Q",
        pageCount: 5,
        coverThumbnail: nil,
        dateAdded: .init(timeIntervalSince1970: 0),
        fileSizeBytes: 1,
        readingMode: nil,
        urlBookmarkData: bookmark
    )
    try await repo.upsert(item)
    let loaded = await repo.all()
    #expect(loaded.first?.urlBookmarkData == bookmark)
}
```

- [ ] **Step 5: Run tests**

`xcodebuild test -workspace Mana.xcworkspace -scheme PersistenceKit CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10`
Expected: 6/6 PASS (5 existing + 1 new).

- [ ] **Step 6: Commit**

```bash
git add Domain/ Data/PersistenceKit/
git commit -m "feat: persist URL as security-scoped bookmark data"
```

---

## Task 5: SwiftDataStack.cloudKit factory + DependenciesLive picks at boot

**Files:**
- Modify: `Data/PersistenceKit/Sources/SwiftDataStack.swift`
- Modify: `App/Sources/DependenciesLive.swift`

- [ ] **Step 1: Add CloudKit factory**

```swift
public static func cloudKit(containerIdentifier: String) throws -> SwiftDataStack {
    let config = ModelConfiguration(
        cloudKitDatabase: .private(containerIdentifier)
    )
    let container = try ModelContainer(
        for: ComicEntity.self, ReadingProgressEntity.self, BookmarkEntity.self,
        configurations: config
    )
    return SwiftDataStack(container: container)
}
```

Keep `inMemory()` and `onDisk(url:)` factories as-is.

- [ ] **Step 2: Update `App/Sources/DependenciesLive.swift`**

```swift
import Foundation
import ComposableArchitecture
import Domain
import ArchiveKit
import PersistenceKit
import ImageCacheKit
import ThumbnailKit
import CloudSyncKit
import LibraryFeature
import ReaderFeature
import BookmarksFeature
import SettingsFeature

enum LiveDependencies {
    static let containerIdentifier = "iCloud.com.example.mana"

    static func register() {
        let ubi = UbiquityContainer(identifier: containerIdentifier)

        // Pick the SwiftData stack: CloudKit if available, on-disk otherwise.
        let stack: SwiftDataStack
        if ubi.isAvailable, let cloudStack = try? SwiftDataStack.cloudKit(containerIdentifier: containerIdentifier) {
            stack = cloudStack
        } else {
            stack = try! SwiftDataStack.onDisk(
                url: URL.applicationSupportDirectory.appending(path: "mana.store")
            )
        }

        let comicRepo = ComicRepositoryLive(stack: stack)
        let progressRepo = ProgressRepositoryLive(stack: stack)
        let bookmarkRepo = BookmarkRepositoryLive(stack: stack)
        let router = DefaultArchiveReaderRouter()
        let cache = ImageCache(
            diskDirectory: URL.cachesDirectory.appending(path: "mana-pages"),
            diskCapacityBytes: 200_000_000
        )
        let thumbnails = ThumbnailProviderLive(
            cacheDir: URL.cachesDirectory.appending(path: "mana-thumbs")
        )
        let fileSync = FileSyncServiceLive(
            containerURL: ubi.containerURL,
            isAvailable: ubi.isAvailable
        )
        let importer = LibraryImporterLive(
            repo: comicRepo,
            router: router,
            cache: cache,
            thumbnails: thumbnails,
            fileSync: fileSync
        )

        prepareDependencies {
            $0.archiveReaderRouter = router
            $0.progressRepository = progressRepo
            $0.imageCache = cache
            $0.comicRepository = comicRepo
            $0.libraryImporter = importer
            $0.bookmarkRepository = bookmarkRepo
            $0.userDefaults = LiveUserDefaultsClient()
            $0.fileSyncService = fileSync
        }
    }
}
```

This requires:
- A `\.fileSyncService` dependency key — add in CloudSyncKit:

```swift
// In FileSyncServiceLive.swift, append:
import ComposableArchitecture

private enum FileSyncServiceKey: DependencyKey {
    static let liveValue: any FileSyncService = NoopFileSyncService()
}

private struct NoopFileSyncService: FileSyncService {
    var isAvailable: Bool { get async { false } }
    func ingest(localURL: URL) async throws -> URL {
        throw SyncError.iCloudUnavailable
    }
    func ensureLocal(url: URL) async throws {
        throw SyncError.iCloudUnavailable
    }
    func observeChanges() -> AsyncStream<FileSyncEvent> {
        AsyncStream { _ in }
    }
}

extension DependencyValues {
    public var fileSyncService: any FileSyncService {
        get { self[FileSyncServiceKey.self] }
        set { self[FileSyncServiceKey.self] = newValue }
    }
}
```

CloudSyncKit needs to depend on `ComposableArchitecture` for this — update its `Project.swift`:

```swift
let project = Module(
    name: "CloudSyncKit",
    kind: .data,
    dependencies: [.project(target: "Domain", path: "../../Domain")],
    externalDependencies: ["ComposableArchitecture"],   // NEW
    hasTests: true
).project()
```

- [ ] **Step 3: Build**

```bash
./Scripts/setup.sh
xcodebuild build -workspace Mana.xcworkspace -scheme Mana CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED. (LibraryImporterLive will need updating in Task 6 to accept `fileSync:` — until then build will fail. Skip ahead and do Task 6 first if needed.)

- [ ] **Step 4: Commit**

```bash
git add Data/PersistenceKit/Sources/SwiftDataStack.swift Data/CloudSyncKit/ App/Sources/DependenciesLive.swift
git commit -m "feat: SwiftDataStack.cloudKit + fileSyncService dependency wiring"
```

---

## Task 6: LibraryImporterLive uses FileSyncService

**Files:**
- Modify: `App/Sources/LibraryImporterLive.swift`
- Modify: `App/Tests/IntegrationFlowTests.swift`

- [ ] **Step 1: Update LibraryImporterLive signature and behavior**

```swift
import Foundation
import Domain
import ArchiveKit
import ImageCacheKit
import ThumbnailKit
import CloudSyncKit
import LibraryFeature

public struct LibraryImporterLive: LibraryImporter {
    let repo: any ComicRepository
    let router: any ArchiveReaderRouter
    let cache: ImageCache
    let thumbnails: ThumbnailProviderLive
    let fileSync: any FileSyncService

    public init(
        repo: any ComicRepository,
        router: any ArchiveReaderRouter,
        cache: ImageCache,
        thumbnails: ThumbnailProviderLive,
        fileSync: any FileSyncService
    ) {
        self.repo = repo
        self.router = router
        self.cache = cache
        self.thumbnails = thumbnails
        self.fileSync = fileSync
    }

    public func importFiles(_ urls: [URL]) async throws -> [ComicItem] {
        var results: [ComicItem] = []
        for url in urls {
            let needsStop = url.startAccessingSecurityScopedResource()
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }

            guard let format = ComicFormat(fileExtension: url.pathExtension) else {
                throw ArchiveError.unsupportedFormat(url.pathExtension)
            }

            // If iCloud is available, copy file into ubiquity container.
            // Otherwise keep the picked URL and store its bookmark for re-resolution.
            let canonicalURL: URL
            let bookmark: Data?
            if await fileSync.isAvailable {
                canonicalURL = try await fileSync.ingest(localURL: url)
                bookmark = nil  // ubiquity URL is reachable directly via container
            } else {
                canonicalURL = url
                bookmark = try? BookmarkURLResolver.bookmarkData(for: url)
            }

            let reader = router.reader(for: format)
            let handle = try await reader.openArchive(at: canonicalURL)
            let pageCount = await reader.pageCount(handle)
            let id = UUID()

            var thumb: Data?
            if pageCount > 0, let raw = try? await reader.pageData(handle, index: 0) {
                thumb = try? await thumbnails.storeThumbnail(comicId: id, page: 0, rawPageBytes: raw, maxDim: 256)
            }
            await reader.closeArchive(handle)

            let title = canonicalURL.deletingPathExtension().lastPathComponent
            let size = (try? FileManager.default.attributesOfItem(atPath: canonicalURL.path)[.size] as? NSNumber)?.int64Value ?? 0

            let item = ComicItem(
                id: id,
                url: canonicalURL,
                format: format,
                title: title,
                pageCount: pageCount,
                coverThumbnail: thumb,
                dateAdded: Date(),
                fileSizeBytes: size,
                readingMode: nil,
                urlBookmarkData: bookmark
            )
            try await repo.upsert(item)
            results.append(item)
        }
        return results
    }
}
```

- [ ] **Step 2: Update integration test**

In `App/Tests/IntegrationFlowTests.swift`, the importer constructor now takes `fileSync:`. Use a no-op `MockFileSyncService` that reports unavailable (so the test stays in the "local URL" path):

```swift
import Domain
// ... existing imports plus:

private struct UnavailableFileSync: FileSyncService {
    var isAvailable: Bool { get async { false } }
    func ingest(localURL: URL) async throws -> URL { throw SyncError.iCloudUnavailable }
    func ensureLocal(url: URL) async throws { throw SyncError.iCloudUnavailable }
    func observeChanges() -> AsyncStream<FileSyncEvent> { AsyncStream { _ in } }
}
```

In the test:
```swift
let importer = LibraryImporterLive(
    repo: comicRepo, router: router, cache: cache, thumbnails: thumbnails,
    fileSync: UnavailableFileSync()
)
```

The test should still pass: `urlBookmarkData` will be set (non-nil) when fileSync is unavailable, since we encode a bookmark for the picked URL. Add an assertion:
```swift
#expect(comic.urlBookmarkData != nil)
```

- [ ] **Step 3: Build + test**

```bash
./Scripts/setup.sh
xcodebuild test -workspace Mana.xcworkspace -scheme Mana CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -15
```
Expected: integration test PASS.

- [ ] **Step 4: Commit**

```bash
git add App/
git commit -m "feat(app): LibraryImporterLive routes through FileSyncService"
```

---

## Task 7: ReaderFeature ensures local + security scope

**Files:**
- Modify: `Features/ReaderFeature/Sources/ReaderFeature.swift`
- Modify: `Features/ReaderFeature/Project.swift` — add CloudSyncKit dep

- [ ] **Step 1: Add CloudSyncKit to ReaderFeature deps**

```swift
let project = Module(
    name: "ReaderFeature",
    kind: .feature,
    dependencies: [
        .project(target: "Domain", path: "../../Domain"),
        .project(target: "ImageCacheKit", path: "../../Data/ImageCacheKit"),
        .project(target: "DesignSystem", path: "../../DesignSystem"),
        .project(target: "SharedUI", path: "../../SharedUI"),
        .project(target: "LibraryFeature", path: "../LibraryFeature"),
        .project(target: "SettingsFeature", path: "../SettingsFeature"),
        .project(target: "CloudSyncKit", path: "../../Data/CloudSyncKit")   // NEW
    ],
    externalDependencies: ["ComposableArchitecture"],
    hasTests: true
).project()
```

- [ ] **Step 2: Add fileSync dependency to ReaderFeature**

In `ReaderFeature.swift`, add:
```swift
import CloudSyncKit
// ...
@Dependency(\.fileSyncService) var fileSync
```

In `.task` case, before opening the archive, ensure-local + resolve bookmark:

```swift
case .task:
    let comic = state.comic
    return .run { send in
        do {
            // Resolve the file URL: prefer the URL stored on ComicItem, but if a
            // bookmark exists and the direct URL is unreachable, resolve via bookmark.
            var url = comic.url
            var didStartScope = false

            if !FileManager.default.fileExists(atPath: url.path),
               let bookmark = comic.urlBookmarkData {
                let (resolved, _) = try BookmarkURLResolver.resolve(bookmarkData: bookmark)
                url = resolved
            }

            // If the URL is in the ubiquity container, ensure it's downloaded.
            if await fileSync.isAvailable {
                try? await fileSync.ensureLocal(url: url)
            }

            didStartScope = url.startAccessingSecurityScopedResource()

            let reader = router.reader(for: comic.format)
            let handle = try await reader.openArchive(at: url)
            let pageCount = await reader.pageCount(handle)
            let saved = await progress.load(comicId: comic.id)
            let lastPage = saved.map { min(max(0, $0.lastPageIndex), max(0, pageCount - 1)) } ?? 0
            await send(.opened(handle: handle, pageCount: pageCount, lastPage: lastPage))
            await send(.prefetchHint(lastPage))

            // Note: not stopping the security scope here — reader holds the file open.
            // Plan 4 polish: stop scope on .onDisappear.
            _ = didStartScope
        } catch {
            await send(.openFailed(error.localizedDescription))
        }
    }
```

- [ ] **Step 3: Update tests if needed**

Existing `ReaderFeatureTests` use `StubReader` and pass file URLs to a fixture. Should still pass. But may need to inject a `fileSyncService` dependency:

```swift
withDependencies: {
    // ... existing ...
    $0.fileSyncService = UnavailableFileSync()
}
```

Define `UnavailableFileSync` near the test fixtures.

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -workspace Mana.xcworkspace -scheme ReaderFeature CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -15
```
Expected: 3/3 PASS.

- [ ] **Step 5: Commit**

```bash
git add Features/ReaderFeature/
git commit -m "feat(reader-feature): ensure local + bookmark resolution on archive open"
```

---

## Task 8: LibraryFeature observes FileSyncService changes

When iCloud delivers new files (added on another device), the library should refresh.

**Files:**
- Modify: `Features/LibraryFeature/Sources/LibraryFeature.swift`
- Modify: `Features/LibraryFeature/Project.swift` — add CloudSyncKit dep

- [ ] **Step 1: Add CloudSyncKit to LibraryFeature deps**

- [ ] **Step 2: Subscribe to file sync events**

In `LibraryFeature.swift`:
```swift
import CloudSyncKit
// ...
@Dependency(\.fileSyncService) var fileSync
```

Add a new action:
```swift
case fileSyncEvent(FileSyncEvent)
```

In `.task` case, ALSO subscribe:
```swift
case .task:
    return .merge(
        .run { send in
            let items = await repo.all()
            await send(.refreshed(items))
        },
        .run { send in
            for await event in fileSync.observeChanges() {
                await send(.fileSyncEvent(event))
            }
        }
    )
```

Handle the event:
```swift
case let .fileSyncEvent(event):
    switch event {
    case .added, .removed, .updated:
        // Naive refresh — Plan 4 polish would diff incrementally.
        return .run { send in
            let items = await repo.all()
            await send(.refreshed(items))
        }
    }
```

- [ ] **Step 3: Tests**

Add a stub `FileSyncService` in tests that emits a single `.added` event. Verify the reducer triggers a refresh.

- [ ] **Step 4: Commit**

```bash
git add Features/LibraryFeature/
git commit -m "feat(library-feature): refresh on FileSyncService events"
```

---

## Task 9: Library row shows "downloading from iCloud" indicator

**Files:**
- Modify: `Features/LibraryFeature/Sources/LibraryRow.swift`
- Modify: `Domain/Sources/Models/ComicItem.swift` — add a derived `isLocalFileAvailable: Bool` (computed at view time, not a stored field)

Actually keep `ComicItem` immutable; check at view time:

- [ ] **Step 1: Modify `LibraryRow.swift`**

```swift
import SwiftUI
import Domain
import DesignSystem

public struct LibraryRow: View {
    let comic: ComicItem

    public init(comic: ComicItem) {
        self.comic = comic
    }

    public var body: some View {
        HStack(spacing: Tokens.Spacing.m) {
            cover
                .frame(width: 60, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card))
            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                Text(comic.title).font(.headline)
                HStack(spacing: 4) {
                    Text(comic.format.rawValue.uppercased())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !isLocallyAvailable {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, Tokens.Spacing.s)
    }

    private var isLocallyAvailable: Bool {
        FileManager.default.fileExists(atPath: comic.url.path)
    }

    @ViewBuilder
    private var cover: some View {
        if let data = comic.coverThumbnail, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: Tokens.Radius.card)
                .fill(Color.gray.opacity(0.3))
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -workspace Mana.xcworkspace -scheme LibraryFeature CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Features/LibraryFeature/
git commit -m "feat(library-feature): cloud-download indicator on library rows"
```

---

## Plan 3 Completion Checklist

- [ ] All module unit tests pass (CloudSyncKit 6/6, PersistenceKit 6/6, others unchanged)
- [ ] Integration test passes
- [ ] App builds for iPad simulator with CODE_SIGNING_ALLOWED=NO
- [ ] App still launches on simulator (in fallback local-only mode since no iCloud signing)
- [ ] No regressions in Plan 1/2 features

## Real-iCloud Verification (post-Plan 3, separate effort)

When the user has an Apple Developer account configured:

1. Set `MANA_DEV_TEAM` env var to their team ID
2. Build with `CODE_SIGNING_ALLOWED=YES` and a real bundle identifier they own
3. Sign into iCloud on the simulator/device
4. Import a comic — verify it appears in `~/Library/Mobile Documents/iCloud~com~example~mana/Documents/`
5. Sign into the same Apple ID on a second device — verify the comic appears with cloud-download indicator, then loads after tapping

These steps are NOT part of Plan 3 task list — they require user action and credentials.

## What's Next (Plan 4)

- Liquid Glass design polish (correct iOS 26 API usage: `Glass`, `GlassButtonStyle`, `glassEffect()` if it exists in this SDK)
- Library sort/filter UI
- Dark mode polish
- Sheet for "Add bookmark with note"
- ReaderFeature: stop security scope on disappear
- Sort/filter, slideshow, image filters (contrast/invert) if time

# Mana — Plan 1: Foundation + Minimal End-to-End

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the Tuist workspace, the Domain layer, a working ZIP/CBZ archive reader, and the smallest possible Library + Reader (single-page) flow — so a user can import a `.cbz` from Files and turn pages.

**Architecture:** Modular Tuist workspace. Pure-Swift Domain (models + protocols) with zero external deps. ArchiveKit implements `ArchiveReader` for ZIP/CBZ via ZIPFoundation. LibraryFeature and ReaderFeature use TCA `@Reducer`. ImageCache provides byte-cache between data and view. Liquid Glass styling minimal in Plan 1 (just enough to compile and look right).

**Tech Stack:** Tuist 4.x, Swift 6.0, iOS 26 SDK, TCA 1.x, ZIPFoundation, SwiftData (local store only — CloudKit comes in Plan 3), `@Observable`, async/await, XCTest, swift-testing.

---

## File Structure (created across this plan)

```
Mana/
├── Tuist.swift
├── Workspace.swift
├── Tuist/
│   ├── Package.swift
│   └── ProjectDescriptionHelpers/
│       └── Module.swift
├── Domain/
│   ├── Project.swift
│   ├── Sources/
│   │   ├── Models/{ComicItem,ComicFormat,ReadingProgress,Bookmark,ReadingMode,ScrollDirection}.swift
│   │   └── Repositories/{ArchiveReader,ArchiveReaderRouter,ComicRepository,ProgressRepository,BookmarkRepository,FileSyncService,ThumbnailProvider}.swift
│   └── Tests/{ComicItemTests,ReadingProgressTests}.swift
├── Data/
│   ├── ArchiveKit/
│   │   ├── Project.swift
│   │   ├── Sources/{ArchiveHandle,ZipArchiveReader,DefaultArchiveReaderRouter}.swift
│   │   └── Tests/{ZipArchiveReaderTests}.swift + Resources/sample.cbz
│   ├── PersistenceKit/
│   │   ├── Project.swift
│   │   ├── Sources/{SwiftDataStack,ComicRepositoryLive,ProgressRepositoryLive,BookmarkRepositoryLive,SwiftDataModels}.swift
│   │   └── Tests/{ComicRepositoryLiveTests,ProgressRepositoryLiveTests}.swift
│   └── ImageCacheKit/
│       ├── Project.swift
│       ├── Sources/{ImageCache,DiskLRUCache,PageKey}.swift
│       └── Tests/{ImageCacheTests}.swift
├── DesignSystem/
│   ├── Project.swift
│   └── Sources/{Tokens,GlassToolbar}.swift  (placeholders, expanded in Plan 4)
├── SharedUI/
│   ├── Project.swift
│   └── Sources/{ZoomableImageView}.swift
├── Features/
│   ├── LibraryFeature/
│   │   ├── Project.swift
│   │   ├── Sources/{LibraryFeature,LibraryView,LibraryRow}.swift
│   │   └── Tests/{LibraryFeatureTests}.swift
│   ├── ReaderFeature/
│   │   ├── Project.swift
│   │   ├── Sources/{ReaderFeature,ReaderView,SinglePageRenderer,PageRenderer}.swift
│   │   └── Tests/{ReaderFeatureTests}.swift
│   └── AppFeature/
│       ├── Project.swift
│       └── Sources/{AppFeature,AppView}.swift
└── App/
    ├── Project.swift
    ├── Sources/{ManaApp,DependenciesLive}.swift
    └── Resources/{Info.plist,Assets.xcassets,LaunchScreen.storyboard}
```

Each module has Tests/ where listed. `App/` does not have unit tests; integration is via XCUITest later.

---

## Conventions

- **Bundle ID prefix:** `com.example.mana` (placeholder; user can change in `Tuist/Package.swift` env later)
- **Swift Package deps** declared centrally in `Tuist/Package.swift`
- **Indentation:** 4 spaces
- **Tests:** `swift-testing` (`@Test`) for new files; `XCTest` allowed for legacy interop where helpful
- **Commit message style:** `feat(<module>): ...`, `test(<module>): ...`, `chore(tuist): ...`
- **Run tests for module X:** `tuist test <ModuleName>` (after `tuist generate`)

---

## Task 1: Tuist workspace skeleton

**Files:**
- Create: `Tuist.swift`
- Create: `Workspace.swift`
- Create: `Tuist/Package.swift`
- Create: `Tuist/ProjectDescriptionHelpers/Module.swift`
- Create: `.gitignore`
- Create: `mise.toml`

- [ ] **Step 1: Initialize git repo**

```bash
cd /Users/doyoung_kim/Documents/Git/mana
git init -b main
```

- [ ] **Step 2: Write `.gitignore`**

```
.DS_Store
*.xcodeproj
*.xcworkspace
DerivedData/
.build/
Tuist/.build/
Tuist/Dependencies/
Derived/
.tuist-bin/
.tuist-version
xcuserdata/
*.swp
```

- [ ] **Step 3: Write `mise.toml` (pins Tuist + Swift)**

```toml
[tools]
tuist = "4.40.0"
```

- [ ] **Step 4: Write `Tuist.swift`**

```swift
import ProjectDescription

let tuist = Tuist(
    project: .tuist(
        compatibleXcodeVersions: ["26.0"],
        swiftVersion: "6.0"
    )
)
```

- [ ] **Step 5: Write `Workspace.swift`**

```swift
import ProjectDescription

let workspace = Workspace(
    name: "Mana",
    projects: [
        "App",
        "Features/AppFeature",
        "Features/LibraryFeature",
        "Features/ReaderFeature",
        "Domain",
        "Data/ArchiveKit",
        "Data/PersistenceKit",
        "Data/ImageCacheKit",
        "DesignSystem",
        "SharedUI"
    ]
)
```

- [ ] **Step 6: Write `Tuist/Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import struct ProjectDescription.PackageSettings
let packageSettings = PackageSettings(
    productTypes: [
        "ComposableArchitecture": .framework,
        "ZIPFoundation": .framework
    ]
)
#endif

let package = Package(
    name: "ManaDeps",
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.15.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.19")
    ]
)
```

- [ ] **Step 7: Write `Tuist/ProjectDescriptionHelpers/Module.swift`**

```swift
import ProjectDescription

public enum ModuleKind { case feature, domain, data, designSystem, sharedUI, app }

public struct Module {
    public let name: String
    public let kind: ModuleKind
    public let dependencies: [TargetDependency]
    public let externalDependencies: [String]
    public let hasResources: Bool

    public init(
        name: String,
        kind: ModuleKind,
        dependencies: [TargetDependency] = [],
        externalDependencies: [String] = [],
        hasResources: Bool = false
    ) {
        self.name = name
        self.kind = kind
        self.dependencies = dependencies
        self.externalDependencies = externalDependencies
        self.hasResources = hasResources
    }

    public func project() -> Project {
        let bundleId = "com.example.mana.\(name.lowercased())"
        let externalDeps: [TargetDependency] = externalDependencies.map { .external(name: $0) }
        let deploymentTargets: DeploymentTargets = .iOS("26.0")

        let frameworkTarget = Target.target(
            name: name,
            destinations: .iOS,
            product: .framework,
            bundleId: bundleId,
            deploymentTargets: deploymentTargets,
            sources: ["Sources/**"],
            resources: hasResources ? ["Resources/**"] : nil,
            dependencies: dependencies + externalDeps
        )

        let testTarget = Target.target(
            name: "\(name)Tests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "\(bundleId).tests",
            deploymentTargets: deploymentTargets,
            sources: ["Tests/**"],
            resources: ["Tests/Resources/**"],
            dependencies: [.target(name: name)]
        )

        return Project(
            name: name,
            targets: [frameworkTarget, testTarget]
        )
    }
}
```

- [ ] **Step 8: Verify tuist installs and validates**

Run: `mise install && tuist install && tuist generate --no-open`
Expected: workspace generation fails because module `Project.swift` files don't exist yet — that's fine for now. Confirm the failure is "missing manifest" not "tuist not found".

- [ ] **Step 9: Commit**

```bash
git add Tuist.swift Workspace.swift Tuist/ .gitignore mise.toml
git commit -m "chore(tuist): initialize workspace skeleton"
```

---

## Task 2: Domain models + repositories (no external deps)

**Files:**
- Create: `Domain/Project.swift`
- Create: `Domain/Sources/Models/ComicFormat.swift`
- Create: `Domain/Sources/Models/ComicItem.swift`
- Create: `Domain/Sources/Models/ReadingProgress.swift`
- Create: `Domain/Sources/Models/Bookmark.swift`
- Create: `Domain/Sources/Models/ReadingMode.swift`
- Create: `Domain/Sources/Repositories/ArchiveReader.swift`
- Create: `Domain/Sources/Repositories/ArchiveReaderRouter.swift`
- Create: `Domain/Sources/Repositories/ComicRepository.swift`
- Create: `Domain/Sources/Repositories/ProgressRepository.swift`
- Create: `Domain/Sources/Repositories/BookmarkRepository.swift`
- Create: `Domain/Sources/Repositories/FileSyncService.swift`
- Create: `Domain/Sources/Repositories/ThumbnailProvider.swift`
- Test: `Domain/Tests/ComicItemTests.swift`
- Test: `Domain/Tests/ReadingProgressTests.swift`

- [ ] **Step 1: Write `Domain/Project.swift`**

```swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(name: "Domain", kind: .domain).project()
```

- [ ] **Step 2: Write failing tests `Domain/Tests/ComicItemTests.swift`**

```swift
import Testing
import Foundation
@testable import Domain

@Test func comicItemEquatableByValue() {
    let id = UUID()
    let url = URL(fileURLWithPath: "/tmp/x.cbz")
    let a = ComicItem(id: id, url: url, format: .cbz, title: "X", pageCount: 12, coverThumbnail: nil, dateAdded: Date(timeIntervalSince1970: 0), fileSizeBytes: 100)
    let b = ComicItem(id: id, url: url, format: .cbz, title: "X", pageCount: 12, coverThumbnail: nil, dateAdded: Date(timeIntervalSince1970: 0), fileSizeBytes: 100)
    #expect(a == b)
}

@Test func comicFormatRawValueIsLowercaseExtension() {
    #expect(ComicFormat.cbz.rawValue == "cbz")
    #expect(ComicFormat.pdf.rawValue == "pdf")
}
```

- [ ] **Step 3: Write failing tests `Domain/Tests/ReadingProgressTests.swift`**

```swift
import Testing
import Foundation
@testable import Domain

@Test func readingProgressEquatable() {
    let id = UUID()
    let date = Date(timeIntervalSince1970: 1)
    let a = ReadingProgress(comicId: id, lastPageIndex: 5, totalPages: 10, updatedAt: date)
    let b = ReadingProgress(comicId: id, lastPageIndex: 5, totalPages: 10, updatedAt: date)
    #expect(a == b)
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `tuist generate --no-open && tuist test Domain`
Expected: compile failure ("cannot find ComicItem in scope" etc.) — confirms test file at least is wired in.

- [ ] **Step 5: Write `Domain/Sources/Models/ComicFormat.swift`**

```swift
import Foundation

public enum ComicFormat: String, Sendable, Equatable, CaseIterable {
    case zip, cbz, rar, cbr, pdf, folder

    public init?(fileExtension: String) {
        self.init(rawValue: fileExtension.lowercased())
    }
}
```

- [ ] **Step 6: Write `Domain/Sources/Models/ComicItem.swift`**

```swift
import Foundation

public struct ComicItem: Identifiable, Equatable, Sendable, Hashable {
    public let id: UUID
    public let url: URL
    public let format: ComicFormat
    public let title: String
    public let pageCount: Int?
    public let coverThumbnail: Data?
    public let dateAdded: Date
    public let fileSizeBytes: Int64

    public init(
        id: UUID,
        url: URL,
        format: ComicFormat,
        title: String,
        pageCount: Int?,
        coverThumbnail: Data?,
        dateAdded: Date,
        fileSizeBytes: Int64
    ) {
        self.id = id
        self.url = url
        self.format = format
        self.title = title
        self.pageCount = pageCount
        self.coverThumbnail = coverThumbnail
        self.dateAdded = dateAdded
        self.fileSizeBytes = fileSizeBytes
    }
}
```

- [ ] **Step 7: Write `Domain/Sources/Models/ReadingProgress.swift`**

```swift
import Foundation

public struct ReadingProgress: Equatable, Sendable, Hashable {
    public let comicId: UUID
    public let lastPageIndex: Int
    public let totalPages: Int
    public let updatedAt: Date

    public init(comicId: UUID, lastPageIndex: Int, totalPages: Int, updatedAt: Date) {
        self.comicId = comicId
        self.lastPageIndex = lastPageIndex
        self.totalPages = totalPages
        self.updatedAt = updatedAt
    }
}
```

- [ ] **Step 8: Write `Domain/Sources/Models/Bookmark.swift`**

```swift
import Foundation

public struct Bookmark: Identifiable, Equatable, Sendable, Hashable {
    public let id: UUID
    public let comicId: UUID
    public let pageIndex: Int
    public let note: String?
    public let createdAt: Date

    public init(id: UUID, comicId: UUID, pageIndex: Int, note: String?, createdAt: Date) {
        self.id = id
        self.comicId = comicId
        self.pageIndex = pageIndex
        self.note = note
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 9: Write `Domain/Sources/Models/ReadingMode.swift`**

```swift
import Foundation

public enum ReadingMode: Equatable, Sendable, Hashable {
    case single
    case dual
    case scroll(direction: ScrollDirection)
}

public enum ScrollDirection: String, Sendable, Equatable, Hashable, CaseIterable {
    case ltr, rtl, ttb
}
```

- [ ] **Step 10: Write `Domain/Sources/Repositories/ArchiveReader.swift`**

```swift
import Foundation

/// Opaque session token for an opened archive. The real per-archive state
/// (file descriptor, decoded entry list, etc.) lives inside the ArchiveReader
/// implementation, keyed by `id`. Treat this as a value type — equality is
/// identity equality.
public struct ArchiveHandle: Equatable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public init(id: UUID = UUID()) { self.id = id }
}

public protocol ArchiveReader: Sendable {
    func openArchive(at url: URL) async throws -> ArchiveHandle
    func pageCount(_ handle: ArchiveHandle) async -> Int
    func pageData(_ handle: ArchiveHandle, index: Int) async throws -> Data
    func closeArchive(_ handle: ArchiveHandle) async
}

public enum ArchiveError: Error, Equatable, Sendable {
    case unsupportedFormat(String)
    case corrupted
    case encrypted
    case ioFailure(reason: String)
    case indexOutOfBounds(Int)
}
```

- [ ] **Step 11: Write `Domain/Sources/Repositories/ArchiveReaderRouter.swift`**

```swift
import Foundation

public protocol ArchiveReaderRouter: Sendable {
    func reader(for format: ComicFormat) -> any ArchiveReader
}
```

- [ ] **Step 12: Write `Domain/Sources/Repositories/ComicRepository.swift`**

```swift
import Foundation

public protocol ComicRepository: Sendable {
    func all() async -> [ComicItem]
    func comic(id: UUID) async -> ComicItem?
    func upsert(_ item: ComicItem) async throws
    func delete(_ id: UUID) async throws
}
```

- [ ] **Step 13: Write `Domain/Sources/Repositories/ProgressRepository.swift`**

```swift
import Foundation

public protocol ProgressRepository: Sendable {
    func load(comicId: UUID) async -> ReadingProgress?
    func save(_ progress: ReadingProgress) async throws
}
```

- [ ] **Step 14: Write `Domain/Sources/Repositories/BookmarkRepository.swift`**

```swift
import Foundation

public protocol BookmarkRepository: Sendable {
    func bookmarks(comicId: UUID) async -> [Bookmark]
    func add(_ bookmark: Bookmark) async throws
    func remove(id: UUID) async throws
}
```

- [ ] **Step 15: Write `Domain/Sources/Repositories/FileSyncService.swift`**

```swift
import Foundation

public enum FileSyncEvent: Sendable, Equatable {
    case added(URL)
    case removed(URL)
    case updated(URL)
}

public enum SyncError: Error, Equatable, Sendable {
    case iCloudUnavailable
    case quotaExceeded
    case downloadFailed(reason: String)
}

public protocol FileSyncService: Sendable {
    var isAvailable: Bool { get async }
    func ingest(localURL: URL) async throws -> URL
    func ensureLocal(url: URL) async throws
    func observeChanges() -> AsyncStream<FileSyncEvent>
}
```

- [ ] **Step 16: Write `Domain/Sources/Repositories/ThumbnailProvider.swift`**

```swift
import Foundation

public protocol ThumbnailProvider: Sendable {
    func thumbnail(for comicId: UUID, page: Int, maxDim: CGFloat) async throws -> Data
}
```

- [ ] **Step 17: Run tests to verify they pass**

Run: `tuist generate --no-open && tuist test Domain`
Expected: PASS — both test files green.

- [ ] **Step 18: Commit**

```bash
git add Domain/
git commit -m "feat(domain): models + repository protocols"
```

---

## Task 3: ImageCache (memory + disk LRU)

**Files:**
- Create: `Data/ImageCacheKit/Project.swift`
- Create: `Data/ImageCacheKit/Sources/PageKey.swift`
- Create: `Data/ImageCacheKit/Sources/DiskLRUCache.swift`
- Create: `Data/ImageCacheKit/Sources/ImageCache.swift`
- Test: `Data/ImageCacheKit/Tests/ImageCacheTests.swift`

- [ ] **Step 1: Write `Data/ImageCacheKit/Project.swift`**

```swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(name: "ImageCacheKit", kind: .data).project()
```

- [ ] **Step 2: Write failing tests `Data/ImageCacheKit/Tests/ImageCacheTests.swift`**

```swift
import Testing
import Foundation
@testable import ImageCacheKit

@Suite struct ImageCacheTests {

    @Test func storeAndRetrieveBytesInMemory() async {
        let cache = ImageCache.inMemoryOnly()
        let key = PageKey(comicId: UUID(), pageIndex: 0)
        let bytes = Data([0x01, 0x02, 0x03])
        await cache.store(bytes, for: key)
        let got = await cache.data(for: key)
        #expect(got == bytes)
    }

    @Test func missingKeyReturnsNil() async {
        let cache = ImageCache.inMemoryOnly()
        let got = await cache.data(for: PageKey(comicId: UUID(), pageIndex: 5))
        #expect(got == nil)
    }

    @Test func diskRoundTrip() async throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "imgcache-\(UUID().uuidString)")
        let cache = ImageCache(diskDirectory: dir, diskCapacityBytes: 10_000_000)
        let key = PageKey(comicId: UUID(), pageIndex: 7)
        let bytes = Data(repeating: 0xAB, count: 1024)
        await cache.store(bytes, for: key)
        // Force memory eviction to test disk fallback
        await cache.evictMemory()
        let got = await cache.data(for: key)
        #expect(got == bytes)
        try? FileManager.default.removeItem(at: dir)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `tuist test ImageCacheKit`
Expected: compile failure — `ImageCache`, `PageKey` not found.

- [ ] **Step 4: Write `Data/ImageCacheKit/Sources/PageKey.swift`**

```swift
import Foundation

public struct PageKey: Hashable, Sendable {
    public let comicId: UUID
    public let pageIndex: Int

    public init(comicId: UUID, pageIndex: Int) {
        self.comicId = comicId
        self.pageIndex = pageIndex
    }

    public var fileName: String {
        "\(comicId.uuidString)-\(pageIndex).bin"
    }
}
```

- [ ] **Step 5: Write `Data/ImageCacheKit/Sources/DiskLRUCache.swift`**

```swift
import Foundation

actor DiskLRUCache {
    private let directory: URL
    private let capacityBytes: Int
    private var totalBytes: Int = 0
    private var accessOrder: [String] = []   // newest at end

    init(directory: URL, capacityBytes: Int) {
        self.directory = directory
        self.capacityBytes = capacityBytes
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        rebuildIndex()
    }

    func read(name: String) -> Data? {
        let url = directory.appending(path: name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        touch(name)
        return data
    }

    func write(name: String, data: Data) throws {
        let url = directory.appending(path: name)
        try data.write(to: url, options: .atomic)
        if let idx = accessOrder.firstIndex(of: name) {
            accessOrder.remove(at: idx)
        } else {
            totalBytes += data.count
        }
        accessOrder.append(name)
        evictIfNeeded()
    }

    private func touch(_ name: String) {
        if let idx = accessOrder.firstIndex(of: name) {
            accessOrder.remove(at: idx)
            accessOrder.append(name)
        }
    }

    private func rebuildIndex() {
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey])) ?? []
        let sorted = items.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? .distantPast
            return l < r
        }
        accessOrder = sorted.map { $0.lastPathComponent }
        totalBytes = sorted.reduce(0) { acc, url in
            acc + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    private func evictIfNeeded() {
        let fm = FileManager.default
        while totalBytes > capacityBytes, let oldest = accessOrder.first {
            let url = directory.appending(path: oldest)
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            try? fm.removeItem(at: url)
            totalBytes -= size
            accessOrder.removeFirst()
        }
    }
}
```

- [ ] **Step 6: Write `Data/ImageCacheKit/Sources/ImageCache.swift`**

```swift
import Foundation

public actor ImageCache {
    private let memoryLimit: Int
    private var memory: [PageKey: Data] = [:]
    private var memoryOrder: [PageKey] = []
    private let disk: DiskLRUCache?

    public init(diskDirectory: URL?, diskCapacityBytes: Int = 200_000_000, memoryLimit: Int = 50) {
        self.memoryLimit = memoryLimit
        self.disk = diskDirectory.map { DiskLRUCache(directory: $0, capacityBytes: diskCapacityBytes) }
    }

    public static func inMemoryOnly(memoryLimit: Int = 50) -> ImageCache {
        ImageCache(diskDirectory: nil, memoryLimit: memoryLimit)
    }

    public func data(for key: PageKey) async -> Data? {
        if let cached = memory[key] {
            touchMemory(key)
            return cached
        }
        if let disk, let bytes = await disk.read(name: key.fileName) {
            putMemory(key, data: bytes)
            return bytes
        }
        return nil
    }

    public func store(_ data: Data, for key: PageKey) async {
        putMemory(key, data: data)
        if let disk {
            try? await disk.write(name: key.fileName, data: data)
        }
    }

    public func evictMemory() {
        memory.removeAll()
        memoryOrder.removeAll()
    }

    private func putMemory(_ key: PageKey, data: Data) {
        if memory[key] == nil {
            memoryOrder.append(key)
        } else {
            touchMemory(key)
        }
        memory[key] = data
        while memoryOrder.count > memoryLimit {
            let evicted = memoryOrder.removeFirst()
            memory.removeValue(forKey: evicted)
        }
    }

    private func touchMemory(_ key: PageKey) {
        if let idx = memoryOrder.firstIndex(of: key) {
            memoryOrder.remove(at: idx)
            memoryOrder.append(key)
        }
    }
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `tuist test ImageCacheKit`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Data/ImageCacheKit/
git commit -m "feat(image-cache-kit): memory + disk LRU image cache"
```

---

## Task 4: ArchiveKit — ZipArchiveReader for ZIP/CBZ

**Files:**
- Create: `Data/ArchiveKit/Project.swift`
- Create: `Data/ArchiveKit/Sources/ArchiveHandleImpl.swift`
- Create: `Data/ArchiveKit/Sources/ZipArchiveReader.swift`
- Create: `Data/ArchiveKit/Sources/DefaultArchiveReaderRouter.swift`
- Create: `Data/ArchiveKit/Tests/Resources/sample.cbz`
- Create: `Data/ArchiveKit/Tests/ZipArchiveReaderTests.swift`

- [ ] **Step 1: Write `Data/ArchiveKit/Project.swift`**

```swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "ArchiveKit",
    kind: .data,
    dependencies: [.project(target: "Domain", path: "../../Domain")],
    externalDependencies: ["ZIPFoundation"],
    hasResources: false
).project()
```

- [ ] **Step 2: Generate test fixture `sample.cbz`**

Run:
```bash
mkdir -p /tmp/cbz_fixture && cd /tmp/cbz_fixture
# Make 3 trivial JPEG-like files (just bytes, valid as images? — for read-bytes test, raw bytes are fine)
printf 'PAGE1' > 001.jpg
printf 'PAGE2-CONTENTS' > 002.jpg
printf 'PAGE3-MORE-CONTENTS' > 003.jpg
zip -j /Users/doyoung_kim/Documents/Git/mana/Data/ArchiveKit/Tests/Resources/sample.cbz 001.jpg 002.jpg 003.jpg
ls -la /Users/doyoung_kim/Documents/Git/mana/Data/ArchiveKit/Tests/Resources/sample.cbz
```

The `Module` helper auto-includes `Tests/Resources/**` in the test target.

- [ ] **Step 3: Write failing tests `Data/ArchiveKit/Tests/ZipArchiveReaderTests.swift`**

```swift
import Testing
import Foundation
@testable import ArchiveKit
import Domain

@Suite struct ZipArchiveReaderTests {
    private final class BundleAnchor {}

    private func fixtureURL() throws -> URL {
        let url = Bundle(for: BundleAnchor.self).url(forResource: "sample", withExtension: "cbz")
        try #require(url != nil)
        return url!
    }

    @Test func opensCbzAndReportsThreePages() async throws {
        let reader = ZipArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        #expect(await reader.pageCount(handle) == 3)
        await reader.closeArchive(handle)
    }

    @Test func readsFirstPageBytes() async throws {
        let reader = ZipArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        let data = try await reader.pageData(handle, index: 0)
        #expect(String(data: data, encoding: .utf8) == "PAGE1")
        await reader.closeArchive(handle)
    }

    @Test func indexOutOfBoundsThrows() async throws {
        let reader = ZipArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        await #expect(throws: ArchiveError.indexOutOfBounds(99)) {
            _ = try await reader.pageData(handle, index: 99)
        }
        await reader.closeArchive(handle)
    }

    @Test func pagesAreSortedByName() async throws {
        let reader = ZipArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        let p0 = try await reader.pageData(handle, index: 0)
        let p1 = try await reader.pageData(handle, index: 1)
        let p2 = try await reader.pageData(handle, index: 2)
        #expect(String(data: p0, encoding: .utf8) == "PAGE1")
        #expect(String(data: p1, encoding: .utf8) == "PAGE2-CONTENTS")
        #expect(String(data: p2, encoding: .utf8) == "PAGE3-MORE-CONTENTS")
        await reader.closeArchive(handle)
    }

    @Test func routerReturnsZipReaderForCbz() {
        let router = DefaultArchiveReaderRouter(zip: ZipArchiveReader())
        let r = router.reader(for: .cbz)
        #expect(r is ZipArchiveReader)
    }
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `tuist test ArchiveKit`
Expected: compile failure — `ZipArchiveReader`, `DefaultArchiveReaderRouter` not found.

- [ ] **Step 5: Write `Data/ArchiveKit/Sources/ArchiveHandleImpl.swift`**

```swift
import Foundation
import ZIPFoundation
import Domain

actor ZipArchiveSessionStore {
    static let shared = ZipArchiveSessionStore()
    private var archives: [UUID: Archive] = [:]
    private var entryLists: [UUID: [Entry]] = [:]

    func register(_ archive: Archive, sortedImageEntries: [Entry]) -> UUID {
        let id = UUID()
        archives[id] = archive
        entryLists[id] = sortedImageEntries
        return id
    }

    func archive(for id: UUID) -> Archive? { archives[id] }
    func entries(for id: UUID) -> [Entry]? { entryLists[id] }

    func close(_ id: UUID) {
        archives.removeValue(forKey: id)
        entryLists.removeValue(forKey: id)
    }
}
```

- [ ] **Step 6: Write `Data/ArchiveKit/Sources/ZipArchiveReader.swift`**

```swift
import Foundation
import ZIPFoundation
import Domain

public struct ZipArchiveReader: ArchiveReader {
    public init() {}

    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "heic"]

    public func openArchive(at url: URL) async throws -> ArchiveHandle {
        do {
            let archive = try Archive(url: url, accessMode: .read)
            let imageEntries = archive
                .filter { entry in
                    let ext = (entry.path as NSString).pathExtension.lowercased()
                    return entry.type == .file && Self.imageExtensions.contains(ext)
                }
                .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
            let id = await ZipArchiveSessionStore.shared.register(archive, sortedImageEntries: imageEntries)
            return ArchiveHandle(id: id)
        } catch let error as Archive.ArchiveError {
            throw map(error)
        } catch {
            throw ArchiveError.ioFailure(reason: error.localizedDescription)
        }
    }

    public func pageCount(_ handle: ArchiveHandle) async -> Int {
        await ZipArchiveSessionStore.shared.entries(for: handle.id)?.count ?? 0
    }

    public func pageData(_ handle: ArchiveHandle, index: Int) async throws -> Data {
        guard let entries = await ZipArchiveSessionStore.shared.entries(for: handle.id),
              let archive = await ZipArchiveSessionStore.shared.archive(for: handle.id)
        else {
            throw ArchiveError.ioFailure(reason: "handle closed")
        }
        guard index >= 0, index < entries.count else {
            throw ArchiveError.indexOutOfBounds(index)
        }
        var buffer = Data()
        do {
            _ = try archive.extract(entries[index]) { chunk in
                buffer.append(chunk)
            }
            return buffer
        } catch let error as Archive.ArchiveError {
            throw map(error)
        } catch {
            throw ArchiveError.ioFailure(reason: error.localizedDescription)
        }
    }

    public func closeArchive(_ handle: ArchiveHandle) async {
        await ZipArchiveSessionStore.shared.close(handle.id)
    }

    private func map(_ error: Archive.ArchiveError) -> ArchiveError {
        switch error {
        case .invalidPasswordError, .missingPasswordError:
            return .encrypted
        case .invalidEntryPath, .invalidStartOfCentralDirectoryOffset, .missingEndOfCentralDirectoryRecord:
            return .corrupted
        default:
            return .ioFailure(reason: String(describing: error))
        }
    }
}
```

- [ ] **Step 7: Write `Data/ArchiveKit/Sources/DefaultArchiveReaderRouter.swift`**

```swift
import Foundation
import Domain

public struct DefaultArchiveReaderRouter: ArchiveReaderRouter {
    private let zip: ZipArchiveReader

    public init(zip: ZipArchiveReader = ZipArchiveReader()) {
        self.zip = zip
    }

    public func reader(for format: ComicFormat) -> any ArchiveReader {
        switch format {
        case .zip, .cbz:
            return zip
        case .rar, .cbr, .pdf, .folder:
            // Plan 2 adds these; for now, return zip and let it throw an unsupported error if used.
            // Fail loudly so we don't silently route wrong formats.
            preconditionFailure("Format \(format.rawValue) not supported until Plan 2")
        }
    }
}
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `tuist test ArchiveKit`
Expected: all 5 tests PASS.

- [ ] **Step 9: Commit**

```bash
git add Data/ArchiveKit/
git commit -m "feat(archive-kit): ZipArchiveReader for ZIP/CBZ via ZIPFoundation"
```

---

## Task 5: PersistenceKit — SwiftData stack and ComicRepository

**Files:**
- Create: `Data/PersistenceKit/Project.swift`
- Create: `Data/PersistenceKit/Sources/SwiftDataModels.swift`
- Create: `Data/PersistenceKit/Sources/SwiftDataStack.swift`
- Create: `Data/PersistenceKit/Sources/ComicRepositoryLive.swift`
- Create: `Data/PersistenceKit/Sources/ProgressRepositoryLive.swift`
- Create: `Data/PersistenceKit/Sources/BookmarkRepositoryLive.swift`
- Test: `Data/PersistenceKit/Tests/ComicRepositoryLiveTests.swift`
- Test: `Data/PersistenceKit/Tests/ProgressRepositoryLiveTests.swift`

- [ ] **Step 1: Write `Data/PersistenceKit/Project.swift`**

```swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "PersistenceKit",
    kind: .data,
    dependencies: [.project(target: "Domain", path: "../../Domain")]
).project()
```

- [ ] **Step 2: Write failing tests `Data/PersistenceKit/Tests/ComicRepositoryLiveTests.swift`**

```swift
import Testing
import Foundation
import SwiftData
@testable import PersistenceKit
import Domain

@Suite struct ComicRepositoryLiveTests {

    private func makeStack() throws -> SwiftDataStack {
        try SwiftDataStack.inMemory()
    }

    @Test func upsertAndAll() async throws {
        let stack = try makeStack()
        let repo = ComicRepositoryLive(stack: stack)
        let item = ComicItem(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/a.cbz"),
            format: .cbz,
            title: "A",
            pageCount: 10,
            coverThumbnail: nil,
            dateAdded: Date(timeIntervalSince1970: 0),
            fileSizeBytes: 1
        )
        try await repo.upsert(item)
        let all = await repo.all()
        #expect(all.count == 1)
        #expect(all.first?.title == "A")
    }

    @Test func upsertOverwritesById() async throws {
        let stack = try makeStack()
        let repo = ComicRepositoryLive(stack: stack)
        let id = UUID()
        let v1 = ComicItem(id: id, url: URL(fileURLWithPath: "/tmp/a.cbz"), format: .cbz, title: "A", pageCount: 1, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0), fileSizeBytes: 1)
        let v2 = ComicItem(id: id, url: URL(fileURLWithPath: "/tmp/a.cbz"), format: .cbz, title: "A2", pageCount: 1, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0), fileSizeBytes: 1)
        try await repo.upsert(v1)
        try await repo.upsert(v2)
        let all = await repo.all()
        #expect(all.count == 1)
        #expect(all.first?.title == "A2")
    }

    @Test func deleteById() async throws {
        let stack = try makeStack()
        let repo = ComicRepositoryLive(stack: stack)
        let item = ComicItem(id: UUID(), url: URL(fileURLWithPath: "/tmp/x"), format: .cbz, title: "X", pageCount: nil, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0), fileSizeBytes: 0)
        try await repo.upsert(item)
        try await repo.delete(item.id)
        let all = await repo.all()
        #expect(all.isEmpty)
    }
}
```

- [ ] **Step 3: Write failing tests `Data/PersistenceKit/Tests/ProgressRepositoryLiveTests.swift`**

```swift
import Testing
import Foundation
@testable import PersistenceKit
import Domain

@Suite struct ProgressRepositoryLiveTests {

    @Test func saveAndLoad() async throws {
        let stack = try SwiftDataStack.inMemory()
        let repo = ProgressRepositoryLive(stack: stack)
        let progress = ReadingProgress(comicId: UUID(), lastPageIndex: 7, totalPages: 30, updatedAt: Date(timeIntervalSince1970: 100))
        try await repo.save(progress)
        let loaded = await repo.load(comicId: progress.comicId)
        #expect(loaded == progress)
    }

    @Test func saveOverwrites() async throws {
        let stack = try SwiftDataStack.inMemory()
        let repo = ProgressRepositoryLive(stack: stack)
        let id = UUID()
        try await repo.save(ReadingProgress(comicId: id, lastPageIndex: 1, totalPages: 10, updatedAt: .init(timeIntervalSince1970: 1)))
        try await repo.save(ReadingProgress(comicId: id, lastPageIndex: 5, totalPages: 10, updatedAt: .init(timeIntervalSince1970: 2)))
        let loaded = await repo.load(comicId: id)
        #expect(loaded?.lastPageIndex == 5)
    }
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `tuist test PersistenceKit`
Expected: compile failure.

- [ ] **Step 5: Write `Data/PersistenceKit/Sources/SwiftDataModels.swift`**

```swift
import Foundation
import SwiftData
import Domain

@Model
public final class ComicEntity {
    @Attribute(.unique) public var id: UUID
    public var urlString: String
    public var formatRaw: String
    public var title: String
    public var pageCount: Int?
    public var coverThumbnail: Data?
    public var dateAdded: Date
    public var fileSizeBytes: Int64

    public init(
        id: UUID,
        urlString: String,
        formatRaw: String,
        title: String,
        pageCount: Int?,
        coverThumbnail: Data?,
        dateAdded: Date,
        fileSizeBytes: Int64
    ) {
        self.id = id
        self.urlString = urlString
        self.formatRaw = formatRaw
        self.title = title
        self.pageCount = pageCount
        self.coverThumbnail = coverThumbnail
        self.dateAdded = dateAdded
        self.fileSizeBytes = fileSizeBytes
    }

    public func toModel() -> ComicItem {
        ComicItem(
            id: id,
            url: URL(string: urlString) ?? URL(fileURLWithPath: urlString),
            format: ComicFormat(rawValue: formatRaw) ?? .zip,
            title: title,
            pageCount: pageCount,
            coverThumbnail: coverThumbnail,
            dateAdded: dateAdded,
            fileSizeBytes: fileSizeBytes
        )
    }

    public static func from(_ item: ComicItem) -> ComicEntity {
        ComicEntity(
            id: item.id,
            urlString: item.url.absoluteString,
            formatRaw: item.format.rawValue,
            title: item.title,
            pageCount: item.pageCount,
            coverThumbnail: item.coverThumbnail,
            dateAdded: item.dateAdded,
            fileSizeBytes: item.fileSizeBytes
        )
    }
}

@Model
public final class ReadingProgressEntity {
    @Attribute(.unique) public var comicId: UUID
    public var lastPageIndex: Int
    public var totalPages: Int
    public var updatedAt: Date

    public init(comicId: UUID, lastPageIndex: Int, totalPages: Int, updatedAt: Date) {
        self.comicId = comicId
        self.lastPageIndex = lastPageIndex
        self.totalPages = totalPages
        self.updatedAt = updatedAt
    }

    public func toModel() -> ReadingProgress {
        ReadingProgress(comicId: comicId, lastPageIndex: lastPageIndex, totalPages: totalPages, updatedAt: updatedAt)
    }
}

@Model
public final class BookmarkEntity {
    @Attribute(.unique) public var id: UUID
    public var comicId: UUID
    public var pageIndex: Int
    public var note: String?
    public var createdAt: Date

    public init(id: UUID, comicId: UUID, pageIndex: Int, note: String?, createdAt: Date) {
        self.id = id
        self.comicId = comicId
        self.pageIndex = pageIndex
        self.note = note
        self.createdAt = createdAt
    }

    public func toModel() -> Bookmark {
        Bookmark(id: id, comicId: comicId, pageIndex: pageIndex, note: note, createdAt: createdAt)
    }
}
```

- [ ] **Step 6: Write `Data/PersistenceKit/Sources/SwiftDataStack.swift`**

```swift
import Foundation
import SwiftData

public final class SwiftDataStack: @unchecked Sendable {
    public let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public static func inMemory() throws -> SwiftDataStack {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ComicEntity.self, ReadingProgressEntity.self, BookmarkEntity.self,
            configurations: config
        )
        return SwiftDataStack(container: container)
    }

    public static func onDisk(url: URL) throws -> SwiftDataStack {
        let config = ModelConfiguration(url: url)
        let container = try ModelContainer(
            for: ComicEntity.self, ReadingProgressEntity.self, BookmarkEntity.self,
            configurations: config
        )
        return SwiftDataStack(container: container)
    }
}
```

- [ ] **Step 7: Write `Data/PersistenceKit/Sources/ComicRepositoryLive.swift`**

```swift
import Foundation
import SwiftData
import Domain

public actor ComicRepositoryLive: ComicRepository {
    private let stack: SwiftDataStack

    public init(stack: SwiftDataStack) {
        self.stack = stack
    }

    private func ctx() -> ModelContext { ModelContext(stack.container) }

    public func all() async -> [ComicItem] {
        let context = ctx()
        let descriptor = FetchDescriptor<ComicEntity>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        let results = (try? context.fetch(descriptor)) ?? []
        return results.map { $0.toModel() }
    }

    public func comic(id: UUID) async -> ComicItem? {
        let context = ctx()
        let descriptor = FetchDescriptor<ComicEntity>(predicate: #Predicate { $0.id == id })
        let results = (try? context.fetch(descriptor)) ?? []
        return results.first?.toModel()
    }

    public func upsert(_ item: ComicItem) async throws {
        let context = ctx()
        let id = item.id
        let descriptor = FetchDescriptor<ComicEntity>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.urlString = item.url.absoluteString
            existing.formatRaw = item.format.rawValue
            existing.title = item.title
            existing.pageCount = item.pageCount
            existing.coverThumbnail = item.coverThumbnail
            existing.dateAdded = item.dateAdded
            existing.fileSizeBytes = item.fileSizeBytes
        } else {
            context.insert(ComicEntity.from(item))
        }
        try context.save()
    }

    public func delete(_ id: UUID) async throws {
        let context = ctx()
        let descriptor = FetchDescriptor<ComicEntity>(predicate: #Predicate { $0.id == id })
        for entity in try context.fetch(descriptor) {
            context.delete(entity)
        }
        try context.save()
    }
}
```

- [ ] **Step 8: Write `Data/PersistenceKit/Sources/ProgressRepositoryLive.swift`**

```swift
import Foundation
import SwiftData
import Domain

public actor ProgressRepositoryLive: ProgressRepository {
    private let stack: SwiftDataStack

    public init(stack: SwiftDataStack) {
        self.stack = stack
    }

    private func ctx() -> ModelContext { ModelContext(stack.container) }

    public func load(comicId: UUID) async -> ReadingProgress? {
        let context = ctx()
        let descriptor = FetchDescriptor<ReadingProgressEntity>(predicate: #Predicate { $0.comicId == comicId })
        return (try? context.fetch(descriptor))?.first?.toModel()
    }

    public func save(_ progress: ReadingProgress) async throws {
        let context = ctx()
        let id = progress.comicId
        let descriptor = FetchDescriptor<ReadingProgressEntity>(predicate: #Predicate { $0.comicId == id })
        if let existing = try context.fetch(descriptor).first {
            existing.lastPageIndex = progress.lastPageIndex
            existing.totalPages = progress.totalPages
            existing.updatedAt = progress.updatedAt
        } else {
            context.insert(ReadingProgressEntity(
                comicId: progress.comicId,
                lastPageIndex: progress.lastPageIndex,
                totalPages: progress.totalPages,
                updatedAt: progress.updatedAt
            ))
        }
        try context.save()
    }
}
```

- [ ] **Step 9: Write `Data/PersistenceKit/Sources/BookmarkRepositoryLive.swift`**

```swift
import Foundation
import SwiftData
import Domain

public actor BookmarkRepositoryLive: BookmarkRepository {
    private let stack: SwiftDataStack

    public init(stack: SwiftDataStack) {
        self.stack = stack
    }

    private func ctx() -> ModelContext { ModelContext(stack.container) }

    public func bookmarks(comicId: UUID) async -> [Bookmark] {
        let context = ctx()
        let descriptor = FetchDescriptor<BookmarkEntity>(
            predicate: #Predicate { $0.comicId == comicId },
            sortBy: [SortDescriptor(\.pageIndex)]
        )
        return ((try? context.fetch(descriptor)) ?? []).map { $0.toModel() }
    }

    public func add(_ bookmark: Bookmark) async throws {
        let context = ctx()
        context.insert(BookmarkEntity(
            id: bookmark.id,
            comicId: bookmark.comicId,
            pageIndex: bookmark.pageIndex,
            note: bookmark.note,
            createdAt: bookmark.createdAt
        ))
        try context.save()
    }

    public func remove(id: UUID) async throws {
        let context = ctx()
        let descriptor = FetchDescriptor<BookmarkEntity>(predicate: #Predicate { $0.id == id })
        for entity in try context.fetch(descriptor) {
            context.delete(entity)
        }
        try context.save()
    }
}
```

- [ ] **Step 10: Run tests to verify they pass**

Run: `tuist test PersistenceKit`
Expected: all 5 tests PASS.

- [ ] **Step 11: Commit**

```bash
git add Data/PersistenceKit/
git commit -m "feat(persistence-kit): SwiftData stack + Comic/Progress/Bookmark repositories"
```

---

## Task 6: SharedUI — ZoomableImageView

**Files:**
- Create: `SharedUI/Project.swift`
- Create: `SharedUI/Sources/ZoomableImageView.swift`

(No tests — this is a thin UIKit bridge; will be exercised via XCUITest in Plan 2.)

- [ ] **Step 1: Write `SharedUI/Project.swift`**

```swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(name: "SharedUI", kind: .sharedUI).project()
```

Modify the helper to skip the test target when no `Tests/` exists. Edit `Tuist/ProjectDescriptionHelpers/Module.swift`:

Replace this block:
```swift
let testTarget = Target.target(
    name: "\(name)Tests",
    ...
)

return Project(
    name: name,
    targets: [frameworkTarget, testTarget]
)
```

With:
```swift
let fm = FileManager.default
let testsExist = fm.fileExists(atPath: "Tests")
var targets: [Target] = [frameworkTarget]
if testsExist {
    let testTarget = Target.target(
        name: "\(name)Tests",
        destinations: .iOS,
        product: .unitTests,
        bundleId: "\(bundleId).tests",
        deploymentTargets: deploymentTargets,
        sources: ["Tests/**"],
        resources: fm.fileExists(atPath: "Tests/Resources") ? ["Tests/Resources/**"] : nil,
        dependencies: [.target(name: name)]
    )
    targets.append(testTarget)
}
return Project(name: name, targets: targets)
```

- [ ] **Step 2: Write `SharedUI/Sources/ZoomableImageView.swift`**

```swift
import SwiftUI
import UIKit

public struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    let maxZoom: CGFloat

    public init(image: UIImage, maxZoom: CGFloat = 4.0) {
        self.image = image
        self.maxZoom = maxZoom
    }

    public func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = maxZoom
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = context.coordinator

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tag = 1
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    public func updateUIView(_ scrollView: UIScrollView, context: Context) {
        if let imageView = scrollView.viewWithTag(1) as? UIImageView {
            imageView.image = image
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public final class Coordinator: NSObject, UIScrollViewDelegate {
        public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            scrollView.viewWithTag(1)
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView = recognizer.view as? UIScrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                scrollView.setZoomScale(scrollView.maximumZoomScale * 0.5, animated: true)
            }
        }
    }
}
```

- [ ] **Step 3: Generate to verify it compiles**

Run: `tuist generate --no-open && xcodebuild -workspace Mana.xcworkspace -scheme SharedUI build CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add SharedUI/ Tuist/ProjectDescriptionHelpers/
git commit -m "feat(shared-ui): ZoomableImageView bridging UIScrollView"
```

---

## Task 7: DesignSystem — minimal placeholders

**Files:**
- Create: `DesignSystem/Project.swift`
- Create: `DesignSystem/Sources/Tokens.swift`
- Create: `DesignSystem/Sources/GlassToolbar.swift`

(Polish in Plan 4 — Plan 1 just needs these to compile and provide one toolbar primitive.)

- [ ] **Step 1: Write `DesignSystem/Project.swift`**

```swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(name: "DesignSystem", kind: .designSystem).project()
```

- [ ] **Step 2: Write `DesignSystem/Sources/Tokens.swift`**

```swift
import SwiftUI

public enum Tokens {
    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 16
        public static let l: CGFloat = 24
    }

    public enum Radius {
        public static let card: CGFloat = 12
        public static let pill: CGFloat = 999
    }
}
```

- [ ] **Step 3: Write `DesignSystem/Sources/GlassToolbar.swift`**

```swift
import SwiftUI

public struct GlassToolbar<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: Tokens.Spacing.m) {
            content
        }
        .padding(.horizontal, Tokens.Spacing.m)
        .padding(.vertical, Tokens.Spacing.s)
        .glassEffect(in: .capsule)
    }
}
```

> Note: `glassEffect(in:)` is iOS 26 Liquid Glass API. If the SDK exposes it under a different name in the version you're building against, fall back to `.background(.thinMaterial, in: .capsule)` — the structure is identical and Plan 4 polishes this module.

- [ ] **Step 4: Build to verify**

Run: `tuist generate --no-open && xcodebuild -workspace Mana.xcworkspace -scheme DesignSystem build CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add DesignSystem/
git commit -m "feat(design-system): tokens + GlassToolbar placeholder"
```

---

## Task 8: ReaderFeature (TCA) — single-page only

**Files:**
- Create: `Features/ReaderFeature/Project.swift`
- Create: `Features/ReaderFeature/Sources/PageRenderer.swift`
- Create: `Features/ReaderFeature/Sources/SinglePageRenderer.swift`
- Create: `Features/ReaderFeature/Sources/ReaderFeature.swift`
- Create: `Features/ReaderFeature/Sources/ReaderView.swift`
- Test: `Features/ReaderFeature/Tests/ReaderFeatureTests.swift`

- [ ] **Step 1: Write `Features/ReaderFeature/Project.swift`**

```swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "ReaderFeature",
    kind: .feature,
    dependencies: [
        .project(target: "Domain", path: "../../Domain"),
        .project(target: "ImageCacheKit", path: "../../Data/ImageCacheKit"),
        .project(target: "DesignSystem", path: "../../DesignSystem"),
        .project(target: "SharedUI", path: "../../SharedUI")
    ],
    externalDependencies: ["ComposableArchitecture"]
).project()
```

- [ ] **Step 2: Write failing tests `Features/ReaderFeature/Tests/ReaderFeatureTests.swift`**

```swift
import Testing
import Foundation
import ComposableArchitecture
@testable import ReaderFeature
import Domain
import ImageCacheKit

@Suite struct ReaderFeatureTests {

    private func sampleComic() -> ComicItem {
        ComicItem(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/sample.cbz"),
            format: .cbz,
            title: "Sample",
            pageCount: 10,
            coverThumbnail: nil,
            dateAdded: Date(timeIntervalSince1970: 0),
            fileSizeBytes: 0
        )
    }

    private struct StubReader: ArchiveReader {
        let handle: ArchiveHandle
        let pages: [Data]
        func openArchive(at url: URL) async throws -> ArchiveHandle { handle }
        func pageCount(_ handle: ArchiveHandle) async -> Int { pages.count }
        func pageData(_ handle: ArchiveHandle, index: Int) async throws -> Data {
            guard index >= 0 && index < pages.count else { throw ArchiveError.indexOutOfBounds(index) }
            return pages[index]
        }
        func closeArchive(_ handle: ArchiveHandle) async {}
    }

    private struct StubRouter: ArchiveReaderRouter {
        let reader: any ArchiveReader
        func reader(for format: ComicFormat) -> any ArchiveReader { reader }
    }

    @Test func taskOpensArchiveAndLoadsLastPage() async {
        let pages = (0..<5).map { Data([UInt8($0)]) }
        let stubHandle = ArchiveHandle()
        let stubReader = StubReader(handle: stubHandle, pages: pages)
        let router = StubRouter(reader: stubReader)
        let comic = sampleComic()

        let progress = ReadingProgress(comicId: comic.id, lastPageIndex: 2, totalPages: 5, updatedAt: Date())
        let progressRepo = InMemoryProgressRepo(initial: [progress])

        let store = await TestStore(initialState: ReaderFeature.State(comic: comic)) {
            ReaderFeature()
        } withDependencies: {
            $0.archiveReaderRouter = router
            $0.progressRepository = progressRepo
            $0.imageCache = ImageCache.inMemoryOnly()
            $0.mainQueue = .immediate
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.task)
        await store.receive(\.opened) {
            $0.handle = stubHandle
            $0.pageCount = 5
            $0.pageIndex = 2
        }
        await store.receive(\.pageLoaded) {
            $0.loadedIndices.insert(2)
        }
    }

    @Test func pageChangedUpdatesIndex() async {
        let pages = (0..<5).map { Data([UInt8($0)]) }
        let stubHandle = ArchiveHandle()
        let stubReader = StubReader(handle: stubHandle, pages: pages)
        let router = StubRouter(reader: stubReader)

        let store = await TestStore(
            initialState: ReaderFeature.State(comic: sampleComic(), handle: stubHandle, pageIndex: 0, pageCount: 5)
        ) {
            ReaderFeature()
        } withDependencies: {
            $0.archiveReaderRouter = router
            $0.progressRepository = InMemoryProgressRepo(initial: [])
            $0.imageCache = ImageCache.inMemoryOnly()
            $0.mainQueue = .immediate
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.pageChanged(3)) {
            $0.pageIndex = 3
        }
        await store.receive(\.pageLoaded) {
            $0.loadedIndices.insert(3)
        }
    }
}

actor InMemoryProgressRepo: ProgressRepository {
    private var store: [UUID: ReadingProgress]
    init(initial: [ReadingProgress]) {
        self.store = Dictionary(uniqueKeysWithValues: initial.map { ($0.comicId, $0) })
    }
    func load(comicId: UUID) async -> ReadingProgress? { store[comicId] }
    func save(_ progress: ReadingProgress) async throws { store[progress.comicId] = progress }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `tuist test ReaderFeature`
Expected: compile failure.

- [ ] **Step 4: Write `Features/ReaderFeature/Sources/PageRenderer.swift`**

```swift
import SwiftUI
import ImageCacheKit

public protocol PageRenderer: View {
    init(
        totalPages: Int,
        current: Binding<Int>,
        cache: ImageCache,
        onPrefetchHint: @escaping (Int) -> Void
    )
}
```

- [ ] **Step 5: Write `Features/ReaderFeature/Sources/SinglePageRenderer.swift`**

```swift
import SwiftUI
import UIKit
import ImageCacheKit
import SharedUI

public struct SinglePageRenderer: View, PageRenderer {
    let totalPages: Int
    @Binding var current: Int
    let cache: ImageCache
    let onPrefetchHint: (Int) -> Void

    @State private var image: UIImage?
    @State private var loadingIndex: Int?

    public init(
        totalPages: Int,
        current: Binding<Int>,
        cache: ImageCache,
        onPrefetchHint: @escaping (Int) -> Void
    ) {
        self.totalPages = totalPages
        self._current = current
        self.cache = cache
        self.onPrefetchHint = onPrefetchHint
    }

    public var body: some View {
        ZStack {
            if let image {
                ZoomableImageView(image: image)
            } else {
                ProgressView()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width < -50, current < totalPages - 1 {
                        current += 1
                    } else if value.translation.width > 50, current > 0 {
                        current -= 1
                    }
                }
        )
        .task(id: current) {
            await load(current)
        }
    }

    private func load(_ index: Int) async {
        loadingIndex = index
        // Hint reducer to ensure pages are decoded
        onPrefetchHint(index)
        // Poll cache up to 3s for the page bytes (reducer fills it)
        let key = makeKey(comicId: comicId(), pageIndex: index)
        for _ in 0..<60 {
            if let data = await cache.data(for: key), let img = UIImage(data: data) {
                if loadingIndex == index { image = img }
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    // The renderer is comic-agnostic; comicId comes from a per-instance key set by ReaderView.
    @Environment(\.comicId) private var environmentComicId
    private func comicId() -> UUID { environmentComicId }
}

private struct ComicIdKey: EnvironmentKey {
    static let defaultValue: UUID = UUID()
}

extension EnvironmentValues {
    var comicId: UUID {
        get { self[ComicIdKey.self] }
        set { self[ComicIdKey.self] = newValue }
    }
}

func makeKey(comicId: UUID, pageIndex: Int) -> PageKey {
    PageKey(comicId: comicId, pageIndex: pageIndex)
}
```

- [ ] **Step 6: Write `Features/ReaderFeature/Sources/ReaderFeature.swift`**

```swift
import Foundation
import ComposableArchitecture
import Domain
import ImageCacheKit

@Reducer
public struct ReaderFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var comic: ComicItem
        public var handle: ArchiveHandle?
        public var pageIndex: Int
        public var pageCount: Int
        public var mode: ReadingMode
        public var isControlsVisible: Bool
        public var loadedIndices: Set<Int>
        @Presents public var alert: AlertState<Action.Alert>?

        public init(
            comic: ComicItem,
            handle: ArchiveHandle? = nil,
            pageIndex: Int = 0,
            pageCount: Int = 0,
            mode: ReadingMode = .single,
            isControlsVisible: Bool = false,
            loadedIndices: Set<Int> = []
        ) {
            self.comic = comic
            self.handle = handle
            self.pageIndex = pageIndex
            self.pageCount = pageCount
            self.mode = mode
            self.isControlsVisible = isControlsVisible
            self.loadedIndices = loadedIndices
        }
    }

    public enum Action {
        case task
        case opened(handle: ArchiveHandle, pageCount: Int, lastPage: Int)
        case openFailed(String)
        case pageChanged(Int)
        case pageLoaded(index: Int)
        case prefetchHint(Int)
        case toggleControls
        case persistProgress
        case onDisappear
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    @Dependency(\.archiveReaderRouter) var router
    @Dependency(\.progressRepository) var progress
    @Dependency(\.imageCache) var imageCache
    @Dependency(\.mainQueue) var mainQueue

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let comic = state.comic
                return .run { send in
                    do {
                        let reader = router.reader(for: comic.format)
                        let handle = try await reader.openArchive(at: comic.url)
                        let pageCount = await reader.pageCount(handle)
                        let saved = await progress.load(comicId: comic.id)
                        let lastPage = saved.map { min(max(0, $0.lastPageIndex), max(0, pageCount - 1)) } ?? 0
                        await send(.opened(handle: handle, pageCount: pageCount, lastPage: lastPage))
                        await send(.prefetchHint(lastPage))
                    } catch {
                        await send(.openFailed(error.localizedDescription))
                    }
                }

            case let .opened(handle, pageCount, lastPage):
                state.handle = handle
                state.pageCount = pageCount
                state.pageIndex = lastPage
                return .none

            case let .openFailed(message):
                state.alert = AlertState {
                    TextState("Cannot open comic")
                } message: {
                    TextState(message)
                }
                return .none

            case let .pageChanged(index):
                guard index != state.pageIndex, index >= 0, index < state.pageCount else { return .none }
                state.pageIndex = index
                return .merge(
                    .send(.prefetchHint(index)),
                    .send(.persistProgress)
                )

            case let .prefetchHint(index):
                guard let handle = state.handle else { return .none }
                let comicId = state.comic.id
                let format = state.comic.format
                let pageCount = state.pageCount
                let neighbors = [index - 1, index, index + 1].filter { $0 >= 0 && $0 < pageCount }
                return .run { send in
                    let reader = router.reader(for: format)
                    for i in neighbors {
                        let key = PageKey(comicId: comicId, pageIndex: i)
                        if await imageCache.data(for: key) != nil { continue }
                        do {
                            let data = try await reader.pageData(handle, index: i)
                            await imageCache.store(data, for: key)
                            await send(.pageLoaded(index: i))
                        } catch {
                            // Swallow; pageLoaded will not fire for this index
                        }
                    }
                }

            case let .pageLoaded(index):
                state.loadedIndices.insert(index)
                return .none

            case .toggleControls:
                state.isControlsVisible.toggle()
                return .none

            case .persistProgress:
                let p = ReadingProgress(
                    comicId: state.comic.id,
                    lastPageIndex: state.pageIndex,
                    totalPages: state.pageCount,
                    updatedAt: Date()
                )
                return .run { _ in
                    try? await progress.save(p)
                }
                .debounce(id: PersistDebounce(), for: .seconds(1), scheduler: mainQueue)

            case .onDisappear:
                guard let handle = state.handle else { return .none }
                let format = state.comic.format
                state.handle = nil
                return .run { _ in
                    let reader = router.reader(for: format)
                    await reader.closeArchive(handle)
                }

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private struct PersistDebounce: Hashable {}
}

// MARK: - Dependency Keys

private enum ArchiveReaderRouterKey: DependencyKey {
    static let liveValue: any ArchiveReaderRouter = LiveArchiveReaderRouterPlaceholder()
}

private struct LiveArchiveReaderRouterPlaceholder: ArchiveReaderRouter {
    func reader(for format: ComicFormat) -> any ArchiveReader {
        preconditionFailure("ArchiveReaderRouter not provided. Wire it in App composition root.")
    }
}

private enum ProgressRepositoryKey: DependencyKey {
    static let liveValue: any ProgressRepository = LiveProgressRepositoryPlaceholder()
}

private struct LiveProgressRepositoryPlaceholder: ProgressRepository {
    func load(comicId: UUID) async -> ReadingProgress? { nil }
    func save(_ progress: ReadingProgress) async throws {}
}

private enum ImageCacheKey: DependencyKey {
    static let liveValue: ImageCache = ImageCache.inMemoryOnly()
}

extension DependencyValues {
    public var archiveReaderRouter: any ArchiveReaderRouter {
        get { self[ArchiveReaderRouterKey.self] }
        set { self[ArchiveReaderRouterKey.self] = newValue }
    }
    public var progressRepository: any ProgressRepository {
        get { self[ProgressRepositoryKey.self] }
        set { self[ProgressRepositoryKey.self] = newValue }
    }
    public var imageCache: ImageCache {
        get { self[ImageCacheKey.self] }
        set { self[ImageCacheKey.self] = newValue }
    }
}
```

- [ ] **Step 7: Write `Features/ReaderFeature/Sources/ReaderView.swift`**

```swift
import SwiftUI
import ComposableArchitecture
import Domain
import ImageCacheKit
import DesignSystem

public struct ReaderView: View {
    @Bindable public var store: StoreOf<ReaderFeature>
    @Dependency(\.imageCache) private var imageCache

    public init(store: StoreOf<ReaderFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if store.pageCount > 0 {
                SinglePageRenderer(
                    totalPages: store.pageCount,
                    current: Binding(
                        get: { store.pageIndex },
                        set: { store.send(.pageChanged($0)) }
                    ),
                    cache: imageCache,
                    onPrefetchHint: { idx in store.send(.prefetchHint(idx)) }
                )
                .environment(\.comicId, store.comic.id)
                .ignoresSafeArea()
            } else {
                ProgressView().tint(.white)
            }

            if store.isControlsVisible {
                VStack {
                    Spacer()
                    GlassToolbar {
                        Text("\(store.pageIndex + 1) / \(store.pageCount)")
                            .foregroundStyle(.white)
                    }
                    .padding(.bottom, Tokens.Spacing.l)
                }
            }
        }
        .task { await store.send(.task).finish() }
        .onTapGesture { store.send(.toggleControls) }
        .onDisappear { store.send(.onDisappear) }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `tuist test ReaderFeature`
Expected: 2 tests PASS.

- [ ] **Step 9: Commit**

```bash
git add Features/ReaderFeature/
git commit -m "feat(reader-feature): TCA reducer + single-page renderer + view"
```

---

## Task 9: LibraryFeature (TCA) — list + import

**Files:**
- Create: `Features/LibraryFeature/Project.swift`
- Create: `Features/LibraryFeature/Sources/LibraryFeature.swift`
- Create: `Features/LibraryFeature/Sources/LibraryView.swift`
- Create: `Features/LibraryFeature/Sources/LibraryRow.swift`
- Test: `Features/LibraryFeature/Tests/LibraryFeatureTests.swift`

- [ ] **Step 1: Write `Features/LibraryFeature/Project.swift`**

```swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "LibraryFeature",
    kind: .feature,
    dependencies: [
        .project(target: "Domain", path: "../../Domain"),
        .project(target: "DesignSystem", path: "../../DesignSystem")
    ],
    externalDependencies: ["ComposableArchitecture"]
).project()
```

- [ ] **Step 2: Write failing tests `Features/LibraryFeature/Tests/LibraryFeatureTests.swift`**

```swift
import Testing
import Foundation
import ComposableArchitecture
@testable import LibraryFeature
import Domain

@Suite struct LibraryFeatureTests {

    private func sample(_ title: String) -> ComicItem {
        ComicItem(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/\(title).cbz"),
            format: .cbz,
            title: title,
            pageCount: 0,
            coverThumbnail: nil,
            dateAdded: Date(timeIntervalSince1970: 0),
            fileSizeBytes: 0
        )
    }

    @Test func taskLoadsComics() async {
        let initial = [sample("A"), sample("B")]
        let repo = StubComicRepo(initial: initial)

        let store = await TestStore(initialState: LibraryFeature.State()) {
            LibraryFeature()
        } withDependencies: {
            $0.comicRepository = repo
            $0.libraryImporter = StubImporter()
        }

        await store.send(.task)
        await store.receive(\.refreshed) {
            $0.comics = IdentifiedArray(uniqueElements: initial)
        }
    }

    @Test func importPickedAddsItems() async {
        let repo = StubComicRepo(initial: [])
        let imported = sample("Imported")
        let importer = StubImporter(stubResult: [imported])

        let store = await TestStore(initialState: LibraryFeature.State()) {
            LibraryFeature()
        } withDependencies: {
            $0.comicRepository = repo
            $0.libraryImporter = importer
        }

        await store.send(.importPicked([URL(fileURLWithPath: "/tmp/Imported.cbz")])) {
            $0.isImporting = true
        }
        await store.receive(\.imported) {
            $0.comics = IdentifiedArray(uniqueElements: [imported])
            $0.isImporting = false
        }
    }
}

actor StubComicRepo: ComicRepository {
    private var items: [ComicItem]
    init(initial: [ComicItem]) { self.items = initial }
    func all() async -> [ComicItem] { items }
    func comic(id: UUID) async -> ComicItem? { items.first { $0.id == id } }
    func upsert(_ item: ComicItem) async throws {
        if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = item }
        else { items.append(item) }
    }
    func delete(_ id: UUID) async throws { items.removeAll { $0.id == id } }
}

struct StubImporter: LibraryImporter, @unchecked Sendable {
    var stubResult: [ComicItem] = []
    func importFiles(_ urls: [URL]) async throws -> [ComicItem] { stubResult }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `tuist test LibraryFeature`
Expected: compile failure.

- [ ] **Step 4: Write `Features/LibraryFeature/Sources/LibraryFeature.swift`**

```swift
import Foundation
import ComposableArchitecture
import Domain

public protocol LibraryImporter: Sendable {
    /// Take user-picked file URLs, ingest them, and return persisted ComicItems.
    func importFiles(_ urls: [URL]) async throws -> [ComicItem]
}

@Reducer
public struct LibraryFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var comics: IdentifiedArrayOf<ComicItem> = []
        public var isImporting: Bool = false
        @Presents public var alert: AlertState<Action.Alert>?

        public init(
            comics: IdentifiedArrayOf<ComicItem> = [],
            isImporting: Bool = false
        ) {
            self.comics = comics
            self.isImporting = isImporting
        }
    }

    public enum Action {
        case task
        case refreshed([ComicItem])
        case importTapped
        case importPicked([URL])
        case imported([ComicItem])
        case importFailed(String)
        case comicTapped(ComicItem)
        case delete(IndexSet)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    @Dependency(\.comicRepository) var repo
    @Dependency(\.libraryImporter) var importer

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    let items = await repo.all()
                    await send(.refreshed(items))
                }

            case let .refreshed(items):
                state.comics = IdentifiedArray(uniqueElements: items)
                return .none

            case .importTapped:
                // Parent presents Files picker; reducer reacts to .importPicked
                return .none

            case let .importPicked(urls):
                state.isImporting = true
                return .run { send in
                    do {
                        let imported = try await importer.importFiles(urls)
                        await send(.imported(imported))
                    } catch {
                        await send(.importFailed(error.localizedDescription))
                    }
                }

            case let .imported(items):
                state.isImporting = false
                for item in items {
                    state.comics.updateOrAppend(item)
                }
                return .none

            case let .importFailed(message):
                state.isImporting = false
                state.alert = AlertState {
                    TextState("Import failed")
                } message: {
                    TextState(message)
                }
                return .none

            case .comicTapped:
                // Parent (AppFeature) handles navigation
                return .none

            case let .delete(indexSet):
                let ids = indexSet.map { state.comics[$0].id }
                for id in ids { state.comics.remove(id: id) }
                return .run { _ in
                    for id in ids {
                        try? await repo.delete(id)
                    }
                }

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

private enum ComicRepositoryKey: DependencyKey {
    static let liveValue: any ComicRepository = LiveComicRepoPlaceholder()
}

private struct LiveComicRepoPlaceholder: ComicRepository {
    func all() async -> [ComicItem] { [] }
    func comic(id: UUID) async -> ComicItem? { nil }
    func upsert(_ item: ComicItem) async throws {}
    func delete(_ id: UUID) async throws {}
}

private enum LibraryImporterKey: DependencyKey {
    static let liveValue: any LibraryImporter = LiveImporterPlaceholder()
}

private struct LiveImporterPlaceholder: LibraryImporter {
    func importFiles(_ urls: [URL]) async throws -> [ComicItem] { [] }
}

extension DependencyValues {
    public var comicRepository: any ComicRepository {
        get { self[ComicRepositoryKey.self] }
        set { self[ComicRepositoryKey.self] = newValue }
    }
    public var libraryImporter: any LibraryImporter {
        get { self[LibraryImporterKey.self] }
        set { self[LibraryImporterKey.self] = newValue }
    }
}
```

- [ ] **Step 5: Write `Features/LibraryFeature/Sources/LibraryRow.swift`**

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
                Text(comic.format.rawValue.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, Tokens.Spacing.s)
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

- [ ] **Step 6: Write `Features/LibraryFeature/Sources/LibraryView.swift`**

```swift
import SwiftUI
import ComposableArchitecture
import Domain
import UniformTypeIdentifiers

public struct LibraryView: View {
    @Bindable public var store: StoreOf<LibraryFeature>
    @State private var showImporter = false

    public init(store: StoreOf<LibraryFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            List {
                ForEach(store.comics) { comic in
                    Button {
                        store.send(.comicTapped(comic))
                    } label: {
                        LibraryRow(comic: comic)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in store.send(.delete(indexSet)) }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(store.isImporting)
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [
                    UTType(filenameExtension: "cbz") ?? .archive,
                    .zip
                ],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls): store.send(.importPicked(urls))
                case .failure: break
                }
            }
            .task { await store.send(.task).finish() }
            .alert($store.scope(state: \.alert, action: \.alert))
            .overlay {
                if store.isImporting { ProgressView("Importing…") }
            }
        }
    }
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `tuist test LibraryFeature`
Expected: 2 tests PASS.

- [ ] **Step 8: Commit**

```bash
git add Features/LibraryFeature/
git commit -m "feat(library-feature): TCA reducer + list view + Files importer"
```

---

## Task 10: AppFeature — root navigation

**Files:**
- Create: `Features/AppFeature/Project.swift`
- Create: `Features/AppFeature/Sources/AppFeature.swift`
- Create: `Features/AppFeature/Sources/AppView.swift`

(No tests — composition is exercised via the top-level App target's smoke test in Task 11.)

- [ ] **Step 1: Write `Features/AppFeature/Project.swift`**

```swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "AppFeature",
    kind: .feature,
    dependencies: [
        .project(target: "Domain", path: "../../Domain"),
        .project(target: "LibraryFeature", path: "../LibraryFeature"),
        .project(target: "ReaderFeature", path: "../ReaderFeature")
    ],
    externalDependencies: ["ComposableArchitecture"]
).project()
```

- [ ] **Step 2: Write `Features/AppFeature/Sources/AppFeature.swift`**

```swift
import Foundation
import ComposableArchitecture
import Domain
import LibraryFeature
import ReaderFeature

@Reducer
public struct AppFeature {
    public init() {}

    @Reducer
    public enum Path {
        case reader(ReaderFeature)
    }

    @ObservableState
    public struct State: Equatable {
        public var library: LibraryFeature.State
        public var path: StackState<Path.State>

        public init(
            library: LibraryFeature.State = LibraryFeature.State(),
            path: StackState<Path.State> = StackState()
        ) {
            self.library = library
            self.path = path
        }
    }

    public enum Action {
        case library(LibraryFeature.Action)
        case path(StackActionOf<Path>)
    }

    public var body: some ReducerOf<Self> {
        Scope(state: \.library, action: \.library) {
            LibraryFeature()
        }

        Reduce { state, action in
            switch action {
            case let .library(.comicTapped(comic)):
                state.path.append(.reader(ReaderFeature.State(comic: comic)))
                return .none

            case .library, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
```

- [ ] **Step 3: Write `Features/AppFeature/Sources/AppView.swift`**

```swift
import SwiftUI
import ComposableArchitecture
import LibraryFeature
import ReaderFeature

public struct AppView: View {
    @Bindable public var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            LibraryView(store: store.scope(state: \.library, action: \.library))
        } destination: { store in
            switch store.case {
            case let .reader(readerStore):
                ReaderView(store: readerStore)
            }
        }
    }
}
```

- [ ] **Step 4: Build to verify**

Run: `tuist generate --no-open && xcodebuild -workspace Mana.xcworkspace -scheme AppFeature build CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Features/AppFeature/
git commit -m "feat(app-feature): root reducer + NavigationStack composition"
```

---

## Task 11: App target — composition root

**Files:**
- Create: `App/Project.swift`
- Create: `App/Sources/ManaApp.swift`
- Create: `App/Sources/DependenciesLive.swift`
- Create: `App/Sources/LibraryImporterLive.swift`
- Create: `App/Resources/Info.plist`
- Create: `App/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `App/Resources/Assets.xcassets/Contents.json`

- [ ] **Step 1: Write `App/Project.swift`**

```swift
import ProjectDescription

let project = Project(
    name: "App",
    targets: [
        .target(
            name: "Mana",
            destinations: .iOS,
            product: .app,
            bundleId: "com.example.mana",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .file(path: "Resources/Info.plist"),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            dependencies: [
                .project(target: "AppFeature", path: "../Features/AppFeature"),
                .project(target: "LibraryFeature", path: "../Features/LibraryFeature"),
                .project(target: "ReaderFeature", path: "../Features/ReaderFeature"),
                .project(target: "ArchiveKit", path: "../Data/ArchiveKit"),
                .project(target: "PersistenceKit", path: "../Data/PersistenceKit"),
                .project(target: "ImageCacheKit", path: "../Data/ImageCacheKit"),
                .project(target: "Domain", path: "../Domain"),
                .external(name: "ComposableArchitecture")
            ],
            settings: .settings(base: [
                "TARGETED_DEVICE_FAMILY": "1,2",
                "SUPPORTS_MACCATALYST": "NO"
            ])
        )
    ]
)
```

- [ ] **Step 2: Write `App/Resources/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>Mana</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>UILaunchScreen</key>
  <dict/>
  <key>UISupportedInterfaceOrientations</key>
  <array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
  </array>
  <key>UISupportedInterfaceOrientations~ipad</key>
  <array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationPortraitUpsideDown</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
  </array>
  <key>UIFileSharingEnabled</key>
  <true/>
  <key>LSSupportsOpeningDocumentsInPlace</key>
  <true/>
</dict>
</plist>
```

- [ ] **Step 3: Write `App/Resources/Assets.xcassets/Contents.json`**

```json
{
  "info": { "version": 1, "author": "xcode" }
}
```

- [ ] **Step 4: Write `App/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`**

```json
{
  "images": [
    { "idiom": "universal", "platform": "ios", "size": "1024x1024" }
  ],
  "info": { "version": 1, "author": "xcode" }
}
```

- [ ] **Step 5: Write `App/Sources/LibraryImporterLive.swift`**

```swift
import Foundation
import Domain
import ArchiveKit
import ImageCacheKit
import LibraryFeature

public struct LibraryImporterLive: LibraryImporter {
    let repo: any ComicRepository
    let router: any ArchiveReaderRouter
    let cache: ImageCache

    public init(repo: any ComicRepository, router: any ArchiveReaderRouter, cache: ImageCache) {
        self.repo = repo
        self.router = router
        self.cache = cache
    }

    public func importFiles(_ urls: [URL]) async throws -> [ComicItem] {
        var results: [ComicItem] = []
        for url in urls {
            let needsStop = url.startAccessingSecurityScopedResource()
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }

            let format = ComicFormat(fileExtension: url.pathExtension) ?? .zip
            let reader = router.reader(for: format)
            let handle = try await reader.openArchive(at: url)
            let pageCount = await reader.pageCount(handle)

            var thumb: Data?
            if pageCount > 0 {
                thumb = try? await reader.pageData(handle, index: 0)
            }
            await reader.closeArchive(handle)

            let id = UUID()
            let title = url.deletingPathExtension().lastPathComponent
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0

            let item = ComicItem(
                id: id,
                url: url,
                format: format,
                title: title,
                pageCount: pageCount,
                coverThumbnail: thumb,
                dateAdded: Date(),
                fileSizeBytes: size
            )
            try await repo.upsert(item)
            results.append(item)
        }
        return results
    }
}
```

- [ ] **Step 6: Write `App/Sources/DependenciesLive.swift`**

```swift
import Foundation
import ComposableArchitecture
import Domain
import ArchiveKit
import PersistenceKit
import ImageCacheKit
import LibraryFeature
import ReaderFeature

enum LiveDependencies {
    static func register() {
        let stack = try! SwiftDataStack.onDisk(
            url: URL.applicationSupportDirectory.appending(path: "mana.store")
        )
        let comicRepo = ComicRepositoryLive(stack: stack)
        let progressRepo = ProgressRepositoryLive(stack: stack)
        let bookmarkRepo = BookmarkRepositoryLive(stack: stack)
        let router = DefaultArchiveReaderRouter()
        let cache = ImageCache(
            diskDirectory: URL.cachesDirectory.appending(path: "mana-pages"),
            diskCapacityBytes: 200_000_000
        )

        let importer = LibraryImporterLive(repo: comicRepo, router: router, cache: cache)

        prepareDependencies {
            $0.archiveReaderRouter = router
            $0.progressRepository = progressRepo
            $0.imageCache = cache
            $0.comicRepository = comicRepo
            $0.libraryImporter = importer
        }

        // Silence unused-variable warning for bookmarkRepo (used in Plan 2)
        _ = bookmarkRepo
    }
}
```

- [ ] **Step 7: Write `App/Sources/ManaApp.swift`**

```swift
import SwiftUI
import ComposableArchitecture
import AppFeature

@main
struct ManaApp: App {
    init() {
        LiveDependencies.register()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: Store(initialState: AppFeature.State()) {
                AppFeature()
            })
        }
    }
}
```

- [ ] **Step 8: Generate and build**

Run:
```bash
tuist generate --no-open
xcodebuild -workspace Mana.xcworkspace -scheme Mana -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' CODE_SIGNING_ALLOWED=NO build
```
Expected: BUILD SUCCEEDED

- [ ] **Step 9: Smoke test on simulator**

```bash
xcrun simctl boot "iPad Pro 13-inch (M4)" 2>/dev/null || true
xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/Mana-*/Build/Products/Debug-iphonesimulator/Mana.app
xcrun simctl launch booted com.example.mana
```
Expected: app launches, library is empty, `+` button opens Files picker. (Can't fully exercise without a `.cbz` on simulator — that's OK.)

- [ ] **Step 10: Commit**

```bash
git add App/
git commit -m "feat(app): composition root + live dependency wiring"
```

---

## Task 12: Final integration test — full flow with fixture

**Files:**
- Create: `App/Tests/IntegrationFlowTests.swift`
- Create: `App/Tests/Resources/sample.cbz`
- Modify: `App/Project.swift` to add a unit test target

This test wires the real ArchiveKit + PersistenceKit + ImageCacheKit + LibraryImporterLive against a fixture file, exercising the import → repo → reader-handle path end-to-end.

- [ ] **Step 1: Copy fixture from Task 4**

```bash
mkdir -p /Users/doyoung_kim/Documents/Git/mana/App/Tests/Resources
cp /Users/doyoung_kim/Documents/Git/mana/Data/ArchiveKit/Tests/Resources/sample.cbz \
   /Users/doyoung_kim/Documents/Git/mana/App/Tests/Resources/sample.cbz
```

- [ ] **Step 2: Modify `App/Project.swift` to add test target**

Replace the file with:

```swift
import ProjectDescription

let project = Project(
    name: "App",
    targets: [
        .target(
            name: "Mana",
            destinations: .iOS,
            product: .app,
            bundleId: "com.example.mana",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .file(path: "Resources/Info.plist"),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            dependencies: [
                .project(target: "AppFeature", path: "../Features/AppFeature"),
                .project(target: "LibraryFeature", path: "../Features/LibraryFeature"),
                .project(target: "ReaderFeature", path: "../Features/ReaderFeature"),
                .project(target: "ArchiveKit", path: "../Data/ArchiveKit"),
                .project(target: "PersistenceKit", path: "../Data/PersistenceKit"),
                .project(target: "ImageCacheKit", path: "../Data/ImageCacheKit"),
                .project(target: "Domain", path: "../Domain"),
                .external(name: "ComposableArchitecture")
            ],
            settings: .settings(base: [
                "TARGETED_DEVICE_FAMILY": "1,2",
                "SUPPORTS_MACCATALYST": "NO"
            ])
        ),
        .target(
            name: "ManaTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.example.mana.tests",
            deploymentTargets: .iOS("26.0"),
            sources: ["Tests/**"],
            resources: ["Tests/Resources/**"],
            dependencies: [
                .target(name: "Mana"),
                .project(target: "Domain", path: "../Domain"),
                .project(target: "ArchiveKit", path: "../Data/ArchiveKit"),
                .project(target: "PersistenceKit", path: "../Data/PersistenceKit"),
                .project(target: "ImageCacheKit", path: "../Data/ImageCacheKit"),
                .project(target: "LibraryFeature", path: "../Features/LibraryFeature")
            ]
        )
    ]
)
```

- [ ] **Step 3: Write `App/Tests/IntegrationFlowTests.swift`**

```swift
import Testing
import Foundation
@testable import Mana
import Domain
import ArchiveKit
import PersistenceKit
import ImageCacheKit
import LibraryFeature

@Suite struct IntegrationFlowTests {
    private final class BundleAnchor {}

    @Test func importThenReadFirstPageEndToEnd() async throws {
        // Wire real components except SwiftData (in-memory).
        let stack = try SwiftDataStack.inMemory()
        let comicRepo = ComicRepositoryLive(stack: stack)
        let router = DefaultArchiveReaderRouter()
        let cache = ImageCache.inMemoryOnly()
        let importer = LibraryImporterLive(repo: comicRepo, router: router, cache: cache)

        let fixture = try #require(Bundle(for: BundleAnchor.self).url(forResource: "sample", withExtension: "cbz"))

        // Import
        let imported = try await importer.importFiles([fixture])
        #expect(imported.count == 1)
        let comic = imported[0]
        #expect(comic.format == .cbz)
        #expect(comic.pageCount == 3)
        #expect(comic.coverThumbnail != nil)

        // Verify in repo
        let stored = await comicRepo.all()
        #expect(stored.count == 1)
        #expect(stored.first?.id == comic.id)

        // Open via router and read first page
        let reader = router.reader(for: comic.format)
        let handle = try await reader.openArchive(at: comic.url)
        let firstPage = try await reader.pageData(handle, index: 0)
        #expect(String(data: firstPage, encoding: .utf8) == "PAGE1")
        await reader.closeArchive(handle)
    }
}
```

- [ ] **Step 4: Generate and run integration test**

```bash
tuist generate --no-open
tuist test ManaTests
```
Expected: 1 test PASS.

- [ ] **Step 5: Commit**

```bash
git add App/
git commit -m "test(app): end-to-end integration test for import + read flow"
```

---

## Plan 1 Completion Checklist

- [ ] All module tests pass: `tuist test`
- [ ] App builds for iPad simulator: `xcodebuild -workspace Mana.xcworkspace -scheme Mana ... build`
- [ ] Manual smoke test: launch app on simulator, library empty, `+` opens Files picker
- [ ] Manual smoke test: drop a `.cbz` in simulator's Files app, import it, tap to open, swipe pages, see `1 / N` indicator on tap

## What's Next (Plan 2 preview)

Plan 2 will add:
1. UnrarKit + RarArchiveReader for `.rar` / `.cbr`
2. PDFArchiveReader using PDFKit
3. DualPageRenderer + ScrollPageRenderer (LTR/RTL/TTB)
4. BookmarksFeature + bookmark UI in reader
5. SettingsFeature for default reading mode

Plan 3 adds CloudKit + ubiquity container sync. Plan 4 polishes Liquid Glass design.

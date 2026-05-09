# Mana — Comic Reader for iPad/iPhone (iOS 26)

> **Status:** Design / Spec
> **Date:** 2026-05-08
> **Scope:** MVP + V2 features of LightComics-equivalent reader

## 1. Goal & Scope

Mana is a SwiftUI/TCA-based comic reader for iPad and iPhone (iOS 26+) that mirrors the core experience of LightComics — read ZIP/CBZ/RAR/PDF archives as comics with multiple page-layout modes, persistent reading progress, and library management. Mana extends LightComics by **syncing both reading state AND the archive files themselves** across the user's devices via iCloud, and adopts the iOS 26 **Liquid Glass** design system throughout.

### In Scope

- Local file import (Files app integration, share extension target deferred)
- Library: grid + list view with sorting, filtering, dark theme
- Reader: single page, dual page (book), continuous scroll (LTR / RTL / TTB)
- Reading progress + bookmarks
- iCloud sync of metadata (SwiftData + CloudKit) AND archive files (Ubiquity container)
- Liquid Glass UI throughout (toolbars, overlays, controls)

### Out of Scope (future phases)

- Remote storage providers (FTP, WebDAV, Dropbox, Google Drive, OneDrive)
- Wi-Fi HTTP transfer
- EPUB/TXT/TTS, Bluetooth keyboard, Face ID lock
- Slideshow, image filters (contrast/invert)

## 2. Tech Stack

| Layer | Choice |
|---|---|
| Min iOS | **26.0** |
| Targets | iPad (primary), iPhone |
| UI | SwiftUI + selective `UIViewRepresentable` (zoomable image, PDF) |
| Architecture | The Composable Architecture (TCA) 1.x with `@Reducer` macro |
| Project | Tuist 4.x (modular workspace) |
| Persistence | SwiftData with CloudKit container (auto sync) |
| File sync | iCloud Drive Ubiquity Container (`~/Documents` of `iCloud.com.example.mana`) |
| ZIP/CBZ | ZIPFoundation |
| RAR/CBR | UnrarKit (LGPL — dynamic link) |
| PDF | PDFKit (system) |
| Image cache | Custom NSCache (mem) + LRU disk cache |
| Design system | Liquid Glass (`glassEffect`, `GlassEffectContainer`, system materials) |
| Concurrency | Swift Concurrency (async/await), TCA `Effect.run` for side-effects |

## 3. Module Structure (Tuist Workspace)

```
Mana/
├── Workspace.swift
├── Tuist/
│   ├── Package.swift                 # ZIPFoundation, UnrarKit, ComposableArchitecture
│   └── ProjectDescriptionHelpers/    # Module template helpers
├── App/
│   └── ManaApp                       # Entry point, dependency wiring
├── Features/
│   ├── AppFeature                    # Root reducer, navigation tree
│   ├── LibraryFeature                # Browser, sort/filter, import
│   ├── ReaderFeature                 # Reader shell + reading mode strategy
│   ├── BookmarksFeature
│   └── SettingsFeature
├── Domain/
│   ├── Models                        # Pure value types
│   └── Repositories                  # Protocols only (no impl)
├── Data/
│   ├── ArchiveKit                    # ZIP/RAR readers, format detection
│   ├── PDFKitAdapter                 # PDFDocument → ArchiveReader
│   ├── PersistenceKit                # SwiftData stack + ProgressRepository impl
│   ├── CloudSyncKit                  # Ubiquity container manager, NSMetadataQuery
│   └── ImageCacheKit                 # Memory + disk LRU
├── DesignSystem/                     # Glass-aware components, colors, typography
└── SharedUI/                         # ZoomableImageView (UIScrollView), PageGrid
```

### Dependency Direction

```
App ──▶ Features ──▶ Domain ◀── Data
        Features ──▶ DesignSystem
        Features ──▶ SharedUI
```

- **Domain has zero dependencies** outside Foundation.
- **Features depend on Domain protocols only.**
- **Data implements Domain protocols.** Wired in `App` via TCA `@Dependency`.
- **DesignSystem and SharedUI** are independent of Features.

## 4. SOLID Mapping

- **SRP** — Each module has one responsibility. `ArchiveKit` only extracts; `LibraryFeature` only browses.
- **OCP** — New formats added by implementing `ArchiveReader`; new reading modes by implementing `PageRenderer`. No existing code touched.
- **LSP** — `ZipArchiveReader`, `RarArchiveReader`, `PDFArchiveReader` all interchangeable behind `ArchiveReader`. `SinglePageRenderer`, `DualPageRenderer`, `ScrollPageRenderer` interchangeable behind `PageRenderer`.
- **ISP** — Reading, extraction, thumbnailing split into separate small protocols. Consumers depend only on what they use.
- **DIP** — Features inject protocols via TCA `@Dependency`. Mocks in tests; real impls in app composition root.

## 5. Domain Models

```swift
// Mana/Domain/Models

public struct ComicItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let url: URL                  // ubiquity-relative or local
    public let format: ComicFormat
    public let title: String
    public let pageCount: Int?
    public let coverThumbnail: Data?
    public let dateAdded: Date
    public let fileSizeBytes: Int64
}

public enum ComicFormat: String, Sendable, Equatable {
    case zip, cbz, rar, cbr, pdf, folder
}

public struct ReadingProgress: Equatable, Sendable {
    public let comicId: UUID
    public let lastPageIndex: Int
    public let totalPages: Int
    public let updatedAt: Date
}

public struct Bookmark: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let comicId: UUID
    public let pageIndex: Int
    public let note: String?
    public let createdAt: Date
}

public enum ReadingMode: Equatable, Sendable {
    case single
    case dual
    case scroll(direction: ScrollDirection)
}

public enum ScrollDirection: String, Sendable { case ltr, rtl, ttb }
```

## 6. Domain Protocols

```swift
// Mana/Domain/Repositories

public protocol ArchiveReader: Sendable {
    func openArchive(at url: URL) async throws -> ArchiveHandle
    func pageCount(_ handle: ArchiveHandle) -> Int
    func pageData(_ handle: ArchiveHandle, index: Int) async throws -> Data
    func closeArchive(_ handle: ArchiveHandle) async
}

public protocol ArchiveReaderRouter: Sendable {
    /// Picks the right ArchiveReader for a file's format.
    func reader(for format: ComicFormat) -> ArchiveReader
}

public protocol ComicRepository: Sendable {
    func all() async -> [ComicItem]
    func upsert(_ item: ComicItem) async throws
    func delete(_ id: UUID) async throws
}

public protocol ProgressRepository: Sendable {
    func load(comicId: UUID) async -> ReadingProgress?
    func save(_ progress: ReadingProgress) async throws
}

public protocol BookmarkRepository: Sendable {
    func bookmarks(comicId: UUID) async -> [Bookmark]
    func add(_ bookmark: Bookmark) async throws
    func remove(id: UUID) async throws
}

public protocol FileSyncService: Sendable {
    /// True if user enabled iCloud sync and the container is reachable.
    var isAvailable: Bool { get async }

    /// Move a local imported file into the ubiquity container.
    func ingest(localURL: URL) async throws -> URL

    /// Trigger download of an ubiquity item not yet local.
    func ensureLocal(url: URL) async throws

    /// Stream of changes (additions/removals) in ubiquity container.
    func observeChanges() -> AsyncStream<FileSyncEvent>
}

public protocol ThumbnailProvider: Sendable {
    func thumbnail(for comicId: UUID, page: Int, maxDim: CGFloat) async throws -> Data
}
```

`ArchiveHandle` is an opaque `Sendable` token (likely an actor reference) that owns the underlying file descriptor / `Archive` / `URLArchive` and ensures thread-safe random page access.

## 7. TCA Reducer Tree

```
AppFeature
├── path: NavigationStack
│   ├── library         → LibraryFeature
│   ├── reader(comic)   → ReaderFeature
│   ├── bookmarks       → BookmarksFeature
│   └── settings        → SettingsFeature
└── tab: TabBarState (iPhone) / Sidebar (iPad)
```

### LibraryFeature

```swift
@Reducer
public struct LibraryFeature {
    @ObservableState
    public struct State: Equatable {
        var comics: IdentifiedArrayOf<ComicItem> = []
        var sort: SortOrder = .dateAddedDesc
        var filter: LibraryFilter = .all
        var isImporting = false
        var syncStatus: SyncStatus = .idle
    }

    public enum Action {
        case task                       // load + observe
        case refreshed([ComicItem])
        case sortChanged(SortOrder)
        case filterChanged(LibraryFilter)
        case importTapped
        case importPicked([URL])        // from Files app
        case comicTapped(ComicItem)
        case syncEvent(FileSyncEvent)
        case delete(IndexSet)
    }

    @Dependency(\.comicRepository) var repo
    @Dependency(\.fileSyncService) var sync
    @Dependency(\.archiveReaderRouter) var router
}
```

### ReaderFeature

```swift
@Reducer
public struct ReaderFeature {
    @ObservableState
    public struct State: Equatable {
        let comic: ComicItem
        var handle: ArchiveHandle?
        var pageIndex: Int = 0
        var pageCount: Int = 0
        var mode: ReadingMode = .scroll(direction: .rtl)
        var isControlsVisible: Bool = false
        var bookmarks: [Bookmark] = []
        var loadedIndices: Set<Int> = []   // which pages currently in ImageCache
    }

    public enum Action {
        case task
        case opened(ArchiveHandle, pageCount: Int, lastPage: Int)
        case pageChanged(Int)
        case pageLoaded(index: Int)        // notification only; bytes live in ImageCache
        case modeChanged(ReadingMode)
        case toggleControls
        case bookmarkToggled
        case persistProgress               // debounced
        case onDisappear
    }

    @Dependency(\.archiveReaderRouter) var router
    @Dependency(\.progressRepository) var progress
    @Dependency(\.bookmarkRepository) var bookmarks
    @Dependency(\.fileSyncService) var sync
}
```

### Page rendering — strategy via subviews, not reducers

`ReaderFeature` chooses a `PageRenderer` view based on `state.mode`. Each renderer pulls page bytes from `ImageCache` directly (no raw `Data` in TCA state). The reducer drives prefetch decisions; the view consumes the cache.

```swift
protocol PageRenderer: View {
    init(
        totalPages: Int,
        current: Binding<Int>,
        cache: ImageCache,           // injected actor
        onPrefetchHint: (Int) -> Void
    )
}

struct SinglePageRenderer: View, PageRenderer { ... }
struct DualPageRenderer: View, PageRenderer { ... }
struct ScrollPageRenderer: View, PageRenderer { ... }
```

`onPrefetchHint(index)` lets the view tell the reducer which pages it would like loaded next, so prefetch policy stays in the reducer (and is unit-testable).

## 8. Data Flow Examples

### Opening a comic

1. `LibraryFeature` user taps comic → `comicTapped(item)` → emits `app.path.append(.reader(item))`
2. `ReaderFeature.task`:
   1. `sync.ensureLocal(url: comic.url)` — block on download if needed (with progress UI)
   2. `router.reader(for: comic.format).openArchive(at:)` → `handle`
   3. `progress.load(comicId:)` → resume page (or 0)
   4. emits `.opened(handle, pageCount, lastPage)`
3. `ReaderFeature` prefetches `pageData` for indices `[lastPage-1, lastPage, lastPage+1]`
4. As user scrolls/swipes, prefetch window slides; old pages evicted by `ImageCache`

### Saving progress (debounced)

`pageChanged(Int)` cancels previous `.persistProgress` effect with `.debounce(seconds: 1, queue: .main)` then `progress.save(...)`. SwiftData mutation triggers CloudKit push automatically.

### File ingestion

User picks file from Files → `importPicked([URL])` → for each:
1. `sync.ingest(localURL:)` moves file into ubiquity container's `Documents/`
2. Spawn `ArchiveReader` to read first page → generate cover thumbnail
3. `repo.upsert(ComicItem)` → SwiftData save → CloudKit push
4. New `ComicItem` row appears via `task` observation

### Cross-device pickup

Other device sees new SwiftData record via CloudKit push notification. `ComicItem.url` is ubiquity-relative; file may not yet be downloaded. UI shows it dimmed with cloud icon. Tap → `ensureLocal` → downloads → reader opens.

## 9. Sync Architecture (detailed)

| What | Where | How |
|---|---|---|
| Comic metadata, progress, bookmarks | SwiftData store with `.cloudKitDatabase(.private)` | Auto-sync; conflict = last-writer-wins on `updatedAt` |
| Archive files | `iCloud.com.example.mana` ubiquity container, `Documents/` | OS-managed; lazy download via `startDownloadingUbiquitousItem` |
| Cover thumbnails | SwiftData `Data` field (small, <100KB) | Goes with metadata sync |
| Disk cache (page bitmaps) | App sandbox `Caches/` | Local only, never synced |

User can disable iCloud sync in Settings → app continues with local-only store.

### Conflict handling

- Progress: last `updatedAt` wins. No merge — pages don't merge meaningfully.
- Bookmarks: union by `id`. Remote `delete` wins over local edit (CloudKit default).
- Files: ubiquity container handles atomically; if same filename on both devices simultaneously, CloudKit appends ` 2` suffix (system default).

## 10. Liquid Glass Design System

Module: `DesignSystem/`. Components:

- `GlassToolbar` — top/bottom reader controls, uses `.glassEffect()` and `GlassEffectContainer { ... }` for grouped morphing
- `GlassPageIndicator` — floating "12 / 240" pill
- `GlassThumbnailStrip` — bottom scrubber in reader
- `LibraryCard` — comic cover with glass-tinted overlay for title
- `PrimaryButton` — `.glassEffect(.tinted)`

Color tokens in Asset Catalog with light/dark variants:
- `BackgroundPrimary`, `BackgroundSecondary`, `Accent`, `OnGlassPrimary`, `OnGlassSecondary`

Typography: SF Pro via Dynamic Type. Reader respects user's preferred content size for UI chrome (page content unaffected).

Dark mode is a free benefit of iOS 26 — Liquid Glass automatically adapts.

## 11. Image Caching

`ImageCacheKit`:

```swift
public actor ImageCache {
    public func data(for key: PageKey) -> Data?
    public func store(_ data: Data, for key: PageKey)
}

struct PageKey: Hashable, Sendable {
    let comicId: UUID
    let pageIndex: Int
}
```

- Memory: `NSCache` capped at ~50 page bitmaps
- Disk: LRU directory in `Caches/`, 200 MB cap, evicts oldest on overflow
- Decoded images NOT cached (only original JPEG/PNG bytes); decoding is per-display

Reader prefetches `current-1, current, current+1, current+2` pages async on background queue; cancels stale prefetches when user jumps.

## 12. Error Handling

```swift
public enum ArchiveError: Error, Equatable {
    case unsupportedFormat(String)
    case corrupted
    case encrypted
    case ioFailure(underlying: String)
}

public enum SyncError: Error, Equatable {
    case iCloudUnavailable
    case quotaExceeded
    case downloadFailed(reason: String)
}
```

- TCA `Effect.run` `catch:` paths surface errors as actions → reducer maps to `state.alert`
- libarchive (UnrarKit) calls run on `DispatchQueue` actor to isolate any unsafe behavior
- Ubiquity download stalls (>30s) show retry UI

## 13. Testing Strategy

| Layer | Approach |
|---|---|
| Domain | Pure value-type tests; trivial |
| Data/ArchiveKit | Integration tests with fixture `.cbz`, `.cbr`, `.pdf` files in test bundle |
| Data/PersistenceKit | In-memory SwiftData container; CRUD round-trips |
| Data/CloudSyncKit | Mock `NSMetadataQuery` results; integration test gated by env flag (real iCloud) |
| Features | TCA `TestStore` for every reducer; mock all `@Dependency` |
| DesignSystem | SwiftUI Previews; optional snapshot tests |
| SharedUI | XCUITest for reader gestures/zoom |

Coverage target: Domain + Features ≥ 90%, Data ≥ 70%.

## 14. Tuist Module Templates

Each module has identical layout; defined via helper:

```swift
// Tuist/ProjectDescriptionHelpers/Module.swift
public enum Module {
    case feature(String)
    case domain(String)
    case data(String)
    case ui(String)

    public func project() -> Project { ... }
}
```

Common per-module folders: `Sources/`, `Tests/`, `Resources/`, `Project.swift`.

External packages declared once in `Tuist/Package.swift` and referenced from modules that need them.

## 15. Open Items / Decisions Deferred

- App icon, branding, Korean localization — deferred until UI scaffolding done
- Bundle identifier and iCloud container name — placeholder `com.example.mana`; real ID set when developer account picked
- UnrarKit licensing review (LGPL dynamic-link compliance documentation) — required before App Store submission, not for MVP build
- Settings screen content beyond theme + reading defaults — designed in V2 phase
- Migration path if SwiftData schema changes post-launch — handle via SwiftData lightweight migrations; documented per change

## 16. Acceptance Criteria

MVP is "done" when, on a clean iPad running iOS 26:

1. User imports a `.cbz`, `.cbr`, `.pdf` file from Files app → appears in library
2. Tapping a comic opens the reader at last-read page
3. User can switch among single / dual / scroll-RTL modes; setting persists per-comic
4. Bookmarks can be added and listed; tapping jumps to the page
5. Killing the app and relaunching restores library + reading state
6. Signing into a second iPad with the same Apple ID:
   - Library populates within 30s
   - Comics show download indicators until `ensureLocal` runs
   - Reading progress matches the first device after both have synced
7. UI uses Liquid Glass throughout — toolbars, controls, indicators have `glassEffect`
8. App passes `xcodebuild test` on all module test schemes

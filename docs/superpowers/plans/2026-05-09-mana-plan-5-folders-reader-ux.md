# Mana — Plan 5: Folders + Drag Import + Reader UX + Settings + Localization

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 1-depth folders, drag-drop import from Files (iPad Split View), full-screen reader with tap-zone/swipe/long-press gestures, page-progression direction (LTR/RTL), and Settings expansion (gesture toggles, app language en/ko/ja) on top of the V2 baseline.

**Architecture:** Pure additions to existing modules. Domain gains `Folder` and `PageProgressionDirection`; PersistenceKit grows `FolderEntity` + `FolderRepositoryLive`; LibraryFeature gains folder navigation + drag-drop receiver; ReaderFeature gains a tap-zone+long-press gesture model and auto-hide overlay; SettingsFeature picks up 5 new fields; localization is added per-module via `Resources/<lang>.lproj/Localizable.strings`.

**Tech Stack:** Same as Plan 4 — SwiftUI, TCA 1.25.x, SwiftData (CloudKit-compatible), Tuist 4.155.x, iOS 26.4 SDK with Liquid Glass, Swift 6 strict concurrency. New: `UIViewControllerRepresentable` (`SwipeBackBlocker`), SwiftUI `.dropDestination(for: URL.self, ...)`, SwiftUI `.statusBarHidden`, `LocalizedStringKey`.

---

## File Structure (added/modified)

```
Mana/
├── Domain/
│   └── Sources/
│       ├── Models/
│       │   ├── Folder.swift                                    [+]
│       │   ├── PageProgressionDirection.swift                  [+]
│       │   └── ComicItem.swift                                 [M] +folderId, +pageProgressionDirection
│       └── Repositories/FolderRepository.swift                 [+]
├── Data/PersistenceKit/
│   ├── Sources/
│   │   ├── SwiftDataModels.swift                               [M] +FolderEntity, ComicEntity fields
│   │   ├── SwiftDataStack.swift                                [M] register FolderEntity
│   │   ├── ComicRepositoryLive.swift                           [M] round-trip new fields
│   │   └── FolderRepositoryLive.swift                          [+]
│   └── Tests/
│       ├── ComicRepositoryLiveTests.swift                      [M] new field round-trip
│       └── FolderRepositoryLiveTests.swift                     [+]
├── SharedUI/
│   └── Sources/SwipeBackBlocker.swift                          [+]
├── Features/
│   ├── LibraryFeature/
│   │   ├── Project.swift                                       [M] hasResources: true
│   │   ├── Sources/
│   │   │   ├── LibraryFeature.swift                            [M] folder state/actions
│   │   │   ├── LibraryView.swift                               [M] folder grid, dropDestination
│   │   │   ├── LibraryRow.swift                                [M] long-press menu
│   │   │   ├── FolderCard.swift                                [+]
│   │   │   ├── FolderThumbnail.swift                           [+]
│   │   │   ├── NewFolderSheet.swift                            [+]
│   │   │   └── MoveToFolderSheet.swift                         [+]
│   │   ├── Resources/{en,ko,ja}.lproj/Localizable.strings      [+]
│   │   └── Tests/LibraryFeatureTests.swift                     [M] folder + drop tests
│   ├── ReaderFeature/
│   │   ├── Project.swift                                       [M] hasResources: true
│   │   ├── Sources/
│   │   │   ├── ReaderFeature.swift                             [M] gestures + auto-hide
│   │   │   ├── ReaderView.swift                                [M] full-screen + overlays
│   │   │   ├── PageRenderer.swift                              [M] add tapZone params
│   │   │   ├── SinglePageRenderer.swift                        [M] tap zones
│   │   │   ├── DualPageRenderer.swift                          [M] tap zones
│   │   │   └── TapZoneOverlay.swift                            [+]
│   │   ├── Resources/{en,ko,ja}.lproj/Localizable.strings      [+]
│   │   └── Tests/ReaderFeatureTests.swift                      [M] tap zone + auto-hide tests
│   ├── BookmarksFeature/
│   │   ├── Project.swift                                       [M] hasResources: true
│   │   ├── Sources/{BookmarksView,BookmarkSheet}.swift         [M] use LocalizedStringKey
│   │   └── Resources/{en,ko,ja}.lproj/Localizable.strings      [+]
│   └── SettingsFeature/
│       ├── Project.swift                                       [M] hasResources: true
│       ├── Sources/
│       │   ├── SettingsFeature.swift                           [M] +5 settings, AppLanguage enum
│       │   └── SettingsView.swift                              [M] new sections
│       ├── Resources/{en,ko,ja}.lproj/Localizable.strings      [+]
│       └── Tests/SettingsFeatureTests.swift                    [M] new settings tests
├── App/
│   ├── Project.swift                                           [M] options.defaultKnownRegions
│   ├── Sources/LibraryImporterLive.swift                       [M] folderId param
│   └── Tests/IntegrationFlowTests.swift                        [M] import-into-folder
└── Workspace.swift                                              (unchanged)
```

10 tasks total. Library-side tasks (1–4) and Reader-side tasks (5–7) can interleave; Settings (8) depends on the new types from Task 1; Localization (9) depends on Tasks 1–8 to know which strings to extract; final integration (10) requires everything else.

---

## Conventions (continued from Plan 4)

- **Module helper API**: `Module(name:, kind:, dependencies:, externalDependencies: [String] = [], hasResources: Bool = false, hasTests: Bool = false)`
- **Test runner**: `xcodebuild test -workspace Mana.xcworkspace -scheme <Module> CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)'`
- **Workspace regen**: `./Scripts/setup.sh`
- **Test patterns**: `@MainActor @Suite struct`, TestStore with `withDependencies:`, `store.exhaustivity = .off(showSkippedAssertions: false)` when reducers emit cascading effects
- **TCA dependency capture**: Capture `@Dependency` values into local lets BEFORE `.run` closures (Plan 4 strict-concurrency lesson)
- **CloudKit-compatible @Model**: No `.unique`; every property optional or has a default value
- **Commit prefixes**: `feat(<module>):`, `test(<module>):`, `refactor(<module>):`, `chore(<module>):`, `i18n(<module>):`

---

## Task 1: Domain — Folder + PageProgressionDirection + ComicItem fields

**Files:**
- Create: `Domain/Sources/Models/Folder.swift`
- Create: `Domain/Sources/Models/PageProgressionDirection.swift`
- Create: `Domain/Sources/Repositories/FolderRepository.swift`
- Modify: `Domain/Sources/Models/ComicItem.swift`
- Test: `Domain/Tests/FolderTests.swift`

- [ ] **Step 1: Write failing tests `Domain/Tests/FolderTests.swift`**

```swift
import Testing
import Foundation
@testable import Domain

@Test func folderEquatableByValue() {
    let id = UUID()
    let date = Date(timeIntervalSince1970: 0)
    #expect(Folder(id: id, name: "Manga", dateAdded: date) == Folder(id: id, name: "Manga", dateAdded: date))
}

@Test func pageDirectionRawValues() {
    #expect(PageProgressionDirection.leftToRight.rawValue == "leftToRight")
    #expect(PageProgressionDirection.rightToLeft.rawValue == "rightToLeft")
}

@Test func comicItemPreservesNewFields() {
    let folderId = UUID()
    let item = ComicItem(
        id: UUID(),
        url: URL(fileURLWithPath: "/tmp/x.cbz"),
        format: .cbz,
        title: "X",
        pageCount: 1,
        coverThumbnail: nil,
        dateAdded: .init(timeIntervalSince1970: 0),
        fileSizeBytes: 0,
        readingMode: nil,
        urlBookmarkData: nil,
        folderId: folderId,
        pageProgressionDirection: .rightToLeft
    )
    #expect(item.folderId == folderId)
    #expect(item.pageProgressionDirection == .rightToLeft)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./Scripts/setup.sh && xcodebuild test -workspace Mana.xcworkspace -scheme Domain CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10`
Expected: compile failure ("cannot find 'Folder'" / "cannot find 'PageProgressionDirection'" / extra args in `ComicItem.init`).

- [ ] **Step 3: Write `Domain/Sources/Models/Folder.swift`**

```swift
import Foundation

public struct Folder: Identifiable, Equatable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let dateAdded: Date

    public init(id: UUID, name: String, dateAdded: Date) {
        self.id = id
        self.name = name
        self.dateAdded = dateAdded
    }
}
```

- [ ] **Step 4: Write `Domain/Sources/Models/PageProgressionDirection.swift`**

```swift
import Foundation

public enum PageProgressionDirection: String, Sendable, Equatable, Hashable, CaseIterable {
    case leftToRight
    case rightToLeft
}
```

- [ ] **Step 5: Write `Domain/Sources/Repositories/FolderRepository.swift`**

```swift
import Foundation

public protocol FolderRepository: Sendable {
    func all() async -> [Folder]
    func upsert(_ folder: Folder) async throws
    func delete(_ id: UUID) async throws
}
```

- [ ] **Step 6: Modify `Domain/Sources/Models/ComicItem.swift`**

Append two fields and update the initializer:

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
    public let readingMode: ReadingMode?
    public let urlBookmarkData: Data?
    public let folderId: UUID?
    public let pageProgressionDirection: PageProgressionDirection?

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
        urlBookmarkData: Data? = nil,
        folderId: UUID? = nil,
        pageProgressionDirection: PageProgressionDirection? = nil
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
        self.folderId = folderId
        self.pageProgressionDirection = pageProgressionDirection
    }
}
```

- [ ] **Step 7: Run tests**

Run: `xcodebuild test -workspace Mana.xcworkspace -scheme Domain CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10`
Expected: PASS — all three new tests + existing Domain tests.

- [ ] **Step 8: Commit**

```bash
git add Domain/
git commit -m "feat(domain): Folder, PageProgressionDirection, ComicItem.folderId/pageProgressionDirection"
```

---

## Task 2: PersistenceKit — FolderEntity, FolderRepositoryLive, ComicEntity round-trip

**Files:**
- Modify: `Data/PersistenceKit/Sources/SwiftDataModels.swift`
- Modify: `Data/PersistenceKit/Sources/SwiftDataStack.swift`
- Modify: `Data/PersistenceKit/Sources/ComicRepositoryLive.swift`
- Create: `Data/PersistenceKit/Sources/FolderRepositoryLive.swift`
- Modify: `Data/PersistenceKit/Tests/ComicRepositoryLiveTests.swift`
- Create: `Data/PersistenceKit/Tests/FolderRepositoryLiveTests.swift`

- [ ] **Step 1: Write failing test `Data/PersistenceKit/Tests/FolderRepositoryLiveTests.swift`**

```swift
import Testing
import Foundation
@testable import PersistenceKit
import Domain

@Suite struct FolderRepositoryLiveTests {

    @Test func upsertAndAll() async throws {
        let stack = try SwiftDataStack.inMemory()
        let repo = FolderRepositoryLive(stack: stack)
        let folder = Folder(id: UUID(), name: "Manga", dateAdded: Date(timeIntervalSince1970: 0))
        try await repo.upsert(folder)
        let all = await repo.all()
        #expect(all.count == 1)
        #expect(all.first?.name == "Manga")
    }

    @Test func upsertOverwritesById() async throws {
        let stack = try SwiftDataStack.inMemory()
        let repo = FolderRepositoryLive(stack: stack)
        let id = UUID()
        try await repo.upsert(Folder(id: id, name: "A", dateAdded: .init(timeIntervalSince1970: 0)))
        try await repo.upsert(Folder(id: id, name: "B", dateAdded: .init(timeIntervalSince1970: 0)))
        let all = await repo.all()
        #expect(all.count == 1)
        #expect(all.first?.name == "B")
    }

    @Test func deleteById() async throws {
        let stack = try SwiftDataStack.inMemory()
        let repo = FolderRepositoryLive(stack: stack)
        let folder = Folder(id: UUID(), name: "X", dateAdded: .init(timeIntervalSince1970: 0))
        try await repo.upsert(folder)
        try await repo.delete(folder.id)
        let all = await repo.all()
        #expect(all.isEmpty)
    }
}
```

- [ ] **Step 2: Add new test in `Data/PersistenceKit/Tests/ComicRepositoryLiveTests.swift`**

Append to the existing file:

```swift
@Test func roundTripsFolderIdAndDirection() async throws {
    let stack = try makeStack()
    let repo = ComicRepositoryLive(stack: stack)
    let folderId = UUID()
    let item = ComicItem(
        id: UUID(),
        url: URL(fileURLWithPath: "/tmp/m.cbz"),
        format: .cbz,
        title: "M",
        pageCount: 1,
        coverThumbnail: nil,
        dateAdded: .init(timeIntervalSince1970: 0),
        fileSizeBytes: 0,
        readingMode: nil,
        urlBookmarkData: nil,
        folderId: folderId,
        pageProgressionDirection: .rightToLeft
    )
    try await repo.upsert(item)
    let loaded = await repo.all()
    #expect(loaded.first?.folderId == folderId)
    #expect(loaded.first?.pageProgressionDirection == .rightToLeft)
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `./Scripts/setup.sh && xcodebuild test -workspace Mana.xcworkspace -scheme PersistenceKit CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10`
Expected: compile failure (`FolderRepositoryLive`, `FolderEntity`, ComicItem extra args).

- [ ] **Step 4: Modify `Data/PersistenceKit/Sources/SwiftDataModels.swift`**

Add the `FolderEntity` and the two new `ComicEntity` fields:

```swift
import Foundation
import SwiftData
import Domain

@Model
public final class ComicEntity {
    public var id: UUID = UUID()
    public var urlString: String = ""
    public var formatRaw: String = ""
    public var title: String = ""
    public var pageCount: Int?
    public var coverThumbnail: Data?
    public var dateAdded: Date = Date(timeIntervalSince1970: 0)
    public var fileSizeBytes: Int64 = 0
    public var readingModeRaw: String?
    public var urlBookmarkData: Data?
    public var folderId: UUID?
    public var pageProgressionDirectionRaw: String?

    public init(
        id: UUID,
        urlString: String,
        formatRaw: String,
        title: String,
        pageCount: Int?,
        coverThumbnail: Data?,
        dateAdded: Date,
        fileSizeBytes: Int64,
        readingModeRaw: String? = nil,
        urlBookmarkData: Data? = nil,
        folderId: UUID? = nil,
        pageProgressionDirectionRaw: String? = nil
    ) {
        self.id = id
        self.urlString = urlString
        self.formatRaw = formatRaw
        self.title = title
        self.pageCount = pageCount
        self.coverThumbnail = coverThumbnail
        self.dateAdded = dateAdded
        self.fileSizeBytes = fileSizeBytes
        self.readingModeRaw = readingModeRaw
        self.urlBookmarkData = urlBookmarkData
        self.folderId = folderId
        self.pageProgressionDirectionRaw = pageProgressionDirectionRaw
    }

    public func toModel() -> ComicItem {
        let mode = readingModeRaw.flatMap { ReadingMode(rawString: $0) }
        let direction = pageProgressionDirectionRaw.flatMap { PageProgressionDirection(rawValue: $0) }
        return ComicItem(
            id: id,
            url: URL(string: urlString) ?? URL(fileURLWithPath: urlString),
            format: ComicFormat(rawValue: formatRaw) ?? .zip,
            title: title,
            pageCount: pageCount,
            coverThumbnail: coverThumbnail,
            dateAdded: dateAdded,
            fileSizeBytes: fileSizeBytes,
            readingMode: mode,
            urlBookmarkData: urlBookmarkData,
            folderId: folderId,
            pageProgressionDirection: direction
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
            fileSizeBytes: item.fileSizeBytes,
            readingModeRaw: item.readingMode?.rawString,
            urlBookmarkData: item.urlBookmarkData,
            folderId: item.folderId,
            pageProgressionDirectionRaw: item.pageProgressionDirection?.rawValue
        )
    }
}

@Model
public final class FolderEntity {
    public var id: UUID = UUID()
    public var name: String = ""
    public var dateAdded: Date = Date(timeIntervalSince1970: 0)

    public init(id: UUID, name: String, dateAdded: Date) {
        self.id = id
        self.name = name
        self.dateAdded = dateAdded
    }

    public func toModel() -> Folder {
        Folder(id: id, name: name, dateAdded: dateAdded)
    }

    public static func from(_ folder: Folder) -> FolderEntity {
        FolderEntity(id: folder.id, name: folder.name, dateAdded: folder.dateAdded)
    }
}

@Model
public final class ReadingProgressEntity {
    public var comicId: UUID = UUID()
    public var lastPageIndex: Int = 0
    public var totalPages: Int = 0
    public var updatedAt: Date = Date(timeIntervalSince1970: 0)

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
    public var id: UUID = UUID()
    public var comicId: UUID = UUID()
    public var pageIndex: Int = 0
    public var note: String?
    public var createdAt: Date = Date(timeIntervalSince1970: 0)

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

- [ ] **Step 5: Modify `Data/PersistenceKit/Sources/SwiftDataStack.swift`**

Update both `inMemory()` and `onDisk(url:)` and `cloudKit(...)` to include `FolderEntity.self` in the model list:

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
            for: ComicEntity.self, ReadingProgressEntity.self, BookmarkEntity.self, FolderEntity.self,
            configurations: config
        )
        return SwiftDataStack(container: container)
    }

    public static func onDisk(url: URL) throws -> SwiftDataStack {
        let config = ModelConfiguration(url: url)
        let container = try ModelContainer(
            for: ComicEntity.self, ReadingProgressEntity.self, BookmarkEntity.self, FolderEntity.self,
            configurations: config
        )
        return SwiftDataStack(container: container)
    }

    public static func cloudKit(containerIdentifier: String) throws -> SwiftDataStack {
        let config = ModelConfiguration(cloudKitDatabase: .private(containerIdentifier))
        let container = try ModelContainer(
            for: ComicEntity.self, ReadingProgressEntity.self, BookmarkEntity.self, FolderEntity.self,
            configurations: config
        )
        return SwiftDataStack(container: container)
    }
}
```

- [ ] **Step 6: Modify `Data/PersistenceKit/Sources/ComicRepositoryLive.swift`**

Update the existing-record branch of `upsert(_:)` to round-trip the two new fields:

```swift
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
        existing.readingModeRaw = item.readingMode?.rawString
        existing.urlBookmarkData = item.urlBookmarkData
        existing.folderId = item.folderId
        existing.pageProgressionDirectionRaw = item.pageProgressionDirection?.rawValue
    } else {
        context.insert(ComicEntity.from(item))
    }
    try context.save()
}
```

(Other methods unchanged.)

- [ ] **Step 7: Write `Data/PersistenceKit/Sources/FolderRepositoryLive.swift`**

```swift
import Foundation
import SwiftData
import Domain

public actor FolderRepositoryLive: FolderRepository {
    private let stack: SwiftDataStack

    public init(stack: SwiftDataStack) {
        self.stack = stack
    }

    private func ctx() -> ModelContext { ModelContext(stack.container) }

    public func all() async -> [Folder] {
        let context = ctx()
        let descriptor = FetchDescriptor<FolderEntity>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).map { $0.toModel() }
    }

    public func upsert(_ folder: Folder) async throws {
        let context = ctx()
        let id = folder.id
        let descriptor = FetchDescriptor<FolderEntity>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.name = folder.name
            existing.dateAdded = folder.dateAdded
        } else {
            context.insert(FolderEntity.from(folder))
        }
        try context.save()
    }

    public func delete(_ id: UUID) async throws {
        let context = ctx()
        let descriptor = FetchDescriptor<FolderEntity>(predicate: #Predicate { $0.id == id })
        for entity in try context.fetch(descriptor) {
            context.delete(entity)
        }
        try context.save()
    }
}
```

- [ ] **Step 8: Run tests**

Run: `xcodebuild test -workspace Mana.xcworkspace -scheme PersistenceKit CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10`
Expected: 13/13 PASS (10 existing + 3 new folder tests). The new comic round-trip test counts as +1, so 11+3=14? Verify count after running.

- [ ] **Step 9: Commit**

```bash
git add Domain/ Data/PersistenceKit/
git commit -m "feat(persistence-kit): FolderEntity + FolderRepositoryLive + ComicEntity folderId/direction"
```

---

## Task 3: SharedUI — SwipeBackBlocker

**Files:**
- Create: `SharedUI/Sources/SwipeBackBlocker.swift`

(Plan 1 confirmed `SharedUI` has no Tests directory; this small UIKit bridge is exercised in manual smoke tests of the reader.)

- [ ] **Step 1: Write `SharedUI/Sources/SwipeBackBlocker.swift`**

```swift
import SwiftUI
import UIKit

/// Inserts a placeholder UIViewController whose only job is to disable the parent
/// navigation controller's interactivePopGestureRecognizer for the lifetime of this
/// view's appearance. Restored on disappear.
public struct SwipeBackBlocker: UIViewControllerRepresentable {
    public init() {}

    public func makeUIViewController(context: Context) -> Holder { Holder() }
    public func updateUIViewController(_: Holder, context: Context) {}

    public final class Holder: UIViewController {
        private var previousState: Bool?

        public override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            if let recognizer = navigationController?.interactivePopGestureRecognizer {
                previousState = recognizer.isEnabled
                recognizer.isEnabled = false
            }
        }

        public override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if let recognizer = navigationController?.interactivePopGestureRecognizer {
                recognizer.isEnabled = previousState ?? true
            }
        }
    }
}
```

- [ ] **Step 2: Build SharedUI**

Run: `./Scripts/setup.sh && xcodebuild build -workspace Mana.xcworkspace -scheme SharedUI CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add SharedUI/Sources/SwipeBackBlocker.swift
git commit -m "feat(shared-ui): SwipeBackBlocker UIViewControllerRepresentable"
```

---

## Task 4: LibraryFeature — folder state, navigation, create folder sheet

**Files:**
- Modify: `Features/LibraryFeature/Sources/LibraryFeature.swift`
- Modify: `Features/LibraryFeature/Sources/LibraryView.swift`
- Create: `Features/LibraryFeature/Sources/FolderCard.swift`
- Create: `Features/LibraryFeature/Sources/FolderThumbnail.swift`
- Create: `Features/LibraryFeature/Sources/NewFolderSheet.swift`
- Modify: `Features/LibraryFeature/Tests/LibraryFeatureTests.swift`

- [ ] **Step 1: Write failing tests in `Features/LibraryFeature/Tests/LibraryFeatureTests.swift`**

Append to the existing file:

```swift
@Test func displayedFoldersSortedByDateAddedDesc() {
    let oldId = UUID()
    let newId = UUID()
    let old = Folder(id: oldId, name: "Old", dateAdded: .init(timeIntervalSince1970: 0))
    let new = Folder(id: newId, name: "New", dateAdded: .init(timeIntervalSince1970: 100))
    let state = LibraryFeature.State(
        folders: IdentifiedArray(uniqueElements: [old, new])
    )
    #expect(state.displayedFolders.map(\.id) == [newId, oldId])
}

@Test func displayedComicsFilterByCurrentFolder() {
    let folderId = UUID()
    let inFolder = ComicItem(id: UUID(), url: URL(fileURLWithPath: "/in"), format: .cbz, title: "In", pageCount: 0, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0), fileSizeBytes: 0, folderId: folderId)
    let atRoot = ComicItem(id: UUID(), url: URL(fileURLWithPath: "/root"), format: .cbz, title: "Root", pageCount: 0, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0), fileSizeBytes: 0)
    let state = LibraryFeature.State(
        comics: IdentifiedArray(uniqueElements: [inFolder, atRoot]),
        currentFolderId: folderId
    )
    #expect(state.displayedComics.map(\.title) == ["In"])
}

@Test func newFolderSubmittedCreatesFolder() async {
    let folderRepo = StubFolderRepo()
    let fixedDate = Date(timeIntervalSince1970: 100)
    let fixedUUID = UUID()

    var initialState = LibraryFeature.State()
    initialState.newFolderSheet = LibraryFeature.NewFolderSheet.State(name: "Manga")

    let store = await TestStore(initialState: initialState) {
        LibraryFeature()
    } withDependencies: {
        $0.comicRepository = StubComicRepo(initial: [])
        $0.libraryImporter = StubImporter()
        $0.fileSyncService = UnavailableFileSync()
        $0.folderRepository = folderRepo
        $0.uuid = .constant(fixedUUID)
        $0.date.now = fixedDate
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.newFolderSubmitted) {
        $0.folders.append(Folder(id: fixedUUID, name: "Manga", dateAdded: fixedDate))
        $0.newFolderSheet = nil
    }
    try? await Task.sleep(nanoseconds: 50_000_000)
    let stored = await folderRepo.all()
    #expect(stored.first?.name == "Manga")
}

@Test func folderTappedSetsCurrentFolderId() async {
    let folder = Folder(id: UUID(), name: "F", dateAdded: .init(timeIntervalSince1970: 0))
    let store = await TestStore(initialState: LibraryFeature.State(
        folders: IdentifiedArray(uniqueElements: [folder])
    )) {
        LibraryFeature()
    } withDependencies: {
        $0.comicRepository = StubComicRepo(initial: [])
        $0.libraryImporter = StubImporter()
        $0.fileSyncService = UnavailableFileSync()
        $0.folderRepository = StubFolderRepo()
    }
    await store.send(.folderTapped(folder)) {
        $0.currentFolderId = folder.id
    }
}

actor StubFolderRepo: FolderRepository {
    private var items: [Folder] = []
    init() {}
    func all() async -> [Folder] { items }
    func upsert(_ f: Folder) async throws {
        if let i = items.firstIndex(where: { $0.id == f.id }) { items[i] = f }
        else { items.append(f) }
    }
    func delete(_ id: UUID) async throws { items.removeAll { $0.id == id } }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -workspace Mana.xcworkspace -scheme LibraryFeature CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10`
Expected: compile failure.

- [ ] **Step 3: Modify `Features/LibraryFeature/Sources/LibraryFeature.swift`**

Add folder state and actions, plus the `\.folderRepository` dependency key. Replace the file with:

```swift
import Foundation
import ComposableArchitecture
import Domain
import CloudSyncKit

public protocol LibraryImporter: Sendable {
    func importFiles(_ urls: [URL], folderId: UUID?) async throws -> [ComicItem]
}

@Reducer
public struct LibraryFeature {
    public init() {}

    public struct NewFolderSheet: Equatable, Sendable {
        public struct State: Equatable, Sendable {
            public var name: String

            public init(name: String = "") {
                self.name = name
            }
        }
    }

    @ObservableState
    public struct State: Equatable {
        public var comics: IdentifiedArrayOf<ComicItem> = []
        public var folders: IdentifiedArrayOf<Folder> = []
        public var currentFolderId: UUID?
        public var isImporting: Bool = false
        public var sort: LibrarySortOrder = .dateAddedDesc
        public var filter: LibraryFilter = .all
        public var newFolderSheet: NewFolderSheet.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(
            comics: IdentifiedArrayOf<ComicItem> = [],
            folders: IdentifiedArrayOf<Folder> = [],
            currentFolderId: UUID? = nil,
            isImporting: Bool = false,
            sort: LibrarySortOrder = .dateAddedDesc,
            filter: LibraryFilter = .all
        ) {
            self.comics = comics
            self.folders = folders
            self.currentFolderId = currentFolderId
            self.isImporting = isImporting
            self.sort = sort
            self.filter = filter
        }

        public var displayedFolders: [Folder] {
            // Folders are only shown at the root level (no nesting).
            currentFolderId == nil
                ? folders.elements.sorted { $0.dateAdded > $1.dateAdded }
                : []
        }

        public var displayedComics: [ComicItem] {
            let scoped = comics.filter { $0.folderId == currentFolderId }
            let filtered: [ComicItem] = scoped.filter { item in
                switch filter {
                case .all: return true
                case .zip: return item.format == .zip || item.format == .cbz
                case .rar: return item.format == .rar || item.format == .cbr
                case .pdf: return item.format == .pdf
                }
            }
            switch sort {
            case .dateAddedDesc: return filtered.sorted { $0.dateAdded > $1.dateAdded }
            case .dateAddedAsc: return filtered.sorted { $0.dateAdded < $1.dateAdded }
            case .titleAsc: return filtered.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            case .titleDesc: return filtered.sorted { $0.title.localizedStandardCompare($1.title) == .orderedDescending }
            case .fileSizeDesc: return filtered.sorted { $0.fileSizeBytes > $1.fileSizeBytes }
            }
        }

        public var currentFolder: Folder? {
            guard let id = currentFolderId else { return nil }
            return folders[id: id]
        }
    }

    public enum Action {
        case task
        case refreshed([ComicItem])
        case foldersRefreshed([Folder])
        case importTapped
        case importPicked([URL])
        case droppedURLs([URL])
        case imported([ComicItem])
        case importFailed(String)
        case comicTapped(ComicItem)
        case settingsTapped
        case delete(IndexSet)
        case sortChanged(LibrarySortOrder)
        case filterChanged(LibraryFilter)
        case folderTapped(Folder)
        case backToRoot
        case newFolderRequested
        case newFolderSheetDismissed
        case newFolderNameChanged(String)
        case newFolderSubmitted
        case folderCreated(Folder)
        case folderDeleteRequested(UUID)
        case folderDeleted(UUID)
        case comicMoveToFolderRequested(comicId: UUID, folderId: UUID?)
        case comicMoved(ComicItem)
        case fileSyncEvent(FileSyncEvent)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    @Dependency(\.comicRepository) var repo
    @Dependency(\.folderRepository) var folderRepo
    @Dependency(\.libraryImporter) var importer
    @Dependency(\.fileSyncService) var fileSync
    @Dependency(\.uuid) var uuid
    @Dependency(\.date.now) var now

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let repo = self.repo
                let folderRepo = self.folderRepo
                let fileSync = self.fileSync
                return .merge(
                    .run { send in
                        let items = await repo.all()
                        await send(.refreshed(items))
                    },
                    .run { send in
                        let folders = await folderRepo.all()
                        await send(.foldersRefreshed(folders))
                    },
                    .run { send in
                        for await event in fileSync.observeChanges() {
                            await send(.fileSyncEvent(event))
                        }
                    }
                )

            case let .refreshed(items):
                state.comics = IdentifiedArray(uniqueElements: items)
                return .none

            case let .foldersRefreshed(folders):
                state.folders = IdentifiedArray(uniqueElements: folders)
                return .none

            case .importTapped:
                return .none

            case let .importPicked(urls):
                state.isImporting = true
                let importer = self.importer
                let folderId = state.currentFolderId
                return .run { send in
                    do {
                        let imported = try await importer.importFiles(urls, folderId: folderId)
                        await send(.imported(imported))
                    } catch {
                        await send(.importFailed(error.localizedDescription))
                    }
                }

            case let .droppedURLs(urls):
                state.isImporting = true
                let importer = self.importer
                let folderId = state.currentFolderId
                return .run { send in
                    do {
                        let imported = try await importer.importFiles(urls, folderId: folderId)
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
                return .none

            case .settingsTapped:
                return .none

            case let .delete(indexSet):
                let displayed = state.displayedComics
                let ids = indexSet.map { displayed[$0].id }
                for id in ids { state.comics.remove(id: id) }
                let repo = self.repo
                return .run { _ in
                    for id in ids { try? await repo.delete(id) }
                }

            case let .sortChanged(s):
                state.sort = s
                return .none

            case let .filterChanged(f):
                state.filter = f
                return .none

            case let .folderTapped(folder):
                state.currentFolderId = folder.id
                return .none

            case .backToRoot:
                state.currentFolderId = nil
                return .none

            case .newFolderRequested:
                state.newFolderSheet = NewFolderSheet.State()
                return .none

            case .newFolderSheetDismissed:
                state.newFolderSheet = nil
                return .none

            case let .newFolderNameChanged(name):
                state.newFolderSheet?.name = name
                return .none

            case .newFolderSubmitted:
                guard let sheet = state.newFolderSheet, !sheet.name.isEmpty else { return .none }
                let folder = Folder(id: uuid(), name: sheet.name, dateAdded: now)
                state.folders.append(folder)
                state.newFolderSheet = nil
                let folderRepo = self.folderRepo
                return .run { send in
                    try? await folderRepo.upsert(folder)
                    await send(.folderCreated(folder))
                }

            case .folderCreated:
                return .none

            case let .folderDeleteRequested(id):
                state.folders.remove(id: id)
                // Comics that were in this folder fall back to root.
                for var comic in state.comics where comic.folderId == id {
                    let updated = ComicItem(
                        id: comic.id, url: comic.url, format: comic.format, title: comic.title,
                        pageCount: comic.pageCount, coverThumbnail: comic.coverThumbnail,
                        dateAdded: comic.dateAdded, fileSizeBytes: comic.fileSizeBytes,
                        readingMode: comic.readingMode, urlBookmarkData: comic.urlBookmarkData,
                        folderId: nil, pageProgressionDirection: comic.pageProgressionDirection
                    )
                    state.comics.updateOrAppend(updated)
                    _ = comic
                }
                if state.currentFolderId == id { state.currentFolderId = nil }
                let folderRepo = self.folderRepo
                let repo = self.repo
                let affectedIds = state.comics.filter { $0.folderId == nil }.map(\.id)
                return .run { send in
                    try? await folderRepo.delete(id)
                    // Persist the folder-clear on the orphaned comics.
                    let all = await repo.all()
                    for var item in all where affectedIds.contains(item.id) && item.folderId != nil {
                        item = ComicItem(
                            id: item.id, url: item.url, format: item.format, title: item.title,
                            pageCount: item.pageCount, coverThumbnail: item.coverThumbnail,
                            dateAdded: item.dateAdded, fileSizeBytes: item.fileSizeBytes,
                            readingMode: item.readingMode, urlBookmarkData: item.urlBookmarkData,
                            folderId: nil, pageProgressionDirection: item.pageProgressionDirection
                        )
                        try? await repo.upsert(item)
                    }
                    await send(.folderDeleted(id))
                }

            case .folderDeleted:
                return .none

            case let .comicMoveToFolderRequested(comicId, folderId):
                guard let existing = state.comics[id: comicId] else { return .none }
                let updated = ComicItem(
                    id: existing.id, url: existing.url, format: existing.format, title: existing.title,
                    pageCount: existing.pageCount, coverThumbnail: existing.coverThumbnail,
                    dateAdded: existing.dateAdded, fileSizeBytes: existing.fileSizeBytes,
                    readingMode: existing.readingMode, urlBookmarkData: existing.urlBookmarkData,
                    folderId: folderId, pageProgressionDirection: existing.pageProgressionDirection
                )
                state.comics.updateOrAppend(updated)
                let repo = self.repo
                return .run { send in
                    try? await repo.upsert(updated)
                    await send(.comicMoved(updated))
                }

            case .comicMoved:
                return .none

            case .fileSyncEvent:
                let repo = self.repo
                return .run { send in
                    let items = await repo.all()
                    await send(.refreshed(items))
                }

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

// Existing types kept (LibrarySortOrder, LibraryFilter, dependency keys)
public enum LibrarySortOrder: String, CaseIterable, Sendable, Equatable {
    case dateAddedDesc = "Recently added"
    case dateAddedAsc = "Oldest first"
    case titleAsc = "Title A→Z"
    case titleDesc = "Title Z→A"
    case fileSizeDesc = "Largest first"
}

public enum LibraryFilter: String, CaseIterable, Sendable, Equatable {
    case all = "All"
    case zip = "ZIP/CBZ"
    case rar = "RAR/CBR"
    case pdf = "PDF"
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

private enum FolderRepositoryKey: DependencyKey {
    static let liveValue: any FolderRepository = LiveFolderRepoPlaceholder()
}

private struct LiveFolderRepoPlaceholder: FolderRepository {
    func all() async -> [Folder] { [] }
    func upsert(_ folder: Folder) async throws {}
    func delete(_ id: UUID) async throws {}
}

private enum LibraryImporterKey: DependencyKey {
    static let liveValue: any LibraryImporter = LiveImporterPlaceholder()
}

private struct LiveImporterPlaceholder: LibraryImporter {
    func importFiles(_ urls: [URL], folderId: UUID?) async throws -> [ComicItem] { [] }
}

extension DependencyValues {
    public var comicRepository: any ComicRepository {
        get { self[ComicRepositoryKey.self] }
        set { self[ComicRepositoryKey.self] = newValue }
    }
    public var folderRepository: any FolderRepository {
        get { self[FolderRepositoryKey.self] }
        set { self[FolderRepositoryKey.self] = newValue }
    }
    public var libraryImporter: any LibraryImporter {
        get { self[LibraryImporterKey.self] }
        set { self[LibraryImporterKey.self] = newValue }
    }
}
```

Note: this changes `LibraryImporter.importFiles(_:)` to take `folderId:`. Existing tests use a stub — update them too.

- [ ] **Step 4: Update existing test stubs**

In `LibraryFeatureTests.swift`, find the `StubImporter` definition and update its `importFiles` to match the new signature:

```swift
struct StubImporter: LibraryImporter, @unchecked Sendable {
    var stubResult: [ComicItem] = []
    func importFiles(_ urls: [URL], folderId: UUID?) async throws -> [ComicItem] { stubResult }
}
```

Also update the existing `importPickedAddsItems` test if it asserts behavior — it should still pass since the stub ignores `folderId`.

- [ ] **Step 5: Write `Features/LibraryFeature/Sources/FolderThumbnail.swift`**

```swift
import SwiftUI
import Domain
import DesignSystem

public struct FolderThumbnail: View {
    let comicsInFolder: [ComicItem]

    public init(comicsInFolder: [ComicItem]) {
        self.comicsInFolder = comicsInFolder
    }

    public var body: some View {
        let covers = comicsInFolder.prefix(4)
        Group {
            switch covers.count {
            case 0:
                placeholder
            case 1:
                cover(covers[covers.startIndex])
            default:
                grid(Array(covers))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card))
    }

    @ViewBuilder
    private func cover(_ item: ComicItem) -> some View {
        if let data = item.coverThumbnail, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            placeholder
        }
    }

    @ViewBuilder
    private func grid(_ items: [ComicItem]) -> some View {
        let padded = items + Array(repeating: nil as ComicItem?, count: max(0, 4 - items.count))
        VStack(spacing: 1) {
            HStack(spacing: 1) {
                cell(padded[0])
                cell(padded[1])
            }
            HStack(spacing: 1) {
                cell(padded.count > 2 ? padded[2] : nil)
                cell(padded.count > 3 ? padded[3] : nil)
            }
        }
    }

    @ViewBuilder
    private func cell(_ item: ComicItem?) -> some View {
        if let item, let data = item.coverThumbnail, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill).clipped()
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Tokens.Colors.backgroundSecondary
    }
}
```

- [ ] **Step 6: Write `Features/LibraryFeature/Sources/FolderCard.swift`**

```swift
import SwiftUI
import Domain
import DesignSystem

public struct FolderCard: View {
    let folder: Folder
    let comicsInFolder: [ComicItem]
    var onTap: () -> Void
    var onDelete: () -> Void

    public init(
        folder: Folder,
        comicsInFolder: [ComicItem],
        onTap: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.folder = folder
        self.comicsInFolder = comicsInFolder
        self.onTap = onTap
        self.onDelete = onDelete
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                FolderThumbnail(comicsInFolder: comicsInFolder)
                    .frame(width: 96, height: 96)
                Text(folder.name)
                    .font(.caption)
                    .lineLimit(1)
                Text("\(comicsInFolder.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 96)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
```

- [ ] **Step 7: Write `Features/LibraryFeature/Sources/NewFolderSheet.swift`**

```swift
import SwiftUI

public struct NewFolderSheetView: View {
    @Binding var name: String
    var onSubmit: () -> Void
    var onCancel: () -> Void

    public init(name: Binding<String>, onSubmit: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self._name = name
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Folder Name") {
                    TextField("e.g. Manga", text: $name)
                }
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: onSubmit).disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
```

- [ ] **Step 8: Update `Features/LibraryFeature/Sources/LibraryView.swift`**

Replace the file body with one that adds folder display, breadcrumb, and the new-folder sheet:

```swift
import SwiftUI
import ComposableArchitecture
import Domain
import DesignSystem
import UniformTypeIdentifiers

public struct LibraryView: View {
    @Bindable public var store: StoreOf<LibraryFeature>
    @State private var showImporter = false

    public init(store: StoreOf<LibraryFeature>) {
        self.store = store
    }

    public var body: some View {
        List {
            if store.currentFolderId == nil, !store.displayedFolders.isEmpty {
                Section("Folders") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: Tokens.Spacing.m) {
                            ForEach(store.displayedFolders) { folder in
                                FolderCard(
                                    folder: folder,
                                    comicsInFolder: store.comics.filter { $0.folderId == folder.id },
                                    onTap: { store.send(.folderTapped(folder)) },
                                    onDelete: { store.send(.folderDeleteRequested(folder.id)) }
                                )
                            }
                        }
                        .padding(.vertical, Tokens.Spacing.s)
                    }
                }
            }

            if let folder = store.currentFolder {
                Section {
                    EmptyView()
                } header: {
                    HStack {
                        Button { store.send(.backToRoot) } label: {
                            Label("Library", systemImage: "chevron.left")
                        }
                        Text("/").foregroundStyle(.secondary)
                        Text(folder.name).fontWeight(.semibold)
                    }
                }
            }

            ForEach(store.displayedComics) { comic in
                Button {
                    store.send(.comicTapped(comic))
                } label: {
                    LibraryRow(comic: comic)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Menu {
                        Button("Move to Library Root") {
                            store.send(.comicMoveToFolderRequested(comicId: comic.id, folderId: nil))
                        }
                        ForEach(store.folders.elements) { folder in
                            Button(folder.name) {
                                store.send(.comicMoveToFolderRequested(comicId: comic.id, folderId: folder.id))
                            }
                        }
                    } label: {
                        Label("Move to…", systemImage: "folder")
                    }
                }
            }
            .onDelete { indexSet in store.send(.delete(indexSet)) }
        }
        .navigationTitle(store.currentFolder?.name ?? "Library")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { store.send(.settingsTapped) } label: { Image(systemName: "gearshape") }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { store.send(.newFolderRequested) } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                    Button { showImporter = true } label: {
                        Label("Import…", systemImage: "doc.badge.plus")
                    }
                    Picker("Sort", selection: Binding(
                        get: { store.sort },
                        set: { store.send(.sortChanged($0)) }
                    )) {
                        ForEach(LibrarySortOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Filter", selection: Binding(
                        get: { store.filter },
                        set: { store.send(.filterChanged($0)) }
                    )) {
                        ForEach(LibraryFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [
                UTType(filenameExtension: "cbz") ?? .archive,
                UTType(filenameExtension: "cbr") ?? .archive,
                .zip,
                .pdf
            ],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls): store.send(.importPicked(urls))
            case .failure: break
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            store.send(.droppedURLs(urls))
            return true
        }
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .overlay {
            if store.isImporting { ProgressView("Importing…") }
        }
        .sheet(
            isPresented: Binding(
                get: { store.newFolderSheet != nil },
                set: { if !$0 { store.send(.newFolderSheetDismissed) } }
            )
        ) {
            if let sheet = store.newFolderSheet {
                NewFolderSheetView(
                    name: Binding(
                        get: { sheet.name },
                        set: { store.send(.newFolderNameChanged($0)) }
                    ),
                    onSubmit: { store.send(.newFolderSubmitted) },
                    onCancel: { store.send(.newFolderSheetDismissed) }
                )
            }
        }
    }
}
```

- [ ] **Step 9: Run tests**

Run: `xcodebuild test -workspace Mana.xcworkspace -scheme LibraryFeature CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10`
Expected: 10/10 PASS (6 existing + 4 new). The existing `importPickedAddsItems` test continues to pass because the stub ignores `folderId`.

- [ ] **Step 10: Build full app**

Note: `LibraryImporterLive` in `App/` doesn't yet match the new signature. Build will fail; Task 10 fixes the App side. For now confirm the LibraryFeature module builds standalone:

```bash
xcodebuild build -workspace Mana.xcworkspace -scheme LibraryFeature CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 11: Commit**

```bash
git add Features/LibraryFeature/
git commit -m "feat(library-feature): folder navigation + new-folder sheet + move-to-folder"
```

---

## Task 5: ReaderFeature — page progression direction + tap zones + auto-hide

**Files:**
- Modify: `Features/ReaderFeature/Sources/ReaderFeature.swift`
- Modify: `Features/ReaderFeature/Sources/PageRenderer.swift`
- Modify: `Features/ReaderFeature/Sources/SinglePageRenderer.swift`
- Modify: `Features/ReaderFeature/Sources/DualPageRenderer.swift`
- Create: `Features/ReaderFeature/Sources/TapZoneOverlay.swift`
- Modify: `Features/ReaderFeature/Tests/ReaderFeatureTests.swift`

- [ ] **Step 1: Write failing tests in `Features/ReaderFeature/Tests/ReaderFeatureTests.swift`**

Append:

```swift
@Test func progressionDirectionLoadsFromComic() async {
    let comic = ComicItem(
        id: UUID(), url: URL(fileURLWithPath: "/tmp/x.cbz"), format: .cbz, title: "X",
        pageCount: 5, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0),
        fileSizeBytes: 0, readingMode: nil, urlBookmarkData: nil,
        folderId: nil, pageProgressionDirection: .rightToLeft
    )
    let stubReader = StubReader(handle: ArchiveHandle(), pages: [Data([0])])
    let store = await TestStore(initialState: ReaderFeature.State(comic: comic)) {
        ReaderFeature()
    } withDependencies: {
        $0.archiveReaderRouter = StubRouter(reader: stubReader)
        $0.progressRepository = InMemoryProgressRepo(initial: [])
        $0.imageCache = ImageCache.inMemoryOnly()
        $0.mainQueue = .immediate
        $0.comicRepository = StubComicRepoForReader(initial: [comic])
        $0.fileSyncService = UnavailableFileSync()
        $0.userDefaults = InMemoryUserDefaults()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.task)
    await store.receive(\.opened) {
        $0.handle = stubReader.handle
        $0.pageCount = 1
        $0.pageProgressionDirection = .rightToLeft
    }
}

@Test func progressionDirectionChangedPersists() async {
    let comic = ComicItem(
        id: UUID(), url: URL(fileURLWithPath: "/tmp/x.cbz"), format: .cbz, title: "X",
        pageCount: 5, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0),
        fileSizeBytes: 0
    )
    let repo = StubComicRepoForReader(initial: [comic])
    let store = await TestStore(initialState: ReaderFeature.State(comic: comic, pageCount: 5)) {
        ReaderFeature()
    } withDependencies: {
        $0.archiveReaderRouter = StubRouter(reader: StubReader(handle: ArchiveHandle(), pages: []))
        $0.progressRepository = InMemoryProgressRepo(initial: [])
        $0.imageCache = ImageCache.inMemoryOnly()
        $0.mainQueue = .immediate
        $0.comicRepository = repo
        $0.fileSyncService = UnavailableFileSync()
        $0.userDefaults = InMemoryUserDefaults()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.progressionDirectionChanged(.rightToLeft)) {
        $0.pageProgressionDirection = .rightToLeft
    }
    try? await Task.sleep(nanoseconds: 50_000_000)
    let stored = await repo.all()
    #expect(stored.first?.pageProgressionDirection == .rightToLeft)
}

@Test func toggleControlsSchedulesAutoHide() async {
    let comic = ComicItem(
        id: UUID(), url: URL(fileURLWithPath: "/tmp/x.cbz"), format: .cbz, title: "X",
        pageCount: 5, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0),
        fileSizeBytes: 0
    )
    let store = await TestStore(initialState: ReaderFeature.State(comic: comic, pageCount: 5)) {
        ReaderFeature()
    } withDependencies: {
        $0.archiveReaderRouter = StubRouter(reader: StubReader(handle: ArchiveHandle(), pages: []))
        $0.progressRepository = InMemoryProgressRepo(initial: [])
        $0.imageCache = ImageCache.inMemoryOnly()
        $0.mainQueue = .immediate
        $0.comicRepository = StubComicRepoForReader(initial: [comic])
        $0.fileSyncService = UnavailableFileSync()
        $0.userDefaults = InMemoryUserDefaults()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.toggleControls) {
        $0.isControlsVisible = true
    }
    // mainQueue == .immediate, so autoHideControls fires synchronously
    await store.receive(\.autoHideControls) {
        $0.isControlsVisible = false
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -workspace Mana.xcworkspace -scheme ReaderFeature CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10`
Expected: compile failure (`progressionDirectionChanged`, `autoHideControls`, `pageProgressionDirection`).

- [ ] **Step 3: Modify `Features/ReaderFeature/Sources/ReaderFeature.swift`**

Add gesture, direction, and auto-hide state + actions. Replace key sections; full state and reducer body looks like:

```swift
import Foundation
import ComposableArchitecture
import Domain
import ImageCacheKit
import LibraryFeature
import SettingsFeature
import CloudSyncKit

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
        public var pageProgressionDirection: PageProgressionDirection = .leftToRight
        public var isControlsVisible: Bool
        public var loadedIndices: Set<Int>
        public var securityScopedURL: URL?
        public var controlsAutoHideSeconds: Double = 3.0
        public var isSliderDragging: Bool = false
        @Presents public var alert: AlertState<Action.Alert>?

        public init(
            comic: ComicItem,
            handle: ArchiveHandle? = nil,
            pageIndex: Int = 0,
            pageCount: Int = 0,
            mode: ReadingMode = .single,
            isControlsVisible: Bool = false,
            loadedIndices: Set<Int> = [],
            securityScopedURL: URL? = nil
        ) {
            self.comic = comic
            self.handle = handle
            self.pageIndex = pageIndex
            self.pageCount = pageCount
            self.mode = mode
            self.isControlsVisible = isControlsVisible
            self.loadedIndices = loadedIndices
            self.securityScopedURL = securityScopedURL
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
        case autoHideControls
        case sliderDragStart
        case sliderDragEnd
        case persistProgress
        case modeChanged(ReadingMode)
        case progressionDirectionChanged(PageProgressionDirection)
        case bookmarksTapped(comicId: UUID)
        case startedSecurityScope(URL)
        case onDisappear
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    @Dependency(\.archiveReaderRouter) var router
    @Dependency(\.progressRepository) var progress
    @Dependency(\.imageCache) var imageCache
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.comicRepository) var comicRepo
    @Dependency(\.userDefaults) var userDefaults
    @Dependency(\.fileSyncService) var fileSync

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let comic = state.comic
                let router = self.router
                let progress = self.progress
                let fileSync = self.fileSync
                return .run { send in
                    do {
                        var url = comic.url
                        if !FileManager.default.fileExists(atPath: url.path),
                           let bookmark = comic.urlBookmarkData {
                            let (resolved, _) = try BookmarkURLResolver.resolve(bookmarkData: bookmark)
                            url = resolved
                        }
                        if await fileSync.isAvailable {
                            try? await fileSync.ensureLocal(url: url)
                        }
                        let didStart = url.startAccessingSecurityScopedResource()
                        do {
                            let reader = router.reader(for: comic.format)
                            let handle = try await reader.openArchive(at: url)
                            let pageCount = await reader.pageCount(handle)
                            let saved = await progress.load(comicId: comic.id)
                            let lastPage = saved.map { min(max(0, $0.lastPageIndex), max(0, pageCount - 1)) } ?? 0
                            await send(.opened(handle: handle, pageCount: pageCount, lastPage: lastPage))
                            await send(.prefetchHint(lastPage))
                            if didStart { await send(.startedSecurityScope(url)) }
                        } catch {
                            if didStart { url.stopAccessingSecurityScopedResource() }
                            throw error
                        }
                    } catch {
                        await send(.openFailed(error.localizedDescription))
                    }
                }

            case let .opened(handle, pageCount, lastPage):
                state.handle = handle
                state.pageCount = pageCount
                state.pageIndex = lastPage
                if let saved = state.comic.readingMode {
                    state.mode = saved
                } else if let raw = userDefaults.string(forKey: SettingsFeature.modeKey),
                          let mode = ReadingMode(rawString: raw) {
                    state.mode = mode
                }
                if let dir = state.comic.pageProgressionDirection {
                    state.pageProgressionDirection = dir
                } else if let raw = userDefaults.string(forKey: SettingsFeature.directionKey),
                          let dir = PageProgressionDirection(rawValue: raw) {
                    state.pageProgressionDirection = dir
                }
                let storedHide = userDefaults.double(forKey: SettingsFeature.autoHideKey)
                state.controlsAutoHideSeconds = storedHide == 0 ? 3.0 : storedHide
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
                let neighbors = ([index, index - 1, index + 1]).filter { $0 >= 0 && $0 < pageCount }
                let router = self.router
                let imageCache = self.imageCache
                return .run { send in
                    let reader = router.reader(for: format)
                    for i in neighbors {
                        let key = PageKey(comicId: comicId, pageIndex: i)
                        if await imageCache.data(for: key) != nil { continue }
                        do {
                            let data = try await reader.pageData(handle, index: i)
                            await imageCache.store(data, for: key)
                            await send(.pageLoaded(index: i))
                        } catch {}
                    }
                }

            case let .pageLoaded(index):
                state.loadedIndices.insert(index)
                return .none

            case .toggleControls:
                state.isControlsVisible.toggle()
                guard state.isControlsVisible, state.controlsAutoHideSeconds > 0 else { return .none }
                let seconds = state.controlsAutoHideSeconds
                let mainQueue = self.mainQueue
                return .run { send in
                    await send(.autoHideControls)
                }
                .debounce(id: AutoHideID(), for: .seconds(seconds), scheduler: mainQueue)

            case .autoHideControls:
                guard !state.isSliderDragging else { return .none }
                state.isControlsVisible = false
                return .none

            case .sliderDragStart:
                state.isSliderDragging = true
                return .cancel(id: AutoHideID())

            case .sliderDragEnd:
                state.isSliderDragging = false
                guard state.isControlsVisible, state.controlsAutoHideSeconds > 0 else { return .none }
                let seconds = state.controlsAutoHideSeconds
                let mainQueue = self.mainQueue
                return .run { send in
                    await send(.autoHideControls)
                }
                .debounce(id: AutoHideID(), for: .seconds(seconds), scheduler: mainQueue)

            case .persistProgress:
                let p = ReadingProgress(
                    comicId: state.comic.id,
                    lastPageIndex: state.pageIndex,
                    totalPages: state.pageCount,
                    updatedAt: Date()
                )
                let progress = self.progress
                return .run { _ in
                    try? await progress.save(p)
                }
                .debounce(id: PersistDebounce(), for: .seconds(1), scheduler: mainQueue)

            case let .modeChanged(mode):
                state.mode = mode
                let updated = ComicItem(
                    id: state.comic.id, url: state.comic.url, format: state.comic.format,
                    title: state.comic.title, pageCount: state.comic.pageCount,
                    coverThumbnail: state.comic.coverThumbnail, dateAdded: state.comic.dateAdded,
                    fileSizeBytes: state.comic.fileSizeBytes,
                    readingMode: mode, urlBookmarkData: state.comic.urlBookmarkData,
                    folderId: state.comic.folderId,
                    pageProgressionDirection: state.comic.pageProgressionDirection
                )
                state.comic = updated
                let comicRepo = self.comicRepo
                return .run { _ in try? await comicRepo.upsert(updated) }

            case let .progressionDirectionChanged(direction):
                state.pageProgressionDirection = direction
                let updated = ComicItem(
                    id: state.comic.id, url: state.comic.url, format: state.comic.format,
                    title: state.comic.title, pageCount: state.comic.pageCount,
                    coverThumbnail: state.comic.coverThumbnail, dateAdded: state.comic.dateAdded,
                    fileSizeBytes: state.comic.fileSizeBytes,
                    readingMode: state.comic.readingMode, urlBookmarkData: state.comic.urlBookmarkData,
                    folderId: state.comic.folderId,
                    pageProgressionDirection: direction
                )
                state.comic = updated
                let comicRepo = self.comicRepo
                return .run { _ in try? await comicRepo.upsert(updated) }

            case .bookmarksTapped:
                return .none

            case let .startedSecurityScope(url):
                state.securityScopedURL = url
                return .none

            case .onDisappear:
                let scopedURL = state.securityScopedURL
                state.securityScopedURL = nil
                let handle = state.handle
                state.handle = nil
                let format = state.comic.format
                let router = self.router
                return .run { _ in
                    if let handle {
                        let reader = router.reader(for: format)
                        await reader.closeArchive(handle)
                    }
                    if let scopedURL { scopedURL.stopAccessingSecurityScopedResource() }
                }

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private struct PersistDebounce: Hashable {}
    private struct AutoHideID: Hashable {}
}

// MARK: - Dependency Keys (continue from prior plans, unchanged)

private enum ArchiveReaderRouterKey: DependencyKey {
    static let liveValue: any ArchiveReaderRouter = LiveArchiveReaderRouterPlaceholder()
}

private struct LiveArchiveReaderRouterPlaceholder: ArchiveReaderRouter {
    func reader(for format: ComicFormat) -> any ArchiveReader {
        preconditionFailure("ArchiveReaderRouter not provided.")
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

- [ ] **Step 4: Modify `Features/ReaderFeature/Sources/PageRenderer.swift`**

Update the `PageRenderer` protocol to add tap-zone params:

```swift
import SwiftUI
import UIKit
import Domain

public protocol PageRenderer: View {
    init(
        totalPages: Int,
        current: Binding<Int>,
        pageImage: @escaping (Int) async -> UIImage?,
        onPrefetchHint: @escaping (Int) -> Void,
        progressionDirection: PageProgressionDirection,
        tapZonesEnabled: Bool,
        swipeEnabled: Bool
    )
}
```

- [ ] **Step 5: Write `Features/ReaderFeature/Sources/TapZoneOverlay.swift`**

```swift
import SwiftUI

/// Two transparent halves; tapping a half calls the corresponding handler.
public struct TapZoneOverlay: View {
    var onLeftTap: () -> Void
    var onRightTap: () -> Void

    public init(onLeftTap: @escaping () -> Void, onRightTap: @escaping () -> Void) {
        self.onLeftTap = onLeftTap
        self.onRightTap = onRightTap
    }

    public var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: geo.size.width / 2, height: geo.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 1, perform: onLeftTap)
                Color.clear
                    .frame(width: geo.size.width / 2, height: geo.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 1, perform: onRightTap)
            }
        }
    }
}
```

- [ ] **Step 6: Modify `Features/ReaderFeature/Sources/SinglePageRenderer.swift`**

```swift
import SwiftUI
import UIKit
import Domain
import SharedUI

public struct SinglePageRenderer: View, PageRenderer {
    let totalPages: Int
    @Binding var current: Int
    let pageImage: (Int) async -> UIImage?
    let onPrefetchHint: (Int) -> Void
    let progressionDirection: PageProgressionDirection
    let tapZonesEnabled: Bool
    let swipeEnabled: Bool

    @State private var image: UIImage?
    @State private var loadingIndex: Int?

    public init(
        totalPages: Int,
        current: Binding<Int>,
        pageImage: @escaping (Int) async -> UIImage?,
        onPrefetchHint: @escaping (Int) -> Void,
        progressionDirection: PageProgressionDirection = .leftToRight,
        tapZonesEnabled: Bool = true,
        swipeEnabled: Bool = true
    ) {
        self.totalPages = totalPages
        self._current = current
        self.pageImage = pageImage
        self.onPrefetchHint = onPrefetchHint
        self.progressionDirection = progressionDirection
        self.tapZonesEnabled = tapZonesEnabled
        self.swipeEnabled = swipeEnabled
    }

    public var body: some View {
        ZStack {
            if let image {
                ZoomableImageView(image: image)
            } else {
                ProgressView()
            }
            if tapZonesEnabled {
                TapZoneOverlay(
                    onLeftTap: { handleLeftTap() },
                    onRightTap: { handleRightTap() }
                )
            }
        }
        .gesture(swipeEnabled ? swipeGesture : nil)
        .task(id: current) {
            await load(current)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onEnded { value in
                if value.translation.width < -50 { handleRightTap() }
                else if value.translation.width > 50 { handleLeftTap() }
            }
    }

    private func handleLeftTap() {
        // LTR: left = previous; RTL: left = next
        let delta = (progressionDirection == .leftToRight) ? -1 : +1
        applyDelta(delta)
    }

    private func handleRightTap() {
        let delta = (progressionDirection == .leftToRight) ? +1 : -1
        applyDelta(delta)
    }

    private func applyDelta(_ delta: Int) {
        let target = current + delta
        guard target >= 0, target < totalPages else { return }
        current = target
    }

    private func load(_ index: Int) async {
        loadingIndex = index
        onPrefetchHint(index)
        for _ in 0..<30 {
            if let img = await pageImage(index) {
                if loadingIndex == index { image = img }
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}
```

- [ ] **Step 7: Modify `Features/ReaderFeature/Sources/DualPageRenderer.swift`**

Same shape, but `+= 2` on both directions and pair load:

```swift
import SwiftUI
import UIKit
import Domain
import SharedUI

public struct DualPageRenderer: View, PageRenderer {
    let totalPages: Int
    @Binding var current: Int
    let pageImage: (Int) async -> UIImage?
    let onPrefetchHint: (Int) -> Void
    let progressionDirection: PageProgressionDirection
    let tapZonesEnabled: Bool
    let swipeEnabled: Bool

    @State private var leftImage: UIImage?
    @State private var rightImage: UIImage?

    public init(
        totalPages: Int,
        current: Binding<Int>,
        pageImage: @escaping (Int) async -> UIImage?,
        onPrefetchHint: @escaping (Int) -> Void,
        progressionDirection: PageProgressionDirection = .leftToRight,
        tapZonesEnabled: Bool = true,
        swipeEnabled: Bool = true
    ) {
        self.totalPages = totalPages
        self._current = current
        self.pageImage = pageImage
        self.onPrefetchHint = onPrefetchHint
        self.progressionDirection = progressionDirection
        self.tapZonesEnabled = tapZonesEnabled
        self.swipeEnabled = swipeEnabled
    }

    public var body: some View {
        ZStack {
            HStack(spacing: 0) {
                pane(image: progressionDirection == .leftToRight ? leftImage : rightImage)
                pane(image: progressionDirection == .leftToRight ? rightImage : leftImage)
            }
            if tapZonesEnabled {
                TapZoneOverlay(
                    onLeftTap: { applyDelta((progressionDirection == .leftToRight) ? -2 : +2) },
                    onRightTap: { applyDelta((progressionDirection == .leftToRight) ? +2 : -2) }
                )
            }
        }
        .gesture(swipeEnabled ? swipeGesture : nil)
        .task(id: current) {
            await loadPair()
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onEnded { value in
                if value.translation.width < -50 {
                    applyDelta((progressionDirection == .leftToRight) ? +2 : -2)
                } else if value.translation.width > 50 {
                    applyDelta((progressionDirection == .leftToRight) ? -2 : +2)
                }
            }
    }

    private func applyDelta(_ delta: Int) {
        let target = current + delta
        guard target >= 0, target < totalPages else { return }
        current = target
    }

    @ViewBuilder
    private func pane(image: UIImage?) -> some View {
        if let image {
            ZoomableImageView(image: image)
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func loadPair() async {
        let left = current
        let right = current + 1
        onPrefetchHint(left)
        if right < totalPages { onPrefetchHint(right) }
        async let leftImg = wait(for: left)
        async let rightImg: UIImage? = right < totalPages ? wait(for: right) : nil
        let (l, r) = await (leftImg, rightImg)
        if current == left {
            leftImage = l
            rightImage = r
        }
    }

    private func wait(for index: Int) async -> UIImage? {
        for _ in 0..<30 {
            if let img = await pageImage(index) { return img }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return nil
    }
}
```

- [ ] **Step 8: Modify `Features/ReaderFeature/Sources/ScrollPageRenderer.swift`**

Add the new init params (ignore them in the body — scroll mode doesn't honor tap zones, and swipe is consumed by the scroll view). Replace the existing init signature; the rest of the view is unchanged:

```swift
import SwiftUI
import UIKit
import Domain
import SharedUI

public struct ScrollPageRenderer: View, PageRenderer {
    let totalPages: Int
    @Binding var current: Int
    let pageImage: (Int) async -> UIImage?
    let onPrefetchHint: (Int) -> Void
    let direction: ScrollDirection

    @State private var images: [Int: UIImage] = [:]

    public init(
        totalPages: Int,
        current: Binding<Int>,
        pageImage: @escaping (Int) async -> UIImage?,
        onPrefetchHint: @escaping (Int) -> Void,
        progressionDirection: PageProgressionDirection = .leftToRight,
        tapZonesEnabled: Bool = true,
        swipeEnabled: Bool = true
    ) {
        self.totalPages = totalPages
        self._current = current
        self.pageImage = pageImage
        self.onPrefetchHint = onPrefetchHint
        // Scroll renderer ignores tap zones / swipe; keep its existing TTB default.
        self.direction = .ttb
        _ = progressionDirection
        _ = tapZonesEnabled
        _ = swipeEnabled
    }

    public init(
        totalPages: Int,
        current: Binding<Int>,
        pageImage: @escaping (Int) async -> UIImage?,
        onPrefetchHint: @escaping (Int) -> Void,
        direction: ScrollDirection
    ) {
        self.totalPages = totalPages
        self._current = current
        self.pageImage = pageImage
        self.onPrefetchHint = onPrefetchHint
        self.direction = direction
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(scrollAxis) { content(proxy: proxy) }
                .environment(\.layoutDirection, layoutDirection)
        }
    }

    private var scrollAxis: Axis.Set {
        switch direction {
        case .ttb: return .vertical
        case .ltr, .rtl: return .horizontal
        }
    }

    private var layoutDirection: LayoutDirection {
        direction == .rtl ? .rightToLeft : .leftToRight
    }

    @ViewBuilder
    private func content(proxy: ScrollViewProxy) -> some View {
        if direction == .ttb {
            LazyVStack(spacing: 0) { pages }.onAppear { proxy.scrollTo(current, anchor: .top) }
        } else {
            LazyHStack(spacing: 0) { pages }.onAppear { proxy.scrollTo(current, anchor: .leading) }
        }
    }

    @ViewBuilder
    private var pages: some View {
        ForEach(0..<totalPages, id: \.self) { index in
            page(at: index).id(index).onAppear { current = index; onPrefetchHint(index) }
        }
    }

    @ViewBuilder
    private func page(at index: Int) -> some View {
        if let img = images[index] {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fit)
        } else {
            Color.black
                .frame(minWidth: 320, minHeight: 480)
                .overlay(ProgressView().tint(.white))
                .task(id: index) {
                    if let img = await pageImage(index) { images[index] = img }
                }
        }
    }
}
```

- [ ] **Step 9: Run tests**

Run: `xcodebuild test -workspace Mana.xcworkspace -scheme ReaderFeature CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10`
Expected: 7/7 PASS (4 existing + 3 new).

- [ ] **Step 10: Commit**

```bash
git add Features/ReaderFeature/
git commit -m "feat(reader-feature): tap zones, progression direction, auto-hide controls"
```

---

## Task 6: ReaderFeature — full-screen view + top/bottom overlays + long-press toggle

**Files:**
- Modify: `Features/ReaderFeature/Sources/ReaderView.swift`

- [ ] **Step 1: Replace `Features/ReaderFeature/Sources/ReaderView.swift`**

```swift
import SwiftUI
import ComposableArchitecture
import Domain
import ImageCacheKit
import DesignSystem
import SharedUI

public struct ReaderView: View {
    @Bindable public var store: StoreOf<ReaderFeature>
    @Dependency(\.imageCache) private var imageCache
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<ReaderFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if store.pageCount > 0 {
                renderer
                    .ignoresSafeArea()
            } else {
                ProgressView().tint(.white)
            }

            if store.isControlsVisible {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.isControlsVisible)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .background(SwipeBackBlocker())
        .task { await store.send(.task).finish() }
        .onLongPressGesture(minimumDuration: 0.4) {
            store.send(.toggleControls)
        }
        .onDisappear { store.send(.onDisappear) }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    @ViewBuilder
    private var renderer: some View {
        let comicId = store.comic.id
        let cache = imageCache
        let provider: (Int) async -> UIImage? = { idx in
            let key = PageKey(comicId: comicId, pageIndex: idx)
            guard let data = await cache.data(for: key) else { return nil }
            return UIImage(data: data)
        }
        let binding = Binding<Int>(
            get: { store.pageIndex },
            set: { store.send(.pageChanged($0)) }
        )
        let hint: (Int) -> Void = { idx in store.send(.prefetchHint(idx)) }
        let direction = store.pageProgressionDirection

        switch store.mode {
        case .single:
            SinglePageRenderer(
                totalPages: store.pageCount,
                current: binding,
                pageImage: provider,
                onPrefetchHint: hint,
                progressionDirection: direction,
                tapZonesEnabled: tapZonesEnabledFromDefaults,
                swipeEnabled: swipeEnabledFromDefaults
            )
        case .dual:
            DualPageRenderer(
                totalPages: store.pageCount,
                current: binding,
                pageImage: provider,
                onPrefetchHint: hint,
                progressionDirection: direction,
                tapZonesEnabled: tapZonesEnabledFromDefaults,
                swipeEnabled: swipeEnabledFromDefaults
            )
        case .scroll(let scrollDirection):
            ScrollPageRenderer(
                totalPages: store.pageCount,
                current: binding,
                pageImage: provider,
                onPrefetchHint: hint,
                direction: scrollDirection
            )
        }
    }

    @ViewBuilder
    private var controlsOverlay: some View {
        VStack {
            // TOP overlay
            HStack(spacing: Tokens.Spacing.m) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.title3)
                }
                Spacer()
                VStack(spacing: 0) {
                    Text(store.comic.title).font(.headline).lineLimit(1)
                    Text("\(store.pageIndex + 1) / \(store.pageCount)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button { store.send(.bookmarksTapped(comicId: store.comic.id)) } label: {
                    Image(systemName: "bookmark").font(.title3)
                }
            }
            .padding(.horizontal, Tokens.Spacing.l)
            .padding(.vertical, Tokens.Spacing.m)
            .background(.ultraThinMaterial)
            .glassEffect(in: .rect(cornerRadius: Tokens.Radius.card))
            .padding(Tokens.Spacing.m)

            Spacer()

            // BOTTOM overlay
            HStack(spacing: Tokens.Spacing.m) {
                Slider(
                    value: Binding(
                        get: { Double(store.pageIndex) },
                        set: { store.send(.pageChanged(Int($0.rounded()))) }
                    ),
                    in: 0...Double(max(0, store.pageCount - 1)),
                    step: 1,
                    onEditingChanged: { editing in
                        store.send(editing ? .sliderDragStart : .sliderDragEnd)
                    }
                )
                .tint(Tokens.Colors.accent)

                Menu {
                    Picker("Mode", selection: Binding(
                        get: { store.mode },
                        set: { store.send(.modeChanged($0)) }
                    )) {
                        Text("Single").tag(ReadingMode.single)
                        Text("Dual").tag(ReadingMode.dual)
                        Text("Scroll LTR").tag(ReadingMode.scroll(direction: .ltr))
                        Text("Scroll RTL").tag(ReadingMode.scroll(direction: .rtl))
                        Text("Scroll TTB").tag(ReadingMode.scroll(direction: .ttb))
                    }
                    Picker("Direction", selection: Binding(
                        get: { store.pageProgressionDirection },
                        set: { store.send(.progressionDirectionChanged($0)) }
                    )) {
                        Text("Left to Right").tag(PageProgressionDirection.leftToRight)
                        Text("Right to Left").tag(PageProgressionDirection.rightToLeft)
                    }
                } label: {
                    Image(systemName: "rectangle.split.2x1").font(.title3)
                }
            }
            .padding(.horizontal, Tokens.Spacing.l)
            .padding(.vertical, Tokens.Spacing.m)
            .background(.ultraThinMaterial)
            .glassEffect(in: .rect(cornerRadius: Tokens.Radius.card))
            .padding(Tokens.Spacing.m)
        }
        .foregroundStyle(.white)
    }

    private var tapZonesEnabledFromDefaults: Bool {
        @Dependency(\.userDefaults) var defaults
        let stored = defaults.string(forKey: SettingsFeature.tapZonesKey)
        return stored != "false"   // default ON
    }

    private var swipeEnabledFromDefaults: Bool {
        @Dependency(\.userDefaults) var defaults
        let stored = defaults.string(forKey: SettingsFeature.swipeKey)
        return stored != "false"   // default ON
    }
}
```

- [ ] **Step 2: Build the reader feature**

Run: `xcodebuild build -workspace Mana.xcworkspace -scheme ReaderFeature CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Features/ReaderFeature/Sources/ReaderView.swift
git commit -m "feat(reader-feature): full-screen view + long-press controls + top/bottom overlays"
```

---

## Task 7: SettingsFeature — 5 new settings + AppLanguage

**Files:**
- Modify: `Features/SettingsFeature/Sources/SettingsFeature.swift`
- Modify: `Features/SettingsFeature/Sources/SettingsView.swift`
- Modify: `Features/SettingsFeature/Tests/SettingsFeatureTests.swift`

- [ ] **Step 1: Write failing tests in `Features/SettingsFeature/Tests/SettingsFeatureTests.swift`**

Append:

```swift
@Test func defaultDirectionChangedPersists() async {
    let defaults = InMemoryUserDefaults()
    let store = await TestStore(initialState: SettingsFeature.State()) {
        SettingsFeature()
    } withDependencies: {
        $0.userDefaults = defaults
    }
    await store.send(.defaultDirectionChanged(.rightToLeft)) {
        $0.defaultPageProgressionDirection = .rightToLeft
    }
    #expect(defaults.string(forKey: SettingsFeature.directionKey) == "rightToLeft")
}

@Test func tapZonesToggledPersists() async {
    let defaults = InMemoryUserDefaults()
    let store = await TestStore(initialState: SettingsFeature.State()) {
        SettingsFeature()
    } withDependencies: {
        $0.userDefaults = defaults
    }
    await store.send(.tapZonesToggled(false)) {
        $0.tapZonesEnabled = false
    }
    #expect(defaults.string(forKey: SettingsFeature.tapZonesKey) == "false")
}

@Test func swipeToggledPersists() async {
    let defaults = InMemoryUserDefaults()
    let store = await TestStore(initialState: SettingsFeature.State()) {
        SettingsFeature()
    } withDependencies: {
        $0.userDefaults = defaults
    }
    await store.send(.swipeToggled(false)) {
        $0.swipeEnabled = false
    }
    #expect(defaults.string(forKey: SettingsFeature.swipeKey) == "false")
}

@Test func controlsAutoHideChangedPersists() async {
    let defaults = InMemoryUserDefaults()
    let store = await TestStore(initialState: SettingsFeature.State()) {
        SettingsFeature()
    } withDependencies: {
        $0.userDefaults = defaults
    }
    await store.send(.controlsAutoHideChanged(5.0)) {
        $0.controlsAutoHideSeconds = 5.0
    }
    // Stored as a string for the same getter API used elsewhere
    #expect(defaults.string(forKey: SettingsFeature.autoHideKey) == "5.0")
}

@Test func appLanguageChangedSetsAppleLanguages() async {
    let defaults = InMemoryUserDefaults()
    let store = await TestStore(initialState: SettingsFeature.State()) {
        SettingsFeature()
    } withDependencies: {
        $0.userDefaults = defaults
    }
    await store.send(.appLanguageChanged(.ko)) {
        $0.appLanguage = .ko
    }
    #expect(defaults.string(forKey: SettingsFeature.languageKey) == "ko")
    #expect(defaults.string(forKey: "AppleLanguages") == "[\"ko\"]")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -workspace Mana.xcworkspace -scheme SettingsFeature CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10`
Expected: compile failure.

- [ ] **Step 3: Replace `Features/SettingsFeature/Sources/SettingsFeature.swift`**

```swift
import Foundation
import ComposableArchitecture
import Domain

@Reducer
public struct SettingsFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var defaultMode: ReadingMode
        public var defaultPageProgressionDirection: PageProgressionDirection
        public var controlsAutoHideSeconds: Double
        public var tapZonesEnabled: Bool
        public var swipeEnabled: Bool
        public var appLanguage: AppLanguage

        public init(
            defaultMode: ReadingMode = .single,
            defaultPageProgressionDirection: PageProgressionDirection = .leftToRight,
            controlsAutoHideSeconds: Double = 3.0,
            tapZonesEnabled: Bool = true,
            swipeEnabled: Bool = true,
            appLanguage: AppLanguage = .system
        ) {
            self.defaultMode = defaultMode
            self.defaultPageProgressionDirection = defaultPageProgressionDirection
            self.controlsAutoHideSeconds = controlsAutoHideSeconds
            self.tapZonesEnabled = tapZonesEnabled
            self.swipeEnabled = swipeEnabled
            self.appLanguage = appLanguage
        }
    }

    public enum Action {
        case task
        case defaultModeChanged(ReadingMode)
        case defaultDirectionChanged(PageProgressionDirection)
        case controlsAutoHideChanged(Double)
        case tapZonesToggled(Bool)
        case swipeToggled(Bool)
        case appLanguageChanged(AppLanguage)
    }

    @Dependency(\.userDefaults) var defaults

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                if let raw = defaults.string(forKey: Self.modeKey),
                   let mode = ReadingMode(rawString: raw) {
                    state.defaultMode = mode
                }
                if let raw = defaults.string(forKey: Self.directionKey),
                   let dir = PageProgressionDirection(rawValue: raw) {
                    state.defaultPageProgressionDirection = dir
                }
                if let raw = defaults.string(forKey: Self.autoHideKey),
                   let val = Double(raw) {
                    state.controlsAutoHideSeconds = val
                }
                if let raw = defaults.string(forKey: Self.tapZonesKey) {
                    state.tapZonesEnabled = raw != "false"
                }
                if let raw = defaults.string(forKey: Self.swipeKey) {
                    state.swipeEnabled = raw != "false"
                }
                if let raw = defaults.string(forKey: Self.languageKey),
                   let lang = AppLanguage(rawValue: raw) {
                    state.appLanguage = lang
                }
                return .none

            case let .defaultModeChanged(mode):
                state.defaultMode = mode
                defaults.set(mode.rawString, forKey: Self.modeKey)
                return .none

            case let .defaultDirectionChanged(dir):
                state.defaultPageProgressionDirection = dir
                defaults.set(dir.rawValue, forKey: Self.directionKey)
                return .none

            case let .controlsAutoHideChanged(val):
                state.controlsAutoHideSeconds = val
                defaults.set(String(val), forKey: Self.autoHideKey)
                return .none

            case let .tapZonesToggled(enabled):
                state.tapZonesEnabled = enabled
                defaults.set(enabled ? "true" : "false", forKey: Self.tapZonesKey)
                return .none

            case let .swipeToggled(enabled):
                state.swipeEnabled = enabled
                defaults.set(enabled ? "true" : "false", forKey: Self.swipeKey)
                return .none

            case let .appLanguageChanged(lang):
                state.appLanguage = lang
                defaults.set(lang.rawValue, forKey: Self.languageKey)
                let arrayString = (lang == .system) ? "[]" : "[\"\(lang.rawValue)\"]"
                defaults.set(arrayString, forKey: "AppleLanguages")
                return .none
            }
        }
    }

    public static let modeKey = "mana.defaultReadingMode"
    public static let directionKey = "mana.defaultPageProgressionDirection"
    public static let autoHideKey = "mana.controlsAutoHideSeconds"
    public static let tapZonesKey = "mana.tapZonesEnabled"
    public static let swipeKey = "mana.swipeEnabled"
    public static let languageKey = "mana.appLanguage"
}

public enum AppLanguage: String, Sendable, Equatable, CaseIterable {
    case system
    case en
    case ko
    case ja
}

public protocol UserDefaultsClient: Sendable {
    func string(forKey key: String) -> String?
    func set(_ value: String, forKey key: String)
    func double(forKey key: String) -> Double
}

public struct LiveUserDefaultsClient: UserDefaultsClient {
    public init() {}
    public func string(forKey key: String) -> String? {
        UserDefaults.standard.string(forKey: key)
    }
    public func set(_ value: String, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    public func double(forKey key: String) -> Double {
        UserDefaults.standard.double(forKey: key)
    }
}

public final class InMemoryUserDefaults: UserDefaultsClient, @unchecked Sendable {
    private var values: [String: String] = [:]
    private let lock = NSLock()
    public init() {}
    public func string(forKey key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return values[key]
    }
    public func set(_ value: String, forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        values[key] = value
    }
    public func double(forKey key: String) -> Double {
        lock.lock(); defer { lock.unlock() }
        return values[key].flatMap(Double.init) ?? 0
    }
}

private enum UserDefaultsKey: DependencyKey {
    static let liveValue: any UserDefaultsClient = LiveUserDefaultsClient()
    static let testValue: any UserDefaultsClient = InMemoryUserDefaults()
}

extension DependencyValues {
    public var userDefaults: any UserDefaultsClient {
        get { self[UserDefaultsKey.self] }
        set { self[UserDefaultsKey.self] = newValue }
    }
}
```

- [ ] **Step 4: Replace `Features/SettingsFeature/Sources/SettingsView.swift`**

```swift
import SwiftUI
import ComposableArchitecture
import Domain

public struct SettingsView: View {
    @Bindable public var store: StoreOf<SettingsFeature>
    @State private var showingRestartAlert = false

    public init(store: StoreOf<SettingsFeature>) { self.store = store }

    public var body: some View {
        Form {
            Section("General") {
                Picker("Default Reading Mode", selection: Binding(
                    get: { store.defaultMode },
                    set: { store.send(.defaultModeChanged($0)) }
                )) {
                    Text("Single").tag(ReadingMode.single)
                    Text("Dual").tag(ReadingMode.dual)
                    Text("Scroll LTR").tag(ReadingMode.scroll(direction: .ltr))
                    Text("Scroll RTL").tag(ReadingMode.scroll(direction: .rtl))
                    Text("Webtoon (TTB)").tag(ReadingMode.scroll(direction: .ttb))
                }
                Picker("Default Page Direction", selection: Binding(
                    get: { store.defaultPageProgressionDirection },
                    set: { store.send(.defaultDirectionChanged($0)) }
                )) {
                    Text("Left to Right").tag(PageProgressionDirection.leftToRight)
                    Text("Right to Left").tag(PageProgressionDirection.rightToLeft)
                }
                Picker("App Language", selection: Binding(
                    get: { store.appLanguage },
                    set: {
                        store.send(.appLanguageChanged($0))
                        showingRestartAlert = true
                    }
                )) {
                    Text("System").tag(AppLanguage.system)
                    Text("English").tag(AppLanguage.en)
                    Text("한국어").tag(AppLanguage.ko)
                    Text("日本語").tag(AppLanguage.ja)
                }
            }

            Section("Reader Gestures") {
                Toggle("Tap Zones to Turn Pages", isOn: Binding(
                    get: { store.tapZonesEnabled },
                    set: { store.send(.tapZonesToggled($0)) }
                ))
                Toggle("Swipe to Turn Pages", isOn: Binding(
                    get: { store.swipeEnabled },
                    set: { store.send(.swipeToggled($0)) }
                ))
                Picker("Auto-hide Controls", selection: Binding(
                    get: { store.controlsAutoHideSeconds },
                    set: { store.send(.controlsAutoHideChanged($0)) }
                )) {
                    Text("3 seconds").tag(3.0 as Double)
                    Text("5 seconds").tag(5.0 as Double)
                    Text("Off").tag(0.0 as Double)
                }
            }
        }
        .navigationTitle("Settings")
        .task { await store.send(.task).finish() }
        .alert("Restart Mana", isPresented: $showingRestartAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Restart Mana to apply this change.")
        }
    }
}
```

- [ ] **Step 5: Run tests**

Run: `xcodebuild test -workspace Mana.xcworkspace -scheme SettingsFeature CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10`
Expected: 8/8 PASS (3 existing + 5 new).

- [ ] **Step 6: Commit**

```bash
git add Features/SettingsFeature/
git commit -m "feat(settings-feature): page direction, gesture toggles, auto-hide, app language"
```

---

## Task 8: Localization — en/ko/ja .lproj setup across feature modules

**Files:**
- Modify: `Features/LibraryFeature/Project.swift` — `hasResources: true`
- Modify: `Features/ReaderFeature/Project.swift` — `hasResources: true`
- Modify: `Features/BookmarksFeature/Project.swift` — `hasResources: true`
- Modify: `Features/SettingsFeature/Project.swift` — `hasResources: true`
- Modify: `App/Project.swift` — add `defaultKnownRegions`/`developmentRegion` via `options`
- Create: `Features/LibraryFeature/Resources/en.lproj/Localizable.strings`
- Create: `Features/LibraryFeature/Resources/ko.lproj/Localizable.strings`
- Create: `Features/LibraryFeature/Resources/ja.lproj/Localizable.strings`
- Create: `Features/ReaderFeature/Resources/{en,ko,ja}.lproj/Localizable.strings`
- Create: `Features/BookmarksFeature/Resources/{en,ko,ja}.lproj/Localizable.strings`
- Create: `Features/SettingsFeature/Resources/{en,ko,ja}.lproj/Localizable.strings`
- Replace user-facing string literals in views to use `LocalizedStringKey`

- [ ] **Step 1: Set `hasResources: true` on the four feature Project.swift files**

Each file has a `Module(...)` call. Add `hasResources: true` to the call. Example for `LibraryFeature/Project.swift`:

```swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "LibraryFeature",
    kind: .feature,
    dependencies: [
        .project(target: "Domain", path: "../../Domain"),
        .project(target: "DesignSystem", path: "../../DesignSystem"),
        .project(target: "CloudSyncKit", path: "../../Data/CloudSyncKit")
    ],
    externalDependencies: ["ComposableArchitecture"],
    hasResources: true,
    hasTests: true
).project()
```

Apply the same pattern to ReaderFeature, BookmarksFeature, SettingsFeature.

- [ ] **Step 2: Add `defaultKnownRegions` to App project options**

Modify `App/Project.swift` to add `options:` to the `Project(...)` initializer. Find the existing `Project(name: "App", organizationName: "com.coby", targets: ...)` and add:

```swift
let project = Project(
    name: "App",
    organizationName: "com.coby",
    options: .options(
        defaultKnownRegions: ["en", "ja", "ko", "Base"],
        developmentRegion: "en"
    ),
    targets: [
        // ... existing targets ...
    ]
)
```

- [ ] **Step 3: Create `Features/LibraryFeature/Resources/en.lproj/Localizable.strings`**

```
"library.title"             = "Library";
"library.empty"             = "No comics yet";
"library.import"            = "Import";
"library.import_dotdotdot"  = "Import…";
"library.new_folder"        = "New Folder";
"library.move_to"           = "Move to…";
"library.move_to_root"      = "Move to Library Root";
"library.delete"            = "Delete";
"library.sort"              = "Sort";
"library.filter"            = "Filter";
"library.create"            = "Create";
"library.cancel"            = "Cancel";
"library.folder_name"       = "Folder Name";
"library.folder_name_placeholder" = "e.g. Manga";
"library.import_failed"     = "Import failed";
"library.importing"         = "Importing…";
"library.folders"           = "Folders";
```

- [ ] **Step 4: Create `Features/LibraryFeature/Resources/ko.lproj/Localizable.strings`**

```
"library.title"             = "라이브러리";
"library.empty"             = "아직 만화가 없습니다";
"library.import"            = "가져오기";
"library.import_dotdotdot"  = "가져오기…";
"library.new_folder"        = "새 폴더";
"library.move_to"           = "이동…";
"library.move_to_root"      = "루트로 이동";
"library.delete"            = "삭제";
"library.sort"              = "정렬";
"library.filter"            = "필터";
"library.create"            = "만들기";
"library.cancel"            = "취소";
"library.folder_name"       = "폴더 이름";
"library.folder_name_placeholder" = "예: 만화";
"library.import_failed"     = "가져오기 실패";
"library.importing"         = "가져오는 중…";
"library.folders"           = "폴더";
```

- [ ] **Step 5: Create `Features/LibraryFeature/Resources/ja.lproj/Localizable.strings`**

```
"library.title"             = "ライブラリ";
"library.empty"             = "コミックがありません";
"library.import"            = "読み込み";
"library.import_dotdotdot"  = "読み込み…";
"library.new_folder"        = "新規フォルダ";
"library.move_to"           = "移動…";
"library.move_to_root"      = "ルートに移動";
"library.delete"            = "削除";
"library.sort"              = "並べ替え";
"library.filter"            = "フィルタ";
"library.create"            = "作成";
"library.cancel"            = "キャンセル";
"library.folder_name"       = "フォルダ名";
"library.folder_name_placeholder" = "例: 漫画";
"library.import_failed"     = "読み込み失敗";
"library.importing"         = "読み込み中…";
"library.folders"           = "フォルダ";
```

- [ ] **Step 6: Create ReaderFeature .lproj files**

`Features/ReaderFeature/Resources/en.lproj/Localizable.strings`:
```
"reader.controls.back"     = "Back";
"reader.controls.bookmark" = "Bookmark";
"reader.controls.mode"     = "Mode";
"reader.controls.direction" = "Direction";
"reader.error.cannot_open" = "Cannot open comic";
"mode.single"              = "Single";
"mode.dual"                = "Dual";
"mode.scroll.ltr"          = "Scroll (LTR)";
"mode.scroll.rtl"          = "Scroll (RTL)";
"mode.scroll.ttb"          = "Webtoon (TTB)";
"direction.ltr"            = "Left to Right";
"direction.rtl"            = "Right to Left";
```

`Features/ReaderFeature/Resources/ko.lproj/Localizable.strings`:
```
"reader.controls.back"     = "뒤로";
"reader.controls.bookmark" = "북마크";
"reader.controls.mode"     = "모드";
"reader.controls.direction" = "진행 방향";
"reader.error.cannot_open" = "만화를 열 수 없습니다";
"mode.single"              = "한 페이지";
"mode.dual"                = "두 페이지";
"mode.scroll.ltr"          = "스크롤 (좌→우)";
"mode.scroll.rtl"          = "스크롤 (우→좌)";
"mode.scroll.ttb"          = "웹툰 (위→아래)";
"direction.ltr"            = "왼쪽에서 오른쪽";
"direction.rtl"            = "오른쪽에서 왼쪽";
```

`Features/ReaderFeature/Resources/ja.lproj/Localizable.strings`:
```
"reader.controls.back"     = "戻る";
"reader.controls.bookmark" = "ブックマーク";
"reader.controls.mode"     = "モード";
"reader.controls.direction" = "進行方向";
"reader.error.cannot_open" = "コミックを開けません";
"mode.single"              = "シングル";
"mode.dual"                = "デュアル";
"mode.scroll.ltr"          = "スクロール (左→右)";
"mode.scroll.rtl"          = "スクロール (右→左)";
"mode.scroll.ttb"          = "縦読み";
"direction.ltr"            = "左から右";
"direction.rtl"            = "右から左";
```

- [ ] **Step 7: Create BookmarksFeature .lproj files**

`Features/BookmarksFeature/Resources/en.lproj/Localizable.strings`:
```
"bookmarks.title"        = "Bookmarks";
"bookmarks.add"          = "Add Bookmark";
"bookmarks.note"         = "Note (optional)";
"bookmarks.note_placeholder" = "e.g. great panel";
"bookmarks.empty"        = "No bookmarks";
"bookmarks.delete"       = "Delete";
"bookmarks.cancel"       = "Cancel";
"bookmarks.save"         = "Save";
"bookmarks.page"         = "Page";
```

`Features/BookmarksFeature/Resources/ko.lproj/Localizable.strings`:
```
"bookmarks.title"        = "북마크";
"bookmarks.add"          = "북마크 추가";
"bookmarks.note"         = "메모 (선택)";
"bookmarks.note_placeholder" = "예: 멋진 컷";
"bookmarks.empty"        = "북마크 없음";
"bookmarks.delete"       = "삭제";
"bookmarks.cancel"       = "취소";
"bookmarks.save"         = "저장";
"bookmarks.page"         = "페이지";
```

`Features/BookmarksFeature/Resources/ja.lproj/Localizable.strings`:
```
"bookmarks.title"        = "ブックマーク";
"bookmarks.add"          = "ブックマーク追加";
"bookmarks.note"         = "メモ（任意）";
"bookmarks.note_placeholder" = "例：いい場面";
"bookmarks.empty"        = "ブックマークなし";
"bookmarks.delete"       = "削除";
"bookmarks.cancel"       = "キャンセル";
"bookmarks.save"         = "保存";
"bookmarks.page"         = "ページ";
```

- [ ] **Step 8: Create SettingsFeature .lproj files**

`Features/SettingsFeature/Resources/en.lproj/Localizable.strings`:
```
"settings.title"           = "Settings";
"settings.general"         = "General";
"settings.gestures"        = "Reader Gestures";
"settings.default_mode"    = "Default Reading Mode";
"settings.default_direction" = "Default Page Direction";
"settings.app_language"    = "App Language";
"settings.tap_zones"       = "Tap Zones to Turn Pages";
"settings.swipe"           = "Swipe to Turn Pages";
"settings.auto_hide"       = "Auto-hide Controls";
"settings.auto_hide.3"     = "3 seconds";
"settings.auto_hide.5"     = "5 seconds";
"settings.auto_hide.off"   = "Off";
"settings.restart_required" = "Restart Mana to apply this change.";
"settings.restart_title"   = "Restart Mana";
"settings.ok"              = "OK";
"language.system"          = "System";
"language.en"              = "English";
"language.ko"              = "한국어";
"language.ja"              = "日本語";
```

`Features/SettingsFeature/Resources/ko.lproj/Localizable.strings`:
```
"settings.title"           = "설정";
"settings.general"         = "일반";
"settings.gestures"        = "리더 제스처";
"settings.default_mode"    = "기본 읽기 모드";
"settings.default_direction" = "기본 페이지 방향";
"settings.app_language"    = "앱 언어";
"settings.tap_zones"       = "탭으로 페이지 넘기기";
"settings.swipe"           = "스와이프로 페이지 넘기기";
"settings.auto_hide"       = "컨트롤 자동 숨김";
"settings.auto_hide.3"     = "3초";
"settings.auto_hide.5"     = "5초";
"settings.auto_hide.off"   = "끄기";
"settings.restart_required" = "언어 변경을 적용하려면 Mana를 다시 시작하세요.";
"settings.restart_title"   = "Mana 다시 시작";
"settings.ok"              = "확인";
"language.system"          = "시스템";
"language.en"              = "English";
"language.ko"              = "한국어";
"language.ja"              = "日本語";
```

`Features/SettingsFeature/Resources/ja.lproj/Localizable.strings`:
```
"settings.title"           = "設定";
"settings.general"         = "一般";
"settings.gestures"        = "リーダージェスチャ";
"settings.default_mode"    = "既定の読み取りモード";
"settings.default_direction" = "既定のページ方向";
"settings.app_language"    = "アプリの言語";
"settings.tap_zones"       = "タップでページめくり";
"settings.swipe"           = "スワイプでページめくり";
"settings.auto_hide"       = "コントロールの自動非表示";
"settings.auto_hide.3"     = "3秒";
"settings.auto_hide.5"     = "5秒";
"settings.auto_hide.off"   = "オフ";
"settings.restart_required" = "言語変更を反映するためMana を再起動してください。";
"settings.restart_title"   = "Mana を再起動";
"settings.ok"              = "OK";
"language.system"          = "システム";
"language.en"              = "English";
"language.ko"              = "한국어";
"language.ja"              = "日本語";
```

- [ ] **Step 9: Replace string literals in feature views with localization keys**

In each feature's `*.swift` view files, replace user-visible `Text("...")` and `Label("...", systemImage: "...")` calls with their localization-key equivalents. SwiftUI auto-resolves `Text("library.title")` against the calling module's `Bundle.module`.

For `LibraryView.swift`, change `.navigationTitle("Library")` to:
```swift
.navigationTitle(store.currentFolder?.name ?? String(localized: "library.title", bundle: .module))
```

For `LibraryRow.swift`, no change needed (no user-facing strings beyond format extension).

For `NewFolderSheetView`, replace:
- `Text("Folder Name")` → `Text("library.folder_name")`
- `TextField("e.g. Manga", text: $name)` → `TextField(String(localized: "library.folder_name_placeholder", bundle: .module), text: $name)`
- `.navigationTitle("New Folder")` → `.navigationTitle(Text("library.new_folder"))`
- `Button("Cancel", ...)` → `Button(String(localized: "library.cancel", bundle: .module), ...)`
- `Button("Create", ...)` → `Button(String(localized: "library.create", bundle: .module), ...)`

For `LibraryView.swift`, replace:
- `Section("Folders")` → `Section(LocalizedStringKey("library.folders"))`
- `Label("Move to…", systemImage: "folder")` → `Label(LocalizedStringKey("library.move_to"), systemImage: "folder")`
- `Button("Move to Library Root")` → `Button(LocalizedStringKey("library.move_to_root")) { ... }`
- `Label("New Folder", systemImage: "folder.badge.plus")` → use `LocalizedStringKey("library.new_folder")`
- `Label("Import…", systemImage: "doc.badge.plus")` → use `LocalizedStringKey("library.import_dotdotdot")`
- `ProgressView("Importing…")` → `ProgressView(LocalizedStringKey("library.importing"))`
- `TextState("Import failed")` → `TextState(LocalizedStringKey("library.import_failed"))`

For `ReaderView.swift`, replace user-visible Picker labels:
- `Text("Single").tag(...)` → `Text(LocalizedStringKey("mode.single")).tag(...)`
- `Text("Dual").tag(...)` → `Text(LocalizedStringKey("mode.dual")).tag(...)`
- `Text("Scroll LTR").tag(...)` → `Text(LocalizedStringKey("mode.scroll.ltr")).tag(...)`
- `Text("Scroll RTL").tag(...)` → `Text(LocalizedStringKey("mode.scroll.rtl")).tag(...)`
- `Text("Scroll TTB").tag(...)` → `Text(LocalizedStringKey("mode.scroll.ttb")).tag(...)`
- `Text("Left to Right").tag(...)` → `Text(LocalizedStringKey("direction.ltr")).tag(...)`
- `Text("Right to Left").tag(...)` → `Text(LocalizedStringKey("direction.rtl")).tag(...)`
- `TextState("Cannot open comic")` → `TextState(LocalizedStringKey("reader.error.cannot_open"))`

For `BookmarksView.swift`:
- `ContentUnavailableView("No bookmarks", systemImage: "bookmark")` → `ContentUnavailableView(LocalizedStringKey("bookmarks.empty"), systemImage: "bookmark")`
- `Text("Page \(bm.pageIndex + 1)")` → `Text("\(LocalizedStringKey("bookmarks.page")) \(bm.pageIndex + 1)")`
- `Label("Delete", systemImage: "trash")` → `Label(LocalizedStringKey("bookmarks.delete"), systemImage: "trash")`
- `.navigationTitle("Bookmarks")` → `.navigationTitle(Text("bookmarks.title"))`

For `BookmarkSheet.swift`:
- `Text("Page")` → `Text(LocalizedStringKey("bookmarks.page"))`
- `Text("Note (optional)")` → `Text(LocalizedStringKey("bookmarks.note"))`
- `TextField("e.g. great panel", ...)` → `TextField(String(localized: "bookmarks.note_placeholder", bundle: .module), ...)`
- `.navigationTitle("Add Bookmark")` → `.navigationTitle(Text("bookmarks.add"))`
- `Button("Cancel", ...)` and `Button("Save", ...)` → use `LocalizedStringKey` accordingly.

For `SettingsView.swift`:
- All `Section("...")` calls → `Section(LocalizedStringKey("settings.<section>"))`
- All `Picker("...", ...)` and `Toggle("...", ...)` labels → use `LocalizedStringKey`
- `.navigationTitle("Settings")` → `.navigationTitle(Text("settings.title"))`
- The "Restart Mana" alert title and message → use `LocalizedStringKey`

These are exact 1:1 replacements; the implementer should grep for `Text("` / `Section("` / `Picker("` / `Label("` / `Button("` / `Toggle("` / `.navigationTitle("` / `TextField("` / `ContentUnavailableView("` / `TextState("` / `ProgressView("` / `.navigationBarTitleDisplayMode` adjacent strings in each modified view, and replace each user-facing English literal with its key from the `.lproj` files above. Skip `Image(systemName:)` calls — those are SF Symbol identifiers, not user-visible text.

- [ ] **Step 10: Build and run all tests**

```bash
./Scripts/setup.sh
xcodebuild build -workspace Mana.xcworkspace -scheme Mana CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED. (No tests exercise localized strings directly; covered manually.)

- [ ] **Step 11: Manual smoke test**

```bash
xcrun simctl boot "iPad Pro 13-inch (M5)" 2>/dev/null || true
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name 'Mana.app' -path '*Debug-iphonesimulator*' | head -1)
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.coby.mana
```
Open Settings → App Language → 한국어 → restart simulator app. Verify Library title is "라이브러리".

- [ ] **Step 12: Commit**

```bash
git add Features/ App/Project.swift
git commit -m "i18n: en/ko/ja localizations across feature modules"
```

---

## Task 9: App composition root — wire FolderRepository, update LibraryImporterLive

**Files:**
- Modify: `App/Sources/DependenciesLive.swift`
- Modify: `App/Sources/LibraryImporterLive.swift`
- Modify: `App/Tests/IntegrationFlowTests.swift`

- [ ] **Step 1: Update `App/Sources/LibraryImporterLive.swift`**

Add the `folderId:` parameter to match the new `LibraryImporter` protocol:

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

    public func importFiles(_ urls: [URL], folderId: UUID?) async throws -> [ComicItem] {
        var results: [ComicItem] = []
        for url in urls {
            let needsStop = url.startAccessingSecurityScopedResource()
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }

            guard let format = ComicFormat(fileExtension: url.pathExtension) else {
                throw ArchiveError.unsupportedFormat(url.pathExtension)
            }

            let canonicalURL: URL
            let bookmark: Data?
            if await fileSync.isAvailable {
                canonicalURL = try await fileSync.ingest(localURL: url)
                bookmark = nil
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
                urlBookmarkData: bookmark,
                folderId: folderId,
                pageProgressionDirection: nil
            )
            try await repo.upsert(item)
            results.append(item)
        }
        return results
    }
}
```

- [ ] **Step 2: Update `App/Sources/DependenciesLive.swift`**

Wire the new `\.folderRepository` dependency:

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
    static let containerIdentifier = "iCloud.com.coby.mana"

    static func register() {
        let ubi = UbiquityContainer(identifier: containerIdentifier)

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
        let folderRepo = FolderRepositoryLive(stack: stack)
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
            repo: comicRepo, router: router, cache: cache,
            thumbnails: thumbnails, fileSync: fileSync
        )

        prepareDependencies {
            $0.archiveReaderRouter = router
            $0.progressRepository = progressRepo
            $0.imageCache = cache
            $0.comicRepository = comicRepo
            $0.libraryImporter = importer
            $0.bookmarkRepository = bookmarkRepo
            $0.folderRepository = folderRepo
            $0.userDefaults = LiveUserDefaultsClient()
            $0.fileSyncService = fileSync
        }
    }
}
```

- [ ] **Step 3: Update `App/Tests/IntegrationFlowTests.swift`**

The integration test calls `LibraryImporterLive(...).importFiles([fixture])`. Update to pass `folderId: nil`:

```swift
let imported = try await importer.importFiles([fixture], folderId: nil)
```

Also assert `comic.folderId == nil` (verifies the new field round-trips through the repo):

```swift
#expect(comic.folderId == nil)
```

- [ ] **Step 4: Generate, build, run integration test**

```bash
./Scripts/setup.sh
xcodebuild build -workspace Mana.xcworkspace -scheme Mana CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -5
xcodebuild test -workspace Mana.xcworkspace -scheme Mana CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED, integration TEST SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add App/
git commit -m "feat(app): wire FolderRepository + LibraryImporterLive folderId param"
```

---

## Task 10: Final verification — full build + all tests + smoke

**Files:** none modified — verification only

- [ ] **Step 1: Generate workspace**

```bash
./Scripts/setup.sh
```

- [ ] **Step 2: Run every module's unit tests**

```bash
for scheme in Domain ArchiveKit PersistenceKit CloudSyncKit ImageCacheKit ThumbnailKit SharedUI DesignSystem ReaderFeature LibraryFeature BookmarksFeature SettingsFeature; do
  echo "=== $scheme ==="
  xcodebuild test -workspace Mana.xcworkspace -scheme $scheme CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | grep -E "Test run|TEST" | tail -2
done
```
Expected: every scheme reports TEST SUCCEEDED.

- [ ] **Step 3: Run integration test**

```bash
xcodebuild test -workspace Mana.xcworkspace -scheme Mana CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -5
```
Expected: TEST SUCCEEDED.

- [ ] **Step 4: Smoke test on simulator**

```bash
xcrun simctl boot "iPad Pro 13-inch (M5)" 2>/dev/null || true
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name 'Mana.app' -path '*Debug-iphonesimulator*' | head -1)
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.coby.mana
```
Manual checks (using your eyes):
- App launches
- Toolbar `+` menu shows "New Folder", "Import…"
- Creating "Manga" folder produces a folder card
- Tapping folder enters it; back button returns to root
- Importing a `.cbz` (drag from Files) places it correctly (root vs folder)
- Opening a comic shows full-screen reader with no nav bar, no status bar
- Tap on left half = previous page; right half = next page
- Long-press shows top + bottom controls; auto-hide after 3 s
- Settings → App Language → 한국어 → restart → UI is Korean

- [ ] **Step 5: Commit empty marker (optional)**

```bash
git commit --allow-empty -m "chore(plan-5): verification — all 10 tasks complete"
```

---

## Plan 5 Completion Checklist

- [ ] All module unit tests pass (Domain 6, ArchiveKit 11, PersistenceKit 13+, CloudSyncKit 6, ImageCacheKit 3, ThumbnailKit 2, ReaderFeature 7, LibraryFeature 10, BookmarksFeature 4, SettingsFeature 8)
- [ ] Integration test passes
- [ ] App builds for iPad iOS 26.4 simulator
- [ ] All 20 acceptance criteria from the spec verified manually

## What's Next (Plan 6 candidates)

- Folder rename
- Drag a comic onto a folder card
- Volume button page turn (AVAudioSession)
- Face ID / passcode lock
- Slideshow auto-advance
- Image filters (contrast/invert)
- More languages (zh-Hans, fr, es, de)

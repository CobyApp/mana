# On-Device Apple Intelligence Translation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an in-reader auto-translation overlay powered by Apple Foundation Models. Gated to iOS 26+ devices where `SystemLanguageModel.default.availability == .available`.

**Architecture:** New `Data/IntelligenceKit` module wraps Vision OCR (constrained to ja/ko/en), `NLLanguageRecognizer`, and Foundation Models. Domain layer gains 3 models + 3 protocols. PersistenceKit gains a SwiftData-backed translation cache. Settings and Reader each gain a gated toggle bound to a single shared UserDefaults key. AppFeature owns the availability check and injects a Bool into child states.

**Tech Stack:** Swift 6 · SwiftUI · Tuist · The Composable Architecture 1.15+ · SwiftData · Vision · NaturalLanguage · FoundationModels (iOS 26+) · Swift Testing.

**Spec:** [`docs/superpowers/specs/2026-05-14-mana-on-device-translation-design.md`](../specs/2026-05-14-mana-on-device-translation-design.md).

---

## File Structure

**New files:**
- `Domain/Sources/Models/TextLineBox.swift`
- `Domain/Sources/Models/TranslatedLine.swift`
- `Domain/Sources/Models/TranslatedPage.swift`
- `Domain/Sources/Repositories/IntelligenceAvailability.swift`
- `Domain/Sources/Repositories/PageTranslator.swift`
- `Domain/Sources/Repositories/TranslationCache.swift`
- `Domain/Tests/TextLineBoxTests.swift`
- `Domain/Tests/TranslatedPageTests.swift`
- `DesignSystem/Sources/ColorARGB.swift`
- `Data/PersistenceKit/Sources/TranslationCacheLive.swift`
- `Data/PersistenceKit/Tests/TranslationCacheLiveTests.swift`
- `Data/IntelligenceKit/Project.swift`
- `Data/IntelligenceKit/Sources/UnavailableIntelligence.swift`
- `Data/IntelligenceKit/Sources/NoopPageTranslator.swift`
- `Data/IntelligenceKit/Sources/InMemoryTranslationCache.swift`
- `Data/IntelligenceKit/Sources/LanguageDetector.swift`
- `Data/IntelligenceKit/Sources/BackgroundColorSampler.swift`
- `Data/IntelligenceKit/Sources/VisionTextRecognizer.swift`
- `Data/IntelligenceKit/Sources/LLMTranslator.swift`
- `Data/IntelligenceKit/Sources/FoundationModelsTranslator.swift`
- `Data/IntelligenceKit/Sources/PageTranslatorLive.swift`
- `Data/IntelligenceKit/Sources/IntelligenceAvailabilityLive.swift`
- `Data/IntelligenceKit/Sources/TargetLanguageResolver.swift`
- `Data/IntelligenceKit/Tests/LanguageDetectorTests.swift`
- `Data/IntelligenceKit/Tests/BackgroundColorSamplerTests.swift`
- `Data/IntelligenceKit/Tests/VisionTextRecognizerTests.swift`
- `Data/IntelligenceKit/Tests/PageTranslatorLiveTests.swift`
- `Features/ReaderFeature/Sources/PageTranslationOverlay.swift`
- `Features/ReaderFeature/Sources/TranslationDependencyKeys.swift`

**Modified files:**
- `Workspace.swift`
- `Data/PersistenceKit/Sources/SwiftDataModels.swift`
- `Data/PersistenceKit/Sources/SwiftDataStack.swift`
- `Features/SettingsFeature/Sources/SettingsFeature.swift`
- `Features/SettingsFeature/Sources/SettingsView.swift`
- `Features/SettingsFeature/Resources/{ko,ja,en}.lproj/Localizable.strings`
- `Features/SettingsFeature/Tests/SettingsFeatureTests.swift`
- `Features/ReaderFeature/Sources/ReaderFeature.swift`
- `Features/ReaderFeature/Sources/ReaderView.swift`
- `Features/ReaderFeature/Sources/SinglePageRenderer.swift`
- `Features/ReaderFeature/Sources/DualPageRenderer.swift`
- `Features/ReaderFeature/Resources/{ko,ja,en}.lproj/Localizable.strings`
- `Features/ReaderFeature/Tests/ReaderFeatureTests.swift`
- `Features/AppFeature/Sources/AppFeature.swift`
- `Features/AppFeature/Project.swift`
- `App/Sources/DependenciesLive.swift`
- `App/Sources/LibraryResetServiceLive.swift`
- `App/Project.swift`
- `App/Tests/IntegrationFlowTests.swift`

---

## Spec Coverage Map

| Spec § | Tasks |
| --- | --- |
| §1.1 Supported langs | 9, 12, 14 |
| §1.2 In Scope (1) device gate | 14, 22, 23 |
| §1.2 In Scope (2) two surfaces | 15, 16, 21 |
| §1.2 In Scope (3) pipeline | 11, 12, 13 |
| §1.2 In Scope (4) overlay rendering | 4, 19, 20 |
| §1.2 In Scope (5) prefetch | 18 |
| §1.2 In Scope (6) cache | 5, 6 |
| §1.2 In Scope (7) both modes | 20 |
| §1.2 In Scope (8) library reset | 24 |
| §2 Capability gating | 8, 14, 22, 23 |
| §3 Module map | 7 (+ each subsequent file task) |
| §4 Domain types | 1, 2 |
| §5 Protocols | 3 |
| §6 Pipeline | 9, 10, 11, 12, 13 |
| §6.1 Prompt | 12 |
| §6.2 Target lang resolver | 14 |
| §7 ReaderFeature | 17, 18, 19, 20, 21 |
| §8 SettingsFeature | 15, 16 |
| §9 Cache schema/impl | 5, 6 |
| §10 Error handling | 13, 18 |
| §11 Testing | embedded per task + 25 |
| §12 Localization | 16, 21 |
| §13 iOS 17 + iOS 26 gate | 12, 14, 23 |
| §15 Acceptance | 23, 24, 25 |

---

## Task 1: Domain — `TextLineBox`

**Files:**
- Create: `Domain/Sources/Models/TextLineBox.swift`
- Create: `Domain/Tests/TextLineBoxTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Domain/Tests/TextLineBoxTests.swift
import Testing
import Foundation
import CoreGraphics
@testable import Domain

@Suite struct TextLineBoxTests {
    @Test func codableRoundTrip() throws {
        let id = UUID()
        let original = TextLineBox(
            id: id,
            text: "こんにちは",
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.05),
            confidence: 0.93
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TextLineBox.self, from: data)
        #expect(decoded == original)
    }

    @Test func equalityIgnoresIdentity() {
        let a = TextLineBox(id: UUID(), text: "x", boundingBox: .zero, confidence: 0)
        let b = TextLineBox(id: a.id, text: "x", boundingBox: .zero, confidence: 0)
        let c = TextLineBox(id: UUID(), text: "x", boundingBox: .zero, confidence: 0)
        #expect(a == b)
        #expect(a != c)  // id differs
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run from repo root:
```bash
tuist test Domain --test-targets DomainTests/TextLineBoxTests
```
Expected: build failure ("TextLineBox not found").

- [ ] **Step 3: Implement the model**

```swift
// Domain/Sources/Models/TextLineBox.swift
import Foundation
import CoreGraphics

public struct TextLineBox: Equatable, Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let text: String
    /// Vision-normalized rect. Origin is bottom-left, all values in 0...1.
    public let boundingBox: CGRect
    public let confidence: Float

    public init(id: UUID, text: String, boundingBox: CGRect, confidence: Float) {
        self.id = id
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
tuist test Domain --test-targets DomainTests/TextLineBoxTests
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Domain/Sources/Models/TextLineBox.swift Domain/Tests/TextLineBoxTests.swift
git commit -m "feat(domain): add TextLineBox model"
```

---

## Task 2: Domain — `TranslatedLine` + `TranslatedPage`

**Files:**
- Create: `Domain/Sources/Models/TranslatedLine.swift`
- Create: `Domain/Sources/Models/TranslatedPage.swift`
- Create: `Domain/Tests/TranslatedPageTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Domain/Tests/TranslatedPageTests.swift
import Testing
import Foundation
import CoreGraphics
@testable import Domain

@Suite struct TranslatedPageTests {
    @Test func emptyPageHasNoLines() {
        let page = TranslatedPage(
            comicId: UUID(), pageIndex: 0,
            sourceLanguage: "und", targetLanguage: "ko",
            lines: [], createdAt: Date()
        )
        #expect(page.lines.isEmpty)
    }

    @Test func codableRoundTrip() throws {
        let comicId = UUID()
        let box = TextLineBox(id: UUID(), text: "こんにちは",
                              boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.05),
                              confidence: 0.9)
        let line = TranslatedLine(original: box, translated: "안녕하세요", backgroundColorARGB: 0xFFEEEEEE)
        let page = TranslatedPage(
            comicId: comicId, pageIndex: 3,
            sourceLanguage: "ja", targetLanguage: "ko",
            lines: [line], createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(page)
        let decoded = try JSONDecoder().decode(TranslatedPage.self, from: data)
        #expect(decoded == page)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
tuist test Domain --test-targets DomainTests/TranslatedPageTests
```
Expected: build failure ("TranslatedLine/TranslatedPage not found").

- [ ] **Step 3: Implement both models**

```swift
// Domain/Sources/Models/TranslatedLine.swift
import Foundation

public struct TranslatedLine: Equatable, Sendable, Hashable, Codable {
    public let original: TextLineBox
    public let translated: String
    /// ARGB packed UInt32 (alpha in the high byte).
    public let backgroundColorARGB: UInt32

    public init(original: TextLineBox, translated: String, backgroundColorARGB: UInt32) {
        self.original = original
        self.translated = translated
        self.backgroundColorARGB = backgroundColorARGB
    }
}
```

```swift
// Domain/Sources/Models/TranslatedPage.swift
import Foundation

public struct TranslatedPage: Equatable, Sendable, Hashable, Codable {
    public let comicId: UUID
    public let pageIndex: Int
    /// BCP-47 of the detected source language. "und" when detection failed.
    public let sourceLanguage: String
    /// BCP-47 of the target language used when the page was translated.
    public let targetLanguage: String
    public let lines: [TranslatedLine]
    public let createdAt: Date

    public init(
        comicId: UUID,
        pageIndex: Int,
        sourceLanguage: String,
        targetLanguage: String,
        lines: [TranslatedLine],
        createdAt: Date
    ) {
        self.comicId = comicId
        self.pageIndex = pageIndex
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.lines = lines
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
tuist test Domain --test-targets DomainTests/TranslatedPageTests
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Domain/Sources/Models/TranslatedLine.swift Domain/Sources/Models/TranslatedPage.swift Domain/Tests/TranslatedPageTests.swift
git commit -m "feat(domain): add TranslatedLine and TranslatedPage models"
```

---

## Task 3: Domain — Translation protocols

**Files:**
- Create: `Domain/Sources/Repositories/IntelligenceAvailability.swift`
- Create: `Domain/Sources/Repositories/PageTranslator.swift`
- Create: `Domain/Sources/Repositories/TranslationCache.swift`

No tests — these are pure protocols. Their consumers will be tested through fakes.

- [ ] **Step 1: Create the three protocol files**

```swift
// Domain/Sources/Repositories/IntelligenceAvailability.swift
import Foundation

public protocol IntelligenceAvailability: Sendable {
    /// True only when the on-device system language model is loaded and ready.
    var isAvailable: Bool { get }
}
```

```swift
// Domain/Sources/Repositories/PageTranslator.swift
import Foundation

public protocol PageTranslator: Sendable {
    /// OCR + language detection + LLM translation for one page.
    ///
    /// Returns a `TranslatedPage` on success. The result may have an empty
    /// `lines` array — that is a valid "no work to do" outcome (no text on
    /// page, or source language already matches target). Empty results are
    /// still meant to be cached so we don't re-OCR on revisit.
    ///
    /// Throws only on unrecoverable errors (e.g. `CancellationError`).
    /// Recoverable failures (model unavailable, LLM mismatch) are surfaced
    /// by throwing `PageTranslatorError.silentFailure` so callers can
    /// distinguish "no cache" from "empty result".
    func translate(
        imageData: Data,
        comicId: UUID,
        pageIndex: Int,
        targetLanguage: String
    ) async throws -> TranslatedPage
}

public enum PageTranslatorError: Error, Sendable {
    /// Recoverable failure. The caller should not cache the result.
    case silentFailure
}
```

```swift
// Domain/Sources/Repositories/TranslationCache.swift
import Foundation

public protocol TranslationCache: Sendable {
    func load(comicId: UUID, pageIndex: Int, targetLanguage: String) async -> TranslatedPage?
    func save(_ page: TranslatedPage) async throws
    func deleteAll(comicId: UUID) async throws
    func deleteEverything() async throws
}
```

- [ ] **Step 2: Verify the Domain target still builds**

```bash
tuist test Domain
```
Expected: all existing Domain tests still PASS, no warnings.

- [ ] **Step 3: Commit**

```bash
git add Domain/Sources/Repositories/IntelligenceAvailability.swift Domain/Sources/Repositories/PageTranslator.swift Domain/Sources/Repositories/TranslationCache.swift
git commit -m "feat(domain): add translation/availability protocols"
```

---

## Task 4: DesignSystem — `Color(argb:)` helper

**Files:**
- Create: `DesignSystem/Sources/ColorARGB.swift`

No dedicated test target exists for DesignSystem in this repo (check with `ls DesignSystem/Tests` — does not exist). The helper is exercised indirectly through `PageTranslationOverlay` later.

- [ ] **Step 1: Implement the helper**

```swift
// DesignSystem/Sources/ColorARGB.swift
import SwiftUI

public extension Color {
    /// Unpacks an ARGB-packed UInt32 (alpha in the high byte) into a SwiftUI Color.
    /// The translation overlay uses this to recreate sampled page background colors.
    init(argb value: UInt32) {
        let a = Double((value >> 24) & 0xFF) / 255.0
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >>  8) & 0xFF) / 255.0
        let b = Double(value        & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Packs the receiver into an ARGB UInt32. Conversion happens via UIColor so
    /// alternative color spaces resolve to sRGB components.
    static func packARGB(red: Double, green: Double, blue: Double, alpha: Double) -> UInt32 {
        let a = UInt32(max(0, min(255, alpha * 255)))
        let r = UInt32(max(0, min(255, red * 255)))
        let g = UInt32(max(0, min(255, green * 255)))
        let b = UInt32(max(0, min(255, blue * 255)))
        return (a << 24) | (r << 16) | (g << 8) | b
    }
}
```

- [ ] **Step 2: Verify it builds**

```bash
tuist generate DesignSystem
xcodebuild build -workspace Mana.xcworkspace -scheme DesignSystem -destination 'generic/platform=iOS' -quiet
```
Expected: succeeds. (If `tuist test DesignSystem` errors because there is no test target, ignore — it is a framework-only module.)

- [ ] **Step 3: Commit**

```bash
git add DesignSystem/Sources/ColorARGB.swift
git commit -m "feat(design-system): add Color ARGB pack/unpack helpers"
```

---

## Task 5: PersistenceKit — `TranslatedPageRecord` SwiftData model + schema

**Files:**
- Modify: `Data/PersistenceKit/Sources/SwiftDataModels.swift`
- Modify: `Data/PersistenceKit/Sources/SwiftDataStack.swift`

- [ ] **Step 1: Append the new `@Model` class**

Append to `Data/PersistenceKit/Sources/SwiftDataModels.swift` (after `ReadingProgressEntity`):

```swift
@Model
public final class TranslatedPageRecord {
    @Attribute(.unique) public var key: String   // "<comicId>|<idx>|<target>"
    public var comicId: UUID = UUID()
    public var pageIndex: Int = 0
    public var targetLanguage: String = ""
    public var sourceLanguage: String = ""
    public var linesJSON: Data = Data()
    public var createdAt: Date = Date(timeIntervalSince1970: 0)

    public init(
        comicId: UUID,
        pageIndex: Int,
        targetLanguage: String,
        sourceLanguage: String,
        linesJSON: Data,
        createdAt: Date
    ) {
        self.key = "\(comicId.uuidString)|\(pageIndex)|\(targetLanguage)"
        self.comicId = comicId
        self.pageIndex = pageIndex
        self.targetLanguage = targetLanguage
        self.sourceLanguage = sourceLanguage
        self.linesJSON = linesJSON
        self.createdAt = createdAt
    }

    public static func compositeKey(comicId: UUID, pageIndex: Int, targetLanguage: String) -> String {
        "\(comicId.uuidString)|\(pageIndex)|\(targetLanguage)"
    }
}
```

- [ ] **Step 2: Add the new type to both `ModelContainer` schemas**

Edit `Data/PersistenceKit/Sources/SwiftDataStack.swift`. In **both** `inMemory()` and `onDisk(url:)`, change the `ModelContainer` call to include `TranslatedPageRecord.self`:

```swift
let container = try ModelContainer(
    for: ComicEntity.self,
        ReadingProgressEntity.self,
        FolderEntity.self,
        TranslatedPageRecord.self,
    configurations: config
)
```

- [ ] **Step 3: Build PersistenceKit + run existing tests to catch migration errors**

```bash
tuist test PersistenceKit
```
Expected: all existing tests PASS. The new model is additive — SwiftData will auto-migrate.

- [ ] **Step 4: Commit**

```bash
git add Data/PersistenceKit/Sources/SwiftDataModels.swift Data/PersistenceKit/Sources/SwiftDataStack.swift
git commit -m "feat(persistence): add TranslatedPageRecord SwiftData model"
```

---

## Task 6: PersistenceKit — `TranslationCacheLive` + tests

**Files:**
- Create: `Data/PersistenceKit/Sources/TranslationCacheLive.swift`
- Create: `Data/PersistenceKit/Tests/TranslationCacheLiveTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Data/PersistenceKit/Tests/TranslationCacheLiveTests.swift
import Testing
import Foundation
import CoreGraphics
import SwiftData
import Domain
@testable import PersistenceKit

@MainActor
@Suite struct TranslationCacheLiveTests {

    private func makeCache() throws -> TranslationCacheLive {
        let stack = try SwiftDataStack.inMemory()
        return TranslationCacheLive(stack: stack)
    }

    private func makePage(_ comicId: UUID, _ pageIndex: Int, target: String = "ko") -> TranslatedPage {
        let box = TextLineBox(id: UUID(), text: "こんにちは",
                              boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1),
                              confidence: 0.9)
        let line = TranslatedLine(original: box, translated: "안녕", backgroundColorARGB: 0xFFFFFFFF)
        return TranslatedPage(
            comicId: comicId, pageIndex: pageIndex,
            sourceLanguage: "ja", targetLanguage: target,
            lines: [line], createdAt: Date()
        )
    }

    @Test func saveAndLoadRoundTrip() async throws {
        let cache = try makeCache()
        let comicId = UUID()
        let page = makePage(comicId, 5)
        try await cache.save(page)

        let loaded = await cache.load(comicId: comicId, pageIndex: 5, targetLanguage: "ko")
        #expect(loaded == page)
    }

    @Test func loadMissReturnsNil() async throws {
        let cache = try makeCache()
        let result = await cache.load(comicId: UUID(), pageIndex: 0, targetLanguage: "ko")
        #expect(result == nil)
    }

    @Test func saveOverwritesByCompositeKey() async throws {
        let cache = try makeCache()
        let comicId = UUID()
        try await cache.save(makePage(comicId, 0))

        let newer = TranslatedPage(
            comicId: comicId, pageIndex: 0,
            sourceLanguage: "ja", targetLanguage: "ko",
            lines: [], createdAt: Date()
        )
        try await cache.save(newer)
        let loaded = await cache.load(comicId: comicId, pageIndex: 0, targetLanguage: "ko")
        #expect(loaded?.lines.isEmpty == true)
    }

    @Test func deleteAllForComicScopesToThatComic() async throws {
        let cache = try makeCache()
        let a = UUID(), b = UUID()
        try await cache.save(makePage(a, 0))
        try await cache.save(makePage(a, 1))
        try await cache.save(makePage(b, 0))

        try await cache.deleteAll(comicId: a)

        #expect(await cache.load(comicId: a, pageIndex: 0, targetLanguage: "ko") == nil)
        #expect(await cache.load(comicId: a, pageIndex: 1, targetLanguage: "ko") == nil)
        #expect(await cache.load(comicId: b, pageIndex: 0, targetLanguage: "ko") != nil)
    }

    @Test func deleteEverythingClearsAll() async throws {
        let cache = try makeCache()
        try await cache.save(makePage(UUID(), 0))
        try await cache.save(makePage(UUID(), 0))

        try await cache.deleteEverything()

        let comicId = UUID()
        #expect(await cache.load(comicId: comicId, pageIndex: 0, targetLanguage: "ko") == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
tuist test PersistenceKit --test-targets PersistenceKitTests/TranslationCacheLiveTests
```
Expected: build failure ("TranslationCacheLive not found").

- [ ] **Step 3: Implement `TranslationCacheLive`**

```swift
// Data/PersistenceKit/Sources/TranslationCacheLive.swift
import Foundation
import SwiftData
import Domain

public actor TranslationCacheLive: TranslationCache {
    private let stack: SwiftDataStack
    private lazy var context: ModelContext = ModelContext(stack.container)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(stack: SwiftDataStack) {
        self.stack = stack
    }

    public func load(comicId: UUID, pageIndex: Int, targetLanguage: String) async -> TranslatedPage? {
        let key = TranslatedPageRecord.compositeKey(
            comicId: comicId, pageIndex: pageIndex, targetLanguage: targetLanguage
        )
        let predicate = #Predicate<TranslatedPageRecord> { $0.key == key }
        var descriptor = FetchDescriptor<TranslatedPageRecord>(predicate: predicate)
        descriptor.fetchLimit = 1
        guard
            let record = try? context.fetch(descriptor).first,
            let lines = try? decoder.decode([TranslatedLine].self, from: record.linesJSON)
        else { return nil }

        return TranslatedPage(
            comicId: record.comicId,
            pageIndex: record.pageIndex,
            sourceLanguage: record.sourceLanguage,
            targetLanguage: record.targetLanguage,
            lines: lines,
            createdAt: record.createdAt
        )
    }

    public func save(_ page: TranslatedPage) async throws {
        let key = TranslatedPageRecord.compositeKey(
            comicId: page.comicId, pageIndex: page.pageIndex, targetLanguage: page.targetLanguage
        )
        let predicate = #Predicate<TranslatedPageRecord> { $0.key == key }
        let descriptor = FetchDescriptor<TranslatedPageRecord>(predicate: predicate)
        let existing = try context.fetch(descriptor)
        for record in existing {
            context.delete(record)
        }

        let json = try encoder.encode(page.lines)
        let record = TranslatedPageRecord(
            comicId: page.comicId,
            pageIndex: page.pageIndex,
            targetLanguage: page.targetLanguage,
            sourceLanguage: page.sourceLanguage,
            linesJSON: json,
            createdAt: page.createdAt
        )
        context.insert(record)
        try context.save()
    }

    public func deleteAll(comicId: UUID) async throws {
        let predicate = #Predicate<TranslatedPageRecord> { $0.comicId == comicId }
        let descriptor = FetchDescriptor<TranslatedPageRecord>(predicate: predicate)
        for record in try context.fetch(descriptor) {
            context.delete(record)
        }
        try context.save()
    }

    public func deleteEverything() async throws {
        let descriptor = FetchDescriptor<TranslatedPageRecord>()
        for record in try context.fetch(descriptor) {
            context.delete(record)
        }
        try context.save()
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
tuist test PersistenceKit --test-targets PersistenceKitTests/TranslationCacheLiveTests
```
Expected: 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Data/PersistenceKit/Sources/TranslationCacheLive.swift Data/PersistenceKit/Tests/TranslationCacheLiveTests.swift
git commit -m "feat(persistence): add TranslationCacheLive backed by SwiftData"
```

---

## Task 7: `IntelligenceKit` module scaffold

**Files:**
- Create: `Data/IntelligenceKit/Project.swift`
- Create: `Data/IntelligenceKit/Sources/.gitkeep` (temporary; deleted in next task)
- Modify: `Workspace.swift`

- [ ] **Step 1: Create the Tuist project descriptor**

```swift
// Data/IntelligenceKit/Project.swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "IntelligenceKit",
    kind: .data,
    dependencies: [.project(target: "Domain", path: "../../Domain")],
    hasTests: true
).project()
```

- [ ] **Step 2: Add the new project to the workspace**

Modify `Workspace.swift`:

```swift
import ProjectDescription

let workspace = Workspace(
    name: "Mana",
    projects: [
        "App",
        "Features/AppFeature",
        "Features/LibraryFeature",
        "Features/ReaderFeature",
        "Features/SettingsFeature",
        "Domain",
        "Data/ArchiveKit",
        "Data/ImageCacheKit",
        "Data/IntelligenceKit",
        "Data/PersistenceKit",
        "Data/ThumbnailKit",
        "DesignSystem",
        "SharedUI"
    ]
)
```

- [ ] **Step 3: Add a placeholder source so Tuist accepts the project**

```bash
mkdir -p Data/IntelligenceKit/Sources Data/IntelligenceKit/Tests
touch Data/IntelligenceKit/Sources/.gitkeep
```

Add a temporary Swift source so the framework target compiles to something:

```swift
// Data/IntelligenceKit/Sources/_Placeholder.swift
// Deleted in the next task. Tuist requires at least one source per target.
@_documentation(visibility: internal)
internal enum _IntelligenceKitPlaceholder {}
```

Also seed an empty test file so the test target compiles:

```swift
// Data/IntelligenceKit/Tests/_PlaceholderTests.swift
import Testing
@testable import IntelligenceKit

@Suite struct _PlaceholderTests {
    @Test func placeholder() { #expect(true) }
}
```

- [ ] **Step 4: Regenerate workspace and verify build**

```bash
tuist generate
tuist test IntelligenceKit
```
Expected: workspace regenerates cleanly, placeholder test PASSES.

- [ ] **Step 5: Commit**

```bash
git add Workspace.swift Data/IntelligenceKit
git commit -m "feat(intelligence): scaffold IntelligenceKit module"
```

---

## Task 8: IntelligenceKit fallback types

**Files:**
- Create: `Data/IntelligenceKit/Sources/UnavailableIntelligence.swift`
- Create: `Data/IntelligenceKit/Sources/NoopPageTranslator.swift`
- Create: `Data/IntelligenceKit/Sources/InMemoryTranslationCache.swift`
- Delete: `Data/IntelligenceKit/Sources/_Placeholder.swift`

These fallback implementations are also used as `testValue` for the dependency keys defined in Task 17.

- [ ] **Step 1: Create the unavailable availability**

```swift
// Data/IntelligenceKit/Sources/UnavailableIntelligence.swift
import Foundation
import Domain

public struct UnavailableIntelligence: IntelligenceAvailability {
    public let isAvailable: Bool = false
    public init() {}
}
```

- [ ] **Step 2: Create the no-op translator**

```swift
// Data/IntelligenceKit/Sources/NoopPageTranslator.swift
import Foundation
import Domain

public struct NoopPageTranslator: PageTranslator {
    public init() {}

    public func translate(
        imageData: Data,
        comicId: UUID,
        pageIndex: Int,
        targetLanguage: String
    ) async throws -> TranslatedPage {
        TranslatedPage(
            comicId: comicId, pageIndex: pageIndex,
            sourceLanguage: "und", targetLanguage: targetLanguage,
            lines: [], createdAt: Date()
        )
    }
}
```

- [ ] **Step 3: Create the in-memory cache (for tests)**

```swift
// Data/IntelligenceKit/Sources/InMemoryTranslationCache.swift
import Foundation
import Domain

public actor InMemoryTranslationCache: TranslationCache {
    private var pages: [String: TranslatedPage] = [:]

    public init() {}

    private func key(_ comicId: UUID, _ pageIndex: Int, _ target: String) -> String {
        "\(comicId.uuidString)|\(pageIndex)|\(target)"
    }

    public func load(comicId: UUID, pageIndex: Int, targetLanguage: String) async -> TranslatedPage? {
        pages[key(comicId, pageIndex, targetLanguage)]
    }

    public func save(_ page: TranslatedPage) async throws {
        pages[key(page.comicId, page.pageIndex, page.targetLanguage)] = page
    }

    public func deleteAll(comicId: UUID) async throws {
        pages = pages.filter { $0.value.comicId != comicId }
    }

    public func deleteEverything() async throws {
        pages.removeAll()
    }
}
```

- [ ] **Step 4: Remove the placeholder source and test**

```bash
rm Data/IntelligenceKit/Sources/_Placeholder.swift
rm Data/IntelligenceKit/Tests/_PlaceholderTests.swift
```

- [ ] **Step 5: Build/test**

```bash
tuist generate
tuist test IntelligenceKit
```
Expected: zero tests (nothing yet), but target compiles cleanly.

- [ ] **Step 6: Commit**

```bash
git add Data/IntelligenceKit
git commit -m "feat(intelligence): add unavailable/no-op/in-memory fallbacks"
```

---

## Task 9: IntelligenceKit — `LanguageDetector` + tests

**Files:**
- Create: `Data/IntelligenceKit/Sources/LanguageDetector.swift`
- Create: `Data/IntelligenceKit/Tests/LanguageDetectorTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Data/IntelligenceKit/Tests/LanguageDetectorTests.swift
import Testing
import Foundation
@testable import IntelligenceKit

@Suite struct LanguageDetectorTests {
    private let detector = LanguageDetector()

    @Test func detectsJapaneseHiragana() {
        let lang = detector.detect("こんにちは、元気ですか？")
        #expect(lang == "ja")
    }

    @Test func detectsKorean() {
        let lang = detector.detect("안녕하세요. 오늘 날씨가 좋네요.")
        #expect(lang == "ko")
    }

    @Test func detectsEnglish() {
        let lang = detector.detect("Hello there, how are you doing today?")
        #expect(lang == "en")
    }

    @Test func returnsUndForEmpty() {
        #expect(detector.detect("") == "und")
    }

    @Test func returnsUndForOnlyPunctuation() {
        let lang = detector.detect("!!!???")
        #expect(lang == "und")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
tuist test IntelligenceKit --test-targets IntelligenceKitTests/LanguageDetectorTests
```
Expected: build failure ("LanguageDetector not found").

- [ ] **Step 3: Implement the detector**

```swift
// Data/IntelligenceKit/Sources/LanguageDetector.swift
import Foundation
import NaturalLanguage

public struct LanguageDetector: Sendable {
    public init() {}

    /// Detects the dominant language of `text`, constrained to {ja, ko, en}.
    /// Returns BCP-47: "ja", "ko", "en", or "und" if no signal exists or the
    /// result falls outside the constraint set.
    public func detect(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "und" }

        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.japanese, .korean, .english]
        recognizer.processString(trimmed)

        guard let lang = recognizer.dominantLanguage else { return "und" }
        switch lang {
        case .japanese: return "ja"
        case .korean:   return "ko"
        case .english:  return "en"
        default:        return "und"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
tuist test IntelligenceKit --test-targets IntelligenceKitTests/LanguageDetectorTests
```
Expected: 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Data/IntelligenceKit/Sources/LanguageDetector.swift Data/IntelligenceKit/Tests/LanguageDetectorTests.swift
git commit -m "feat(intelligence): add LanguageDetector constrained to ja/ko/en"
```

---

## Task 10: IntelligenceKit — `BackgroundColorSampler` + tests

**Files:**
- Create: `Data/IntelligenceKit/Sources/BackgroundColorSampler.swift`
- Create: `Data/IntelligenceKit/Tests/BackgroundColorSamplerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Data/IntelligenceKit/Tests/BackgroundColorSamplerTests.swift
import Testing
import Foundation
import CoreGraphics
import UIKit
@testable import IntelligenceKit

@MainActor
@Suite struct BackgroundColorSamplerTests {

    /// Makes an opaque 100x100 PNG of a single solid color.
    private func solidImageData(red: CGFloat, green: CGFloat, blue: CGFloat) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let img = renderer.image { ctx in
            UIColor(red: red, green: green, blue: blue, alpha: 1.0).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        return img.pngData()!
    }

    @Test func samplesSolidWhite() {
        let data = solidImageData(red: 1, green: 1, blue: 1)
        let sampler = BackgroundColorSampler()
        let bbox = CGRect(x: 0.3, y: 0.3, width: 0.2, height: 0.2)
        let argb = sampler.sample(imageData: data, normalizedBox: bbox)
        // alpha=FF, r≈FF, g≈FF, b≈FF — allow ±4 per channel for sRGB rounding.
        #expect((argb >> 24) & 0xFF == 0xFF)
        #expect(((argb >> 16) & 0xFF) > 0xF8)
        #expect(((argb >>  8) & 0xFF) > 0xF8)
        #expect((argb        & 0xFF) > 0xF8)
    }

    @Test func samplesSolidRed() {
        let data = solidImageData(red: 1, green: 0, blue: 0)
        let sampler = BackgroundColorSampler()
        let argb = sampler.sample(imageData: data, normalizedBox: CGRect(x: 0.1, y: 0.1, width: 0.1, height: 0.1))
        let r = (argb >> 16) & 0xFF
        let g = (argb >>  8) & 0xFF
        let b = argb         & 0xFF
        #expect(r > 0xF0)
        #expect(g < 0x10)
        #expect(b < 0x10)
    }

    @Test func emptyImageFallsBackToPaperColor() {
        let sampler = BackgroundColorSampler()
        let argb = sampler.sample(imageData: Data(), normalizedBox: .zero)
        // Fallback is opaque off-white.
        #expect((argb >> 24) & 0xFF == 0xFF)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
tuist test IntelligenceKit --test-targets IntelligenceKitTests/BackgroundColorSamplerTests
```
Expected: build failure ("BackgroundColorSampler not found").

- [ ] **Step 3: Implement the sampler**

```swift
// Data/IntelligenceKit/Sources/BackgroundColorSampler.swift
import Foundation
import CoreGraphics
import UIKit

public struct BackgroundColorSampler: Sendable {
    /// Opaque paper-ish fallback (ARGB 0xFFF6F3EC) used when the bbox cannot
    /// be sampled — keeps the overlay readable instead of going transparent.
    public static let fallbackARGB: UInt32 = 0xFFF6F3EC

    public init() {}

    /// Samples a single representative color from a thin ring just outside the
    /// normalized bbox. Sampling outside the text rather than inside avoids
    /// picking up the ink color.
    public func sample(imageData: Data, normalizedBox: CGRect) -> UInt32 {
        guard
            let image = UIImage(data: imageData),
            let cg = image.cgImage,
            cg.width > 0, cg.height > 0
        else { return Self.fallbackARGB }

        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        // Convert Vision (origin bottom-left) → image-space (origin top-left).
        let imgRect = CGRect(
            x: normalizedBox.minX * w,
            y: (1 - normalizedBox.maxY) * h,
            width: normalizedBox.width * w,
            height: normalizedBox.height * h
        )
        // Sample a 4-pixel ring outside the bbox, clamped to image bounds.
        let inset: CGFloat = -4
        let outer = imgRect.insetBy(dx: inset, dy: inset)
            .intersection(CGRect(x: 0, y: 0, width: w, height: h))
        guard !outer.isNull, outer.width >= 1, outer.height >= 1 else {
            return Self.fallbackARGB
        }

        // Downscale the ring to a single 1x1 pixel — fastest reliable average.
        let bytesPerRow = 4
        var pixel: [UInt8] = [0, 0, 0, 0]
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return Self.fallbackARGB }
        let info: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let ctx = CGContext(
            data: &pixel,
            width: 1, height: 1, bitsPerComponent: 8,
            bytesPerRow: bytesPerRow, space: space, bitmapInfo: info
        ) else { return Self.fallbackARGB }
        ctx.interpolationQuality = .medium
        // Draw the cropped region into the 1x1 context.
        if let cropped = cg.cropping(to: outer) {
            ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        let r = UInt32(pixel[0]), g = UInt32(pixel[1]), b = UInt32(pixel[2])
        // Force alpha to 0xFF — overlay must be opaque.
        return (0xFF << 24) | (r << 16) | (g << 8) | b
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
tuist test IntelligenceKit --test-targets IntelligenceKitTests/BackgroundColorSamplerTests
```
Expected: 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Data/IntelligenceKit/Sources/BackgroundColorSampler.swift Data/IntelligenceKit/Tests/BackgroundColorSamplerTests.swift
git commit -m "feat(intelligence): add BackgroundColorSampler"
```

---

## Task 11: IntelligenceKit — `VisionTextRecognizer` + tests

**Files:**
- Create: `Data/IntelligenceKit/Sources/VisionTextRecognizer.swift`
- Create: `Data/IntelligenceKit/Tests/VisionTextRecognizerTests.swift`

- [ ] **Step 1: Write the failing test**

The test synthesizes a small PNG containing Korean text (no fixture binary committed). OCR on Apple platforms is reliable enough for printed system-font Korean that this is deterministic. We test Korean rather than Japanese here purely because system fonts render Korean glyphs at small sizes more reliably across SDKs.

```swift
// Data/IntelligenceKit/Tests/VisionTextRecognizerTests.swift
import Testing
import Foundation
import UIKit
@testable import IntelligenceKit

@MainActor
@Suite struct VisionTextRecognizerTests {

    private func textImagePNG(_ text: String, size: CGSize = CGSize(width: 400, height: 120)) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let attr = NSAttributedString(string: text, attributes: attrs)
            attr.draw(at: CGPoint(x: 20, y: 30))
        }
        return img.pngData()!
    }

    @Test func recognizesRenderedKorean() async throws {
        let data = textImagePNG("안녕하세요")
        let recognizer = VisionTextRecognizer()
        let boxes = try await recognizer.recognize(imageData: data)
        #expect(!boxes.isEmpty)
        let joined = boxes.map(\.text).joined()
        #expect(joined.contains("안녕"))
    }

    @Test func returnsEmptyForBlankImage() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let blank = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        let data = blank.pngData()!
        let recognizer = VisionTextRecognizer()
        let boxes = try await recognizer.recognize(imageData: data)
        #expect(boxes.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
tuist test IntelligenceKit --test-targets IntelligenceKitTests/VisionTextRecognizerTests
```
Expected: build failure ("VisionTextRecognizer not found").

- [ ] **Step 3: Implement the recognizer**

```swift
// Data/IntelligenceKit/Sources/VisionTextRecognizer.swift
import Foundation
import Vision
import UIKit
import Domain

public struct VisionTextRecognizer: Sendable {
    public init() {}

    public func recognize(imageData: Data) async throws -> [TextLineBox] {
        guard let uiImage = UIImage(data: imageData), let cg = uiImage.cgImage else {
            return []
        }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
                let lines: [TextLineBox] = observations.compactMap { obs in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    return TextLineBox(
                        id: UUID(),
                        text: candidate.string,
                        boundingBox: obs.boundingBox,  // Vision normalized, bottom-left origin
                        confidence: candidate.confidence
                    )
                }
                continuation.resume(returning: lines)
            }
            request.recognitionLanguages = ["ja", "ko", "en"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
tuist test IntelligenceKit --test-targets IntelligenceKitTests/VisionTextRecognizerTests
```
Expected: 2 tests PASS. (If Korean recognition is flaky on the simulator, swap to "Hello" — the assertion logic is identical.)

- [ ] **Step 5: Commit**

```bash
git add Data/IntelligenceKit/Sources/VisionTextRecognizer.swift Data/IntelligenceKit/Tests/VisionTextRecognizerTests.swift
git commit -m "feat(intelligence): add VisionTextRecognizer for ja/ko/en"
```

---

## Task 12: IntelligenceKit — `LLMTranslator` protocol + `FoundationModelsTranslator`

**Files:**
- Create: `Data/IntelligenceKit/Sources/LLMTranslator.swift`
- Create: `Data/IntelligenceKit/Sources/FoundationModelsTranslator.swift`

`LLMTranslator` is an internal seam so `PageTranslatorLive` (Task 13) can be tested with a fake.

- [ ] **Step 1: Define the internal protocol**

```swift
// Data/IntelligenceKit/Sources/LLMTranslator.swift
import Foundation

/// Internal seam over the on-device LLM so PageTranslatorLive can be tested
/// without a real Foundation Models call.
package protocol LLMTranslator: Sendable {
    /// Translates `lines` from `source` (BCP-47) to `target` (BCP-47).
    /// MUST return an array of the same length as `lines`.
    /// Throws `LLMTranslatorError.protocolViolation` on count mismatch /
    /// parse failure, or rethrows underlying model errors.
    func translateLines(_ lines: [String], from source: String, to target: String) async throws -> [String]
}

package enum LLMTranslatorError: Error, Sendable {
    case protocolViolation
    case modelUnavailable
}
```

- [ ] **Step 2: Implement the Foundation Models translator (iOS 26 gated)**

```swift
// Data/IntelligenceKit/Sources/FoundationModelsTranslator.swift
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

@available(iOS 26.0, *)
package struct FoundationModelsTranslator: LLMTranslator {
    package init() {}

    @Generable
    private struct TranslationResponse {
        let lines: [String]
    }

    package func translateLines(_ lines: [String], from source: String, to target: String) async throws -> [String] {
        guard !lines.isEmpty else { return [] }
        let instructions = """
        You translate manga dialogue from \(humanReadable(source)) to \(humanReadable(target)).
        Rules:
        - Source language is one of: Japanese, Korean, English.
        - Target language is one of: Japanese, Korean, English.
        - Translate each line independently. Preserve speaker tone.
        - Keep onomatopoeia (e.g. ドキドキ) untranslated; copy them verbatim.
        - Do not merge or split lines.
        - Output an array `lines` of the same length as the input.
        """

        let inputJSON: String
        do {
            let data = try JSONEncoder().encode(["lines": lines])
            inputJSON = String(decoding: data, as: UTF8.self)
        } catch {
            throw LLMTranslatorError.protocolViolation
        }

        let session = LanguageModelSession(
            model: SystemLanguageModel.default,
            instructions: instructions
        )
        let response: LanguageModelSession.Response<TranslationResponse>
        do {
            response = try await session.respond(
                to: "Input: \(inputJSON)\nReturn JSON only.",
                generating: TranslationResponse.self
            )
        } catch {
            throw LLMTranslatorError.modelUnavailable
        }

        let translated = response.content.lines
        guard translated.count == lines.count else {
            throw LLMTranslatorError.protocolViolation
        }
        return translated
    }

    private func humanReadable(_ bcp47: String) -> String {
        switch bcp47 {
        case "ja": return "Japanese"
        case "ko": return "Korean"
        case "en": return "English"
        default:   return bcp47
        }
    }
}
```

- [ ] **Step 3: Verify it compiles**

```bash
tuist generate
xcodebuild build -workspace Mana.xcworkspace -scheme IntelligenceKit -destination 'generic/platform=iOS' -quiet
```
Expected: succeeds.

> Note: there is intentionally no unit test for `FoundationModelsTranslator` — it requires a device with Apple Intelligence enabled. Task 13 tests `PageTranslatorLive` against a fake `LLMTranslator`.

- [ ] **Step 4: Commit**

```bash
git add Data/IntelligenceKit/Sources/LLMTranslator.swift Data/IntelligenceKit/Sources/FoundationModelsTranslator.swift
git commit -m "feat(intelligence): add LLMTranslator seam and Foundation Models impl"
```

---

## Task 13: IntelligenceKit — `PageTranslatorLive` + tests

**Files:**
- Create: `Data/IntelligenceKit/Sources/PageTranslatorLive.swift`
- Create: `Data/IntelligenceKit/Tests/PageTranslatorLiveTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Data/IntelligenceKit/Tests/PageTranslatorLiveTests.swift
import Testing
import Foundation
import CoreGraphics
import UIKit
import Domain
@testable import IntelligenceKit

@MainActor
@Suite struct PageTranslatorLiveTests {

    private func textImagePNG(_ text: String) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 120))
        let img = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 120))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            NSAttributedString(string: text, attributes: attrs)
                .draw(at: CGPoint(x: 20, y: 30))
        }
        return img.pngData()!
    }

    private final class FakeLLM: LLMTranslator, @unchecked Sendable {
        var calls: [(source: String, target: String, lines: [String])] = []
        var nextResponse: ([String]) -> [String] = { $0.map { "[T] " + $0 } }
        var nextError: LLMTranslatorError?

        func translateLines(_ lines: [String], from source: String, to target: String) async throws -> [String] {
            calls.append((source, target, lines))
            if let err = nextError { throw err }
            return nextResponse(lines)
        }
    }

    @Test func translatesWhenSourceDiffersFromTarget() async throws {
        let llm = FakeLLM()
        let translator = PageTranslatorLive(llm: llm)
        let data = textImagePNG("안녕하세요")

        let page = try await translator.translate(
            imageData: data, comicId: UUID(), pageIndex: 0, targetLanguage: "ja"
        )

        #expect(!page.lines.isEmpty)
        #expect(page.targetLanguage == "ja")
        #expect(page.sourceLanguage == "ko")
        #expect(llm.calls.count == 1)
        #expect(llm.calls.first?.target == "ja")
        // First line's translated value starts with the fake prefix.
        #expect(page.lines.first?.translated.hasPrefix("[T] ") == true)
    }

    @Test func skipsLLMWhenSourceEqualsTarget() async throws {
        let llm = FakeLLM()
        let translator = PageTranslatorLive(llm: llm)
        let data = textImagePNG("안녕하세요")

        let page = try await translator.translate(
            imageData: data, comicId: UUID(), pageIndex: 0, targetLanguage: "ko"
        )

        #expect(page.lines.isEmpty)
        #expect(page.sourceLanguage == "ko")
        #expect(llm.calls.isEmpty)
    }

    @Test func emptyOCRReturnsEmptyPage() async throws {
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
            .image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            }.pngData()!

        let llm = FakeLLM()
        let translator = PageTranslatorLive(llm: llm)
        let page = try await translator.translate(
            imageData: blank, comicId: UUID(), pageIndex: 0, targetLanguage: "ko"
        )
        #expect(page.lines.isEmpty)
        #expect(llm.calls.isEmpty)
    }

    @Test func llmFailureBubblesAsSilentFailure() async throws {
        let llm = FakeLLM()
        llm.nextError = .protocolViolation
        let translator = PageTranslatorLive(llm: llm)
        let data = textImagePNG("안녕하세요")

        do {
            _ = try await translator.translate(
                imageData: data, comicId: UUID(), pageIndex: 0, targetLanguage: "ja"
            )
            Issue.record("expected silent failure")
        } catch PageTranslatorError.silentFailure {
            // expected
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
tuist test IntelligenceKit --test-targets IntelligenceKitTests/PageTranslatorLiveTests
```
Expected: build failure ("PageTranslatorLive not found").

- [ ] **Step 3: Implement `PageTranslatorLive`**

```swift
// Data/IntelligenceKit/Sources/PageTranslatorLive.swift
import Foundation
import os
import Domain

public struct PageTranslatorLive: PageTranslator {
    private let ocr: VisionTextRecognizer
    private let detector: LanguageDetector
    private let llm: any LLMTranslator
    private let sampler: BackgroundColorSampler
    private static let log = Logger(subsystem: "com.coby.mana", category: "translation")

    package init(
        ocr: VisionTextRecognizer = VisionTextRecognizer(),
        detector: LanguageDetector = LanguageDetector(),
        sampler: BackgroundColorSampler = BackgroundColorSampler(),
        llm: any LLMTranslator
    ) {
        self.ocr = ocr
        self.detector = detector
        self.sampler = sampler
        self.llm = llm
    }

    public func translate(
        imageData: Data,
        comicId: UUID,
        pageIndex: Int,
        targetLanguage: String
    ) async throws -> TranslatedPage {
        // 1) OCR
        let boxes: [TextLineBox]
        do {
            boxes = try await ocr.recognize(imageData: imageData)
        } catch {
            Self.log.error("OCR failed: \(error.localizedDescription, privacy: .public)")
            throw PageTranslatorError.silentFailure
        }
        if boxes.isEmpty {
            return TranslatedPage(
                comicId: comicId, pageIndex: pageIndex,
                sourceLanguage: "und", targetLanguage: targetLanguage,
                lines: [], createdAt: Date()
            )
        }

        // 2) Language detection. Spec §6: if detection fails ("und"), treat as Japanese.
        let joined = boxes.map(\.text).joined(separator: "\n")
        let raw = detector.detect(joined)
        let source = (raw == "und") ? "ja" : raw
        if source == targetLanguage {
            return TranslatedPage(
                comicId: comicId, pageIndex: pageIndex,
                sourceLanguage: source, targetLanguage: targetLanguage,
                lines: [], createdAt: Date()
            )
        }

        // 3) LLM
        let inputs = boxes.map(\.text)
        let translated: [String]
        do {
            translated = try await llm.translateLines(inputs, from: source, to: targetLanguage)
        } catch {
            Self.log.error("LLM failure: \(error.localizedDescription, privacy: .public)")
            throw PageTranslatorError.silentFailure
        }
        guard translated.count == boxes.count else {
            throw PageTranslatorError.silentFailure
        }

        // 4) Background sample + assemble
        let lines: [TranslatedLine] = zip(boxes, translated).map { box, t in
            let argb = sampler.sample(imageData: imageData, normalizedBox: box.boundingBox)
            return TranslatedLine(original: box, translated: t, backgroundColorARGB: argb)
        }
        return TranslatedPage(
            comicId: comicId, pageIndex: pageIndex,
            sourceLanguage: source, targetLanguage: targetLanguage,
            lines: lines, createdAt: Date()
        )
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
tuist test IntelligenceKit --test-targets IntelligenceKitTests/PageTranslatorLiveTests
```
Expected: 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Data/IntelligenceKit/Sources/PageTranslatorLive.swift Data/IntelligenceKit/Tests/PageTranslatorLiveTests.swift
git commit -m "feat(intelligence): add PageTranslatorLive composing OCR + detector + LLM + sampler"
```

---

## Task 14: IntelligenceKit — `IntelligenceAvailabilityLive` + `TargetLanguageResolver`

**Files:**
- Create: `Data/IntelligenceKit/Sources/IntelligenceAvailabilityLive.swift`
- Create: `Data/IntelligenceKit/Sources/TargetLanguageResolver.swift`

- [ ] **Step 1: Implement the live availability**

```swift
// Data/IntelligenceKit/Sources/IntelligenceAvailabilityLive.swift
import Foundation
import Domain
#if canImport(FoundationModels)
import FoundationModels
#endif

@available(iOS 26.0, *)
public struct IntelligenceAvailabilityLive: IntelligenceAvailability {
    public init() {}

    public var isAvailable: Bool {
        switch SystemLanguageModel.default.availability {
        case .available:
            return true
        case .unavailable:
            return false
        }
    }
}
```

- [ ] **Step 2: Implement the target language resolver**

```swift
// Data/IntelligenceKit/Sources/TargetLanguageResolver.swift
import Foundation

public enum TargetLanguageResolver {
    /// Maps `AppLanguage`-equivalent raw string to a translation target.
    /// `.system` and any out-of-set value fall back to the development region (ko).
    public static func resolve(appLanguageRawValue raw: String) -> String {
        switch raw {
        case "ko": return "ko"
        case "ja": return "ja"
        case "en": return "en"
        case "system":
            let preferred = Bundle.main.preferredLocalizations.first ?? "ko"
            switch preferred {
            case "ko": return "ko"
            case "ja": return "ja"
            case "en": return "en"
            default:   return "ko"
            }
        default:
            return "ko"
        }
    }
}
```

- [ ] **Step 3: Build IntelligenceKit**

```bash
tuist test IntelligenceKit
```
Expected: all previously passing tests continue to PASS, no new failures.

- [ ] **Step 4: Commit**

```bash
git add Data/IntelligenceKit/Sources/IntelligenceAvailabilityLive.swift Data/IntelligenceKit/Sources/TargetLanguageResolver.swift
git commit -m "feat(intelligence): add live availability check and target language resolver"
```

---

## Task 15: SettingsFeature — `autoTranslateEnabled` reducer state + tests

**Files:**
- Modify: `Features/SettingsFeature/Sources/SettingsFeature.swift`
- Modify: `Features/SettingsFeature/Tests/SettingsFeatureTests.swift`

- [ ] **Step 1: Add the new state, action, and persistence key**

In `Features/SettingsFeature/Sources/SettingsFeature.swift`:

Inside `State`:
```swift
public var isIntelligenceAvailable: Bool
public var autoTranslateEnabled: Bool
```

Update the initializer:
```swift
public init(
    defaultMode: ReadingMode = .single,
    defaultPageProgressionDirection: PageProgressionDirection = .leftToRight,
    defaultPageOffset: Bool = false,
    appLanguage: AppLanguage = .system,
    isIntelligenceAvailable: Bool = false,
    autoTranslateEnabled: Bool = false
) {
    self.defaultMode = defaultMode
    self.defaultPageProgressionDirection = defaultPageProgressionDirection
    self.defaultPageOffset = defaultPageOffset
    self.appLanguage = appLanguage
    self.isIntelligenceAvailable = isIntelligenceAvailable
    self.autoTranslateEnabled = autoTranslateEnabled
}
```

Add to `Action`:
```swift
case autoTranslateChanged(Bool)
```

Add a key constant alongside the existing ones:
```swift
public static let autoTranslateKey = "mana.autoTranslateEnabled"
```

In `.task` handling, append (just before the `return .none`):
```swift
if state.isIntelligenceAvailable,
   let raw = defaults.string(forKey: Self.autoTranslateKey) {
    state.autoTranslateEnabled = (raw == "true")
} else {
    state.autoTranslateEnabled = false
}
```

Add a new case alongside the other persistence handlers:
```swift
case let .autoTranslateChanged(enabled):
    state.autoTranslateEnabled = enabled
    defaults.set(enabled ? "true" : "false", forKey: Self.autoTranslateKey)
    return .none
```

- [ ] **Step 2: Add unit tests**

Append to `Features/SettingsFeature/Tests/SettingsFeatureTests.swift`:

```swift
@Test func autoTranslateDefaultsToFalse() async {
    let store = await TestStore(
        initialState: SettingsFeature.State(isIntelligenceAvailable: true)
    ) { SettingsFeature() } withDependencies: {
        $0.userDefaults = InMemoryUserDefaults()
    }
    await store.send(.task)
    #expect(store.state.autoTranslateEnabled == false)
}

@Test func autoTranslateLoadsPersistedTrue() async {
    let defaults = InMemoryUserDefaults()
    defaults.set("true", forKey: SettingsFeature.autoTranslateKey)
    let store = await TestStore(
        initialState: SettingsFeature.State(isIntelligenceAvailable: true)
    ) { SettingsFeature() } withDependencies: {
        $0.userDefaults = defaults
    }
    await store.send(.task) {
        $0.autoTranslateEnabled = true
    }
}

@Test func autoTranslateIgnoresPersistedValueWhenUnavailable() async {
    let defaults = InMemoryUserDefaults()
    defaults.set("true", forKey: SettingsFeature.autoTranslateKey)
    let store = await TestStore(
        initialState: SettingsFeature.State(isIntelligenceAvailable: false)
    ) { SettingsFeature() } withDependencies: {
        $0.userDefaults = defaults
    }
    await store.send(.task)
    #expect(store.state.autoTranslateEnabled == false)
}

@Test func autoTranslateChangedPersists() async {
    let defaults = InMemoryUserDefaults()
    let store = await TestStore(
        initialState: SettingsFeature.State(isIntelligenceAvailable: true)
    ) { SettingsFeature() } withDependencies: {
        $0.userDefaults = defaults
    }
    await store.send(.autoTranslateChanged(true)) {
        $0.autoTranslateEnabled = true
    }
    #expect(defaults.string(forKey: SettingsFeature.autoTranslateKey) == "true")
}
```

- [ ] **Step 3: Run all SettingsFeature tests**

```bash
tuist test SettingsFeature
```
Expected: all existing + 4 new tests PASS.

- [ ] **Step 4: Commit**

```bash
git add Features/SettingsFeature/Sources/SettingsFeature.swift Features/SettingsFeature/Tests/SettingsFeatureTests.swift
git commit -m "feat(settings): add gated autoTranslate toggle state and reducer"
```

---

## Task 16: SettingsFeature — view section + localized strings

**Files:**
- Modify: `Features/SettingsFeature/Sources/SettingsView.swift`
- Modify: `Features/SettingsFeature/Resources/{ko,ja,en}.lproj/Localizable.strings`

- [ ] **Step 1: Append localized strings to each `.strings` file**

`Features/SettingsFeature/Resources/ko.lproj/Localizable.strings`:
```
"settings.translate.section" = "자동 번역";
"settings.translate.toggle" = "페이지 자동 번역";
"settings.translate.on" = "켜기";
"settings.translate.off" = "끄기";
"settings.translate.description" = "지원되는 기기에서만 표시됩니다.";
```

`Features/SettingsFeature/Resources/ja.lproj/Localizable.strings`:
```
"settings.translate.section" = "自動翻訳";
"settings.translate.toggle" = "ページ自動翻訳";
"settings.translate.on" = "オン";
"settings.translate.off" = "オフ";
"settings.translate.description" = "対応デバイスでのみ表示されます。";
```

`Features/SettingsFeature/Resources/en.lproj/Localizable.strings`:
```
"settings.translate.section" = "Auto translation";
"settings.translate.toggle" = "Translate pages automatically";
"settings.translate.on" = "On";
"settings.translate.off" = "Off";
"settings.translate.description" = "Available on supported devices.";
```

- [ ] **Step 2: Add the gated section to `SettingsView`**

In `Features/SettingsFeature/Sources/SettingsView.swift`, locate the `section(title: localized("settings.general"))` block. Just **after** the closing `}` of that `section(...)` call (and before the next section / language section), insert a new gated section:

```swift
if store.isIntelligenceAvailable {
    section(title: localized("settings.translate.section")) {
        settingRow(
            title: localized("settings.translate.toggle"),
            footer: localized("settings.translate.description")
        ) {
            MangaToggle(
                selection: Binding(
                    get: { store.autoTranslateEnabled },
                    set: { store.send(.autoTranslateChanged($0)) }
                ),
                options: [
                    (false, Text(verbatim: localized("settings.translate.off"))),
                    (true,  Text(verbatim: localized("settings.translate.on")))
                ]
            )
        }
    }
}
```

> If the existing `settingRow(title:footer:content:)` signature differs from what's shown, follow the existing pattern in the file — pass the toggle as the `content` closure and the description as `footer`.

- [ ] **Step 3: Build + smoke run**

```bash
tuist generate
xcodebuild build -workspace Mana.xcworkspace -scheme SettingsFeature -destination 'generic/platform=iOS' -quiet
```
Expected: succeeds.

- [ ] **Step 4: Commit**

```bash
git add Features/SettingsFeature/Sources/SettingsView.swift Features/SettingsFeature/Resources
git commit -m "ui(settings): show gated auto-translate section"
```

---

## Task 17: ReaderFeature — `TranslationState` + dependency keys

**Files:**
- Create: `Features/ReaderFeature/Sources/TranslationDependencyKeys.swift`
- Modify: `Features/ReaderFeature/Sources/ReaderFeature.swift`
- Modify: `Features/ReaderFeature/Project.swift`

- [ ] **Step 1: Update ReaderFeature's Project.swift to depend on IntelligenceKit and PersistenceKit**

> ReaderFeature already depends on `Domain` and `ImageCacheKit`. Confirm by reading the current file; then add:

```swift
.project(target: "IntelligenceKit", path: "../../Data/IntelligenceKit"),
.project(target: "PersistenceKit", path: "../../Data/PersistenceKit"),
```

…to the `dependencies` array in `Features/ReaderFeature/Project.swift`.

> The Live impls (`PageTranslatorLive`, `TranslationCacheLive`) themselves are wired in `App/DependenciesLive`. ReaderFeature consumes them only via dependency keys, but the symbol types (`InMemoryTranslationCache`, `NoopPageTranslator`) come from IntelligenceKit and are used as the keys' `testValue`/placeholder.

- [ ] **Step 2: Create the dependency keys file**

```swift
// Features/ReaderFeature/Sources/TranslationDependencyKeys.swift
import Foundation
import ComposableArchitecture
import Domain
import IntelligenceKit

private enum PageTranslatorKey: DependencyKey {
    static let liveValue: any PageTranslator = NoopPageTranslator()
    static let testValue: any PageTranslator = NoopPageTranslator()
}

private enum TranslationCacheKey: DependencyKey {
    static let liveValue: any TranslationCache = InMemoryTranslationCache()
    static let testValue: any TranslationCache = InMemoryTranslationCache()
}

extension DependencyValues {
    public var pageTranslator: any PageTranslator {
        get { self[PageTranslatorKey.self] }
        set { self[PageTranslatorKey.self] = newValue }
    }
    public var translationCache: any TranslationCache {
        get { self[TranslationCacheKey.self] }
        set { self[TranslationCacheKey.self] = newValue }
    }
}
```

> The live default is `Noop`/in-memory — the real `Live` variants are injected at app start via `prepareDependencies`. This mirrors the existing `ArchiveReaderRouter` placeholder pattern.

- [ ] **Step 3: Extend `ReaderFeature.State` with `TranslationState`**

In `Features/ReaderFeature/Sources/ReaderFeature.swift`, add a nested type and a state field:

```swift
public struct TranslationState: Equatable, Sendable {
    public var isIntelligenceAvailable: Bool
    public var isEnabled: Bool
    public var targetLanguage: String
    public var pagesInFlight: Set<Int>
    public var pages: [Int: TranslatedPage]

    public init(
        isIntelligenceAvailable: Bool = false,
        isEnabled: Bool = false,
        targetLanguage: String = "ko",
        pagesInFlight: Set<Int> = [],
        pages: [Int: TranslatedPage] = [:]
    ) {
        self.isIntelligenceAvailable = isIntelligenceAvailable
        self.isEnabled = isEnabled
        self.targetLanguage = targetLanguage
        self.pagesInFlight = pagesInFlight
        self.pages = pages
    }
}
```

Inside `State`, add:
```swift
public var translation: TranslationState
```

Update the `State.init(...)` signature with a new parameter (default-valued):
```swift
translation: TranslationState = TranslationState()
```

and assign it at the bottom of `init`.

- [ ] **Step 4: Verify ReaderFeature still builds**

```bash
tuist generate
tuist test ReaderFeature
```
Expected: existing tests still PASS; nothing breaks. (We have not added new actions yet — that comes in Task 18.)

- [ ] **Step 5: Commit**

```bash
git add Features/ReaderFeature/Project.swift Features/ReaderFeature/Sources/TranslationDependencyKeys.swift Features/ReaderFeature/Sources/ReaderFeature.swift
git commit -m "feat(reader): add TranslationState and translation dependency keys"
```

---

## Task 18: ReaderFeature — translation actions, effects, and tests

**Files:**
- Modify: `Features/ReaderFeature/Sources/ReaderFeature.swift`
- Modify: `Features/ReaderFeature/Tests/ReaderFeatureTests.swift`

- [ ] **Step 1: Add new actions to `ReaderFeature.Action`**

```swift
case translationToggleChanged(Bool)
case translatePage(Int)
case translationLoaded(pageIndex: Int, page: TranslatedPage, fromCache: Bool)
case translationFailed(pageIndex: Int)
```

- [ ] **Step 2: Add two new `@Dependency` declarations to the reducer**

```swift
@Dependency(\.pageTranslator) var pageTranslator
@Dependency(\.translationCache) var translationCache
```

- [ ] **Step 3: Extend `.task` to read the persisted toggle**

Find the existing `case .task:` branch. At the very top of the case (before the `let comic = state.comic` line), insert:

```swift
if state.translation.isIntelligenceAvailable,
   userDefaults.string(forKey: SettingsFeature.autoTranslateKey) == "true" {
    state.translation.isEnabled = true
}
```

Leave the rest of the `.task` body (archive open `.run`) untouched. The initial prefetch fires from `.opened` (next step) so that `state.pageIndex` reflects the saved last page.

- [ ] **Step 4: Extend `.opened` to kick off initial prefetch**

Find the existing `case let .opened(handle, pageCount, savedLastPage):` branch. Replace its final `return .none` with:

```swift
if state.translation.isEnabled && state.translation.isIntelligenceAvailable {
    let idx = state.pageIndex
    return .merge(
        .send(.translatePage(idx - 1)),
        .send(.translatePage(idx)),
        .send(.translatePage(idx + 1))
    )
}
return .none
```

- [ ] **Step 5: Add the new reducer cases**

Insert before the existing `.alert:` (or wherever the final cases live) the following:

```swift
case let .translationToggleChanged(enabled):
    state.translation.isEnabled = enabled
    userDefaults.set(enabled ? "true" : "false", forKey: SettingsFeature.autoTranslateKey)
    if enabled {
        let idx = state.pageIndex
        return .merge(
            .send(.translatePage(idx - 1)),
            .send(.translatePage(idx)),
            .send(.translatePage(idx + 1))
        )
    }
    return .none

case let .translatePage(idx):
    guard
        state.translation.isEnabled,
        state.translation.isIntelligenceAvailable,
        idx >= 0, idx < state.pageCount,
        state.translation.pages[idx] == nil,
        !state.translation.pagesInFlight.contains(idx)
    else { return .none }

    state.translation.pagesInFlight.insert(idx)
    let comicId = state.comic.id
    let target = state.translation.targetLanguage
    let format = state.comic.format
    let cache = self.translationCache
    let translator = self.pageTranslator
    let router = self.router
    let imageCache = self.imageCache
    let handle = state.handle

    return .run { send in
        // Cache lookup first.
        if let cached = await cache.load(comicId: comicId, pageIndex: idx, targetLanguage: target) {
            await send(.translationLoaded(pageIndex: idx, page: cached, fromCache: true))
            return
        }
        // Fetch image bytes (try cache, then archive).
        let key = PageKey(comicId: comicId, pageIndex: idx)
        var imageData = await imageCache.data(for: key)
        if imageData == nil, let handle {
            let reader = router.reader(for: format)
            do {
                let data = try await reader.pageData(handle, index: idx)
                await imageCache.store(data, for: key)
                imageData = data
            } catch {
                await send(.translationFailed(pageIndex: idx))
                return
            }
        }
        guard let imageData else {
            await send(.translationFailed(pageIndex: idx))
            return
        }
        do {
            let page = try await translator.translate(
                imageData: imageData, comicId: comicId, pageIndex: idx, targetLanguage: target
            )
            await send(.translationLoaded(pageIndex: idx, page: page, fromCache: false))
        } catch {
            await send(.translationFailed(pageIndex: idx))
        }
    }

case let .translationLoaded(idx, page, fromCache):
    state.translation.pages[idx] = page
    state.translation.pagesInFlight.remove(idx)
    if fromCache { return .none }
    let cache = self.translationCache
    return .run { _ in
        Task.detached(priority: .utility) {
            try? await cache.save(page)
        }
    }

case let .translationFailed(idx):
    state.translation.pagesInFlight.remove(idx)
    return .none
```

- [ ] **Step 6: Extend `.pageChanged` to fan out neighbor translations**

Find the existing `case let .pageChanged(index):` and replace its body with:

```swift
case let .pageChanged(index):
    guard index != state.pageIndex, index >= 0, index < state.pageCount else { return .none }
    state.pageIndex = index
    var effects: [Effect<Action>] = [
        .send(.prefetchHint(index)),
        .send(.persistProgress)
    ]
    if state.translation.isEnabled && state.translation.isIntelligenceAvailable {
        effects.append(.send(.translatePage(index - 1)))
        effects.append(.send(.translatePage(index)))
        effects.append(.send(.translatePage(index + 1)))
    }
    return .merge(effects)
```

- [ ] **Step 7: Write reducer tests**

Append to `Features/ReaderFeature/Tests/ReaderFeatureTests.swift`. Use the existing `TestStore` style.

```swift
@Test func toggleOnDispatchesNeighborTranslates() async {
    let comic = sampleComic(pageCount: 10)
    let translator = FakePageTranslator()
    let cache = InMemoryTranslationCache()
    let store = await TestStore(
        initialState: ReaderFeature.State(
            comic: comic,
            pageIndex: 5,
            pageCount: 10,
            translation: ReaderFeature.TranslationState(
                isIntelligenceAvailable: true,
                isEnabled: false,
                targetLanguage: "ko"
            )
        )
    ) {
        ReaderFeature()
    } withDependencies: {
        $0.pageTranslator = translator
        $0.translationCache = cache
        $0.userDefaults = InMemoryUserDefaults()
    }

    await store.send(.translationToggleChanged(true)) {
        $0.translation.isEnabled = true
    }
    // Three neighbor translatePage actions are fired (4, 5, 6).
    await store.receive(.translatePage(4))
    await store.receive(.translatePage(5))
    await store.receive(.translatePage(6))
    // Each one inserts into pagesInFlight then loads (fake returns empty).
    // We won't track the full effect chain here — exit via finishing.
    await store.finish()
}

@Test func translatePageGuardsOutOfRange() async {
    let store = await TestStore(
        initialState: ReaderFeature.State(
            comic: sampleComic(pageCount: 3),
            pageCount: 3,
            translation: ReaderFeature.TranslationState(
                isIntelligenceAvailable: true,
                isEnabled: true
            )
        )
    ) {
        ReaderFeature()
    } withDependencies: {
        $0.pageTranslator = FakePageTranslator()
        $0.translationCache = InMemoryTranslationCache()
        $0.userDefaults = InMemoryUserDefaults()
    }
    await store.send(.translatePage(-1))    // guarded
    await store.send(.translatePage(99))    // guarded
    // No state mutation, no further actions.
}
```

Add the fake translator helper at the top of the test file:

```swift
private struct FakePageTranslator: PageTranslator {
    func translate(imageData: Data, comicId: UUID, pageIndex: Int, targetLanguage: String) async throws -> TranslatedPage {
        TranslatedPage(
            comicId: comicId, pageIndex: pageIndex,
            sourceLanguage: "ja", targetLanguage: targetLanguage,
            lines: [], createdAt: Date()
        )
    }
}
```

And a `sampleComic` helper if not already present:

```swift
private func sampleComic(pageCount: Int) -> ComicItem {
    ComicItem(
        id: UUID(),
        url: URL(fileURLWithPath: "/tmp/sample.cbz"),
        format: .cbz,
        title: "Sample",
        pageCount: pageCount,
        coverThumbnail: nil,
        dateAdded: Date(),
        fileSizeBytes: 0
    )
}
```

> If the test file already declares `sampleComic` with a different signature, reuse the existing helper instead of redeclaring.

- [ ] **Step 8: Run ReaderFeature tests**

```bash
tuist test ReaderFeature
```
Expected: all existing + 2 new tests PASS.

- [ ] **Step 9: Commit**

```bash
git add Features/ReaderFeature/Sources/ReaderFeature.swift Features/ReaderFeature/Tests/ReaderFeatureTests.swift
git commit -m "feat(reader): translate current ±1 pages when auto-translate is on"
```

---

## Task 19: ReaderFeature — `PageTranslationOverlay` view

**Files:**
- Create: `Features/ReaderFeature/Sources/PageTranslationOverlay.swift`

- [ ] **Step 1: Implement the overlay view**

```swift
// Features/ReaderFeature/Sources/PageTranslationOverlay.swift
import SwiftUI
import Domain
import DesignSystem

struct PageTranslationOverlay: View {
    let page: TranslatedPage?
    let isHidden: Bool

    var body: some View {
        if !isHidden, let page, !page.lines.isEmpty {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    ForEach(page.lines, id: \.original.id) { line in
                        let bb = line.original.boundingBox
                        let w = max(8, proxy.size.width * bb.width)
                        let h = max(8, proxy.size.height * bb.height)
                        let cx = proxy.size.width * bb.midX
                        let cy = proxy.size.height * (1 - bb.midY)  // Vision Y → SwiftUI Y

                        Text(line.translated)
                            .font(Tokens.Typography.subtitle)
                            .foregroundStyle(Tokens.Colors.ink)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.4)
                            .lineLimit(nil)
                            .padding(2)
                            .frame(width: w, height: h)
                            .background(Color(argb: line.backgroundColorARGB))
                            .position(x: cx, y: cy)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}
```

- [ ] **Step 2: Verify it builds**

```bash
tuist generate
xcodebuild build -workspace Mana.xcworkspace -scheme ReaderFeature -destination 'generic/platform=iOS' -quiet
```
Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add Features/ReaderFeature/Sources/PageTranslationOverlay.swift
git commit -m "feat(reader): add PageTranslationOverlay view"
```

---

## Task 20: ReaderFeature — wire overlay into single + dual renderers

**Files:**
- Modify: `Features/ReaderFeature/Sources/SinglePageRenderer.swift`
- Modify: `Features/ReaderFeature/Sources/DualPageRenderer.swift`
- Modify: `Features/ReaderFeature/Sources/ReaderView.swift`

- [ ] **Step 1: Add an `overlay` parameter to `SinglePageRenderer`**

In `SinglePageRenderer.swift`, extend the initializer and properties to accept:

```swift
let pageOverlay: ((Int) -> AnyView)?
```

Default value `nil`. Wherever the renderer draws the page image inside its aspect-fit container, wrap the image in a `ZStack`:

```swift
ZStack {
    Image(uiImage: img)
        .resizable()
        .aspectRatio(contentMode: .fit)
    if let pageOverlay {
        pageOverlay(pageIndex)
    }
}
```

> Read the existing file first; place the overlay inside the same container that already sizes/letterboxes the page image. Do NOT add it on top of any tap-zone overlay.

- [ ] **Step 2: Add an `overlay` parameter to `DualPageRenderer`**

Same change in `DualPageRenderer.swift`. The renderer shows two pages side-by-side; each page's `ZStack` gets its own `pageOverlay(idx)` call with the appropriate index.

- [ ] **Step 3: Pass the overlay from `ReaderView`**

In `Features/ReaderFeature/Sources/ReaderView.swift`, inside the `private var renderer: some View` computed property, build the overlay closure:

```swift
let pageOverlay: ((Int) -> AnyView)? = store.translation.isIntelligenceAvailable
    ? { idx in
        AnyView(
            PageTranslationOverlay(
                page: store.translation.pages[idx],
                isHidden: !store.translation.isEnabled
            )
        )
      }
    : nil
```

Pass `pageOverlay: pageOverlay` to both renderer initializers.

- [ ] **Step 4: Build + run the reader manually on simulator**

```bash
tuist generate
xcodebuild build -workspace Mana.xcworkspace -scheme Mana -destination 'platform=iOS Simulator,name=iPhone 15' -quiet
```
Expected: succeeds. Manual verification: open a comic, enable translation in Settings, open the reader, confirm the overlay area aligns with the page.

- [ ] **Step 5: Commit**

```bash
git add Features/ReaderFeature/Sources/SinglePageRenderer.swift Features/ReaderFeature/Sources/DualPageRenderer.swift Features/ReaderFeature/Sources/ReaderView.swift
git commit -m "feat(reader): wire translation overlay into single + dual renderers"
```

---

## Task 21: ReaderFeature — controls popover toggle + strings

**Files:**
- Modify: `Features/ReaderFeature/Sources/ReaderView.swift`
- Modify: `Features/ReaderFeature/Resources/{ko,ja,en}.lproj/Localizable.strings`

- [ ] **Step 1: Append strings**

`Features/ReaderFeature/Resources/ko.lproj/Localizable.strings`:
```
"reader.controls.translate" = "번역";
"translate.on" = "켜기";
"translate.off" = "끄기";
```

`Features/ReaderFeature/Resources/ja.lproj/Localizable.strings`:
```
"reader.controls.translate" = "翻訳";
"translate.on" = "オン";
"translate.off" = "オフ";
```

`Features/ReaderFeature/Resources/en.lproj/Localizable.strings`:
```
"reader.controls.translate" = "Translate";
"translate.on" = "On";
"translate.off" = "Off";
```

- [ ] **Step 2: Add the gated section to `controlsPopover`**

In `ReaderView.swift`, locate the `private var controlsPopover: some View { VStack(...) { ... } }`. Just before the final closing braces of that `VStack`, append:

```swift
if store.translation.isIntelligenceAvailable {
    sectionDivider
    sectionHeader(localized("reader.controls.translate"))
    optionRow(localized("translate.off"),
              isSelected: !store.translation.isEnabled) {
        store.send(.translationToggleChanged(false))
    }
    divider
    optionRow(localized("translate.on"),
              isSelected: store.translation.isEnabled) {
        store.send(.translationToggleChanged(true))
    }
}
```

- [ ] **Step 3: Build**

```bash
tuist generate
xcodebuild build -workspace Mana.xcworkspace -scheme ReaderFeature -destination 'generic/platform=iOS' -quiet
```
Expected: succeeds.

- [ ] **Step 4: Commit**

```bash
git add Features/ReaderFeature/Sources/ReaderView.swift Features/ReaderFeature/Resources
git commit -m "ui(reader): gated translation toggle in controls popover"
```

---

## Task 22: AppFeature — `isIntelligenceAvailable` + child state injection

**Files:**
- Modify: `Features/AppFeature/Sources/AppFeature.swift`
- Modify: `Features/AppFeature/Project.swift`

- [ ] **Step 1: Add IntelligenceKit dependency to AppFeature**

In `Features/AppFeature/Project.swift`, append to `dependencies`:

```swift
.project(target: "IntelligenceKit", path: "../../Data/IntelligenceKit"),
```

- [ ] **Step 2: Define a `DependencyKey` for `IntelligenceAvailability` inside AppFeature**

Append to the bottom of `Features/AppFeature/Sources/AppFeature.swift`:

```swift
private enum IntelligenceAvailabilityKey: DependencyKey {
    static let liveValue: any IntelligenceAvailability = UnavailableIntelligence()
    static let testValue: any IntelligenceAvailability = UnavailableIntelligence()
}

extension DependencyValues {
    public var intelligenceAvailability: any IntelligenceAvailability {
        get { self[IntelligenceAvailabilityKey.self] }
        set { self[IntelligenceAvailabilityKey.self] = newValue }
    }
}
```

Add imports at the top of the file:
```swift
import IntelligenceKit
```

- [ ] **Step 3: Extend `AppFeature.State`**

Add a new field:
```swift
public var isIntelligenceAvailable: Bool
```

Update `init` to accept it (default `false`).

- [ ] **Step 4: Resolve availability in `.task`**

In the reducer body, add the `@Dependency` for the new key:

```swift
@Dependency(\.intelligenceAvailability) var intelligenceAvailability
```

Inside the existing `.task` case, **before** the existing migration logic, evaluate:
```swift
state.isIntelligenceAvailable = intelligenceAvailability.isAvailable
```

- [ ] **Step 5: Inject availability into child states**

Find the existing `library(.comicTapped(comic))` branch. Replace the reader push to also pass the target language and availability:

```swift
case let .library(.comicTapped(comic)):
    let target = TargetLanguageResolver.resolve(appLanguageRawValue: state.appLanguage.rawValue)
    let translation = ReaderFeature.TranslationState(
        isIntelligenceAvailable: state.isIntelligenceAvailable,
        targetLanguage: target
    )
    state.path.append(.reader(ReaderFeature.State(comic: comic, translation: translation)))
    return .none
```

Find the existing `library(.settingsTapped)` branch and update similarly:

```swift
case .library(.settingsTapped):
    state.path.append(
        .settings(
            SettingsFeature.State(
                appLanguage: state.appLanguage,
                isIntelligenceAvailable: state.isIntelligenceAvailable
            )
        )
    )
    return .none
```

- [ ] **Step 6: Run AppFeature build / existing AppFeature tests if any**

```bash
tuist generate
tuist test AppFeature 2>/dev/null || true
xcodebuild build -workspace Mana.xcworkspace -scheme AppFeature -destination 'generic/platform=iOS' -quiet
```
Expected: build succeeds. AppFeature may not have a test target — the `|| true` swallows the resulting non-zero exit.

- [ ] **Step 7: Commit**

```bash
git add Features/AppFeature/Project.swift Features/AppFeature/Sources/AppFeature.swift
git commit -m "feat(app): resolve intelligence availability and inject into child states"
```

---

## Task 23: App — register live dependencies with iOS 26 gate

**Files:**
- Modify: `App/Sources/DependenciesLive.swift`
- Modify: `App/Project.swift`

- [ ] **Step 1: Add IntelligenceKit to App's dependency list**

In `App/Project.swift`, append to the `Mana` target's `dependencies` array:

```swift
.project(target: "IntelligenceKit", path: "../Data/IntelligenceKit"),
```

- [ ] **Step 2: Wire the live availability, translator, and cache**

In `App/Sources/DependenciesLive.swift`, add imports:

```swift
import IntelligenceKit
import AppFeature
```

Inside `register()`, after the existing `let folderRepo = ...` line, instantiate the translation cache:

```swift
let translationCache = TranslationCacheLive(stack: stack)
```

Inside the existing `prepareDependencies { ... }`, append:

```swift
$0.translationCache = translationCache
if #available(iOS 26.0, *) {
    $0.intelligenceAvailability = IntelligenceAvailabilityLive()
    $0.pageTranslator = PageTranslatorLive(llm: FoundationModelsTranslator())
} else {
    $0.intelligenceAvailability = UnavailableIntelligence()
    $0.pageTranslator = NoopPageTranslator()
}
```

- [ ] **Step 3: Build and run on simulator**

```bash
tuist generate
xcodebuild build -workspace Mana.xcworkspace -scheme Mana -destination 'platform=iOS Simulator,name=iPhone 15' -quiet
```
Expected: succeeds. On simulators that lack Apple Intelligence support, the toggles should remain hidden — verify by launching the app and checking Settings.

- [ ] **Step 4: Commit**

```bash
git add App/Project.swift App/Sources/DependenciesLive.swift
git commit -m "feat(app): wire intelligence/translator/cache live dependencies (iOS 26 gated)"
```

---

## Task 24: LibraryResetService — clear translation cache

**Files:**
- Modify: `App/Sources/LibraryResetServiceLive.swift`

- [ ] **Step 1: Inject the translation cache into the reset service**

Modify `LibraryResetServiceLive` to take an additional `translationCache` property:

```swift
import Foundation
import Domain
import PersistenceKit
import ImageCacheKit

public struct LibraryResetServiceLive: LibraryResetService {
    let comicRepo: any ComicRepository
    let folderRepo: any FolderRepository
    let progressRepo: any ProgressRepository
    let imageCache: ImageCache
    let translationCache: any TranslationCache

    public init(
        comicRepo: any ComicRepository,
        folderRepo: any FolderRepository,
        progressRepo: any ProgressRepository,
        imageCache: ImageCache,
        translationCache: any TranslationCache
    ) {
        self.comicRepo = comicRepo
        self.folderRepo = folderRepo
        self.progressRepo = progressRepo
        self.imageCache = imageCache
        self.translationCache = translationCache
    }

    public func resetAll() async throws {
        let allComics = await comicRepo.all()
        let allFolders = await folderRepo.all()
        for comic in allComics {
            try? FileManager.default.removeItem(at: comic.url)
            try? await comicRepo.delete(comic.id)
        }
        for folder in allFolders {
            try? await folderRepo.delete(folder.id)
        }
        try? await translationCache.deleteEverything()
        let localDir = LibraryStorage.libraryDirectory
        try? FileManager.default.removeItem(at: localDir)
        try? FileManager.default.createDirectory(at: localDir, withIntermediateDirectories: true)
        await imageCache.evictMemory()
    }
}
```

- [ ] **Step 2: Update construction site in `DependenciesLive`**

In `App/Sources/DependenciesLive.swift`, update the existing `LibraryResetServiceLive(...)` call to pass the cache:

```swift
let libraryReset = LibraryResetServiceLive(
    comicRepo: comicRepo,
    folderRepo: folderRepo,
    progressRepo: progressRepo,
    imageCache: cache,
    translationCache: translationCache
)
```

- [ ] **Step 3: Build**

```bash
tuist generate
xcodebuild build -workspace Mana.xcworkspace -scheme Mana -destination 'generic/platform=iOS' -quiet
```
Expected: succeeds.

- [ ] **Step 4: Commit**

```bash
git add App/Sources/LibraryResetServiceLive.swift App/Sources/DependenciesLive.swift
git commit -m "feat(library): clear translation cache on full reset"
```

---

## Task 25: Integration test — happy path with fake translator

**Files:**
- Modify: `App/Tests/IntegrationFlowTests.swift`

- [ ] **Step 1: Add a translation happy-path test**

Add to `App/Tests/IntegrationFlowTests.swift`:

```swift
@MainActor
@Test func translationToggleOnPopulatesOverlay() async throws {
    // Arrange: minimal reader state, fake translator that yields one line.
    let comic = ComicItem(
        id: UUID(),
        url: URL(fileURLWithPath: "/tmp/x.cbz"),
        format: .cbz,
        title: "x",
        pageCount: 3,
        coverThumbnail: nil,
        dateAdded: Date(),
        fileSizeBytes: 0
    )
    let store = await TestStore(
        initialState: ReaderFeature.State(
            comic: comic,
            pageIndex: 1,
            pageCount: 3,
            translation: ReaderFeature.TranslationState(
                isIntelligenceAvailable: true,
                targetLanguage: "ko"
            )
        )
    ) {
        ReaderFeature()
    } withDependencies: {
        $0.pageTranslator = FixedPageTranslator()
        $0.translationCache = InMemoryTranslationCache()
        $0.userDefaults = InMemoryUserDefaults()
        // We deliberately don't wire archiveReaderRouter / imageCache — the
        // fake translator does not need image bytes, but the reducer's
        // `.translatePage` path will hit imageCache. Provide an in-memory cache
        // pre-seeded with placeholder PNG bytes for indices 0..2.
        let cache = ImageCache.inMemoryOnly()
        let placeholder = makePlaceholderPNG()
        for idx in 0..<3 {
            await cache.store(placeholder, for: PageKey(comicId: comic.id, pageIndex: idx))
        }
        $0.imageCache = cache
    }

    await store.send(.translationToggleChanged(true)) {
        $0.translation.isEnabled = true
    }
    // Receive the 3 translatePage actions and their loaded results.
    // We assert at least one .translationLoaded ends up with a non-empty page.
    await store.skipReceivedActions()
    #expect(store.state.translation.pages.values.contains { !$0.lines.isEmpty })
}

private struct FixedPageTranslator: PageTranslator {
    func translate(imageData: Data, comicId: UUID, pageIndex: Int, targetLanguage: String) async throws -> TranslatedPage {
        let box = TextLineBox(
            id: UUID(), text: "こんにちは",
            boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.05),
            confidence: 0.95
        )
        return TranslatedPage(
            comicId: comicId, pageIndex: pageIndex,
            sourceLanguage: "ja", targetLanguage: targetLanguage,
            lines: [TranslatedLine(original: box, translated: "안녕", backgroundColorARGB: 0xFFFFFFFF)],
            createdAt: Date()
        )
    }
}

private func makePlaceholderPNG() -> Data {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
    let img = renderer.image { ctx in
        UIColor.white.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
    }
    return img.pngData()!
}
```

> Note: ensure the file's imports include `IntelligenceKit` (for `InMemoryTranslationCache`) and `ImageCacheKit` if not already present.

- [ ] **Step 2: Run the integration tests**

```bash
tuist test App --test-targets ManaTests
```
Expected: existing tests still PASS + the new test PASSES.

- [ ] **Step 3: Commit**

```bash
git add App/Tests/IntegrationFlowTests.swift
git commit -m "test(app): integration happy path for translation overlay"
```

---

## Final Verification

After all 25 tasks have been committed:

- [ ] **Run the full test suite**

```bash
tuist test
```
Expected: every target passes.

- [ ] **Build the app**

```bash
xcodebuild build -workspace Mana.xcworkspace -scheme Mana -destination 'platform=iOS Simulator,name=iPhone 15' -quiet
```
Expected: succeeds.

- [ ] **Manual smoke (simulator, iOS < 26):**
  - Open Settings → no "Auto translation" section.
  - Open a comic → reader controls popover has no "번역" section.

- [ ] **Manual smoke (device, iOS 26+ with Apple Intelligence on):**
  - Open Settings → "Auto translation" section appears, toggle persists.
  - Open a Japanese-text manga → enabling the toggle shows Korean overlays
    on text lines within a couple of seconds.
  - Flip pages → neighbors are already translated (no flicker).
  - Disable → overlays vanish. Re-enable → overlays return instantly (cache hit).
  - Settings → "라이브러리 초기화" → translation cache wiped (overlays
    re-OCR on next read).

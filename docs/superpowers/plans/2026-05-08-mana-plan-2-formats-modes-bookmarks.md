# Mana — Plan 2: Formats, Reading Modes, Bookmarks

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Extend Plan 1's foundation to support RAR/CBR + PDF formats, all three reading modes (single / dual / scroll with LTR/RTL/TTB), bookmarks, per-comic reading mode persistence, and a settings feature for global defaults.

**Architecture:** Pure additions to the existing module structure — no breaking changes to Domain or Plan 1 features. New `RarArchiveReader` and `PDFArchiveReader` slot in behind the existing `ArchiveReader` protocol; new `DualPageRenderer` and `ScrollPageRenderer` slot in behind `PageRenderer`. Bookmarks and Settings get their own feature modules. Two refactors fold in feedback from Plan 1's final review: replace `SinglePageRenderer`'s 3-second cache poll with a reducer-pushed `pageImage` lookup, and downsample thumbnails through a real `ThumbnailProvider` instead of stuffing first-page bytes into SwiftData.

**Tech Stack:** Same as Plan 1, plus UnrarKit (LGPL, dynamic-link) for RAR and PDFKit (system) for PDF. PDFKit already in iOS SDK; UnrarKit added to `Tuist/Package.swift`.

---

## File Structure (added/modified across this plan)

```
Mana/
├── Tuist/Package.swift                              [M] — add UnrarKit
├── Domain/Sources/Models/ReadingMode.swift          [M] — already exists; reused
├── Data/ArchiveKit/
│   ├── Sources/RarArchiveReader.swift               [+] — new
│   ├── Sources/PDFArchiveReader.swift               [+] — new
│   ├── Sources/DefaultArchiveReaderRouter.swift     [M] — wire RAR + PDF
│   ├── Sources/RarSessionStore.swift                [+] — actor for UnrarKit handles
│   ├── Sources/PDFSessionStore.swift                [+] — actor for PDFDocument handles
│   ├── Tests/Resources/sample.cbr                   [+] — fixture
│   ├── Tests/Resources/sample.pdf                   [+] — fixture
│   ├── Tests/RarArchiveReaderTests.swift            [+]
│   └── Tests/PDFArchiveReaderTests.swift            [+]
├── Data/ThumbnailKit/                               [+] — new module
│   ├── Project.swift
│   ├── Sources/ImageDownsampler.swift               — UIImage → Data downsampler
│   ├── Sources/ThumbnailProviderLive.swift          — implements Domain.ThumbnailProvider
│   └── Tests/ImageDownsamplerTests.swift
├── Data/PersistenceKit/
│   ├── Sources/SwiftDataModels.swift                [M] — add ComicEntity.readingModeRaw
│   └── Sources/ComicRepositoryLive.swift            [M] — round-trip new field
├── Domain/Sources/Models/ComicItem.swift            [M] — add readingMode field
├── Features/ReaderFeature/
│   ├── Sources/PageRenderer.swift                   [M] — push pattern (image arg, not cache)
│   ├── Sources/SinglePageRenderer.swift             [M] — refactored to use injected image
│   ├── Sources/DualPageRenderer.swift               [+]
│   ├── Sources/ScrollPageRenderer.swift             [+]
│   ├── Sources/ReaderFeature.swift                  [M] — track per-page UIImage in state
│   ├── Sources/ReaderView.swift                     [M] — switch on mode, controls update
│   └── Tests/ReaderFeatureTests.swift               [M] — new tests for mode change
├── Features/BookmarksFeature/                       [+] — new module
│   ├── Project.swift
│   ├── Sources/BookmarksFeature.swift
│   ├── Sources/BookmarksView.swift
│   ├── Sources/BookmarkSheet.swift                  — sheet view in reader for "Add bookmark"
│   └── Tests/BookmarksFeatureTests.swift
├── Features/SettingsFeature/                        [+] — new module
│   ├── Project.swift
│   ├── Sources/SettingsFeature.swift
│   ├── Sources/SettingsView.swift
│   └── Tests/SettingsFeatureTests.swift
├── Features/AppFeature/Sources/AppFeature.swift     [M] — add bookmarks+settings to Path
├── Features/AppFeature/Sources/AppView.swift        [M] — destinations for new path cases
├── App/Sources/DependenciesLive.swift               [M] — wire bookmarkRepo, thumbnailProvider, default reading mode
└── App/Sources/LibraryImporterLive.swift            [M] — use ThumbnailProvider instead of raw page0 bytes
```

---

## Conventions (continued from Plan 1)

- **Test resources for non-Module-helper projects:** explicit `resources: ["Tests/Resources/**"]` on the test target
- **Bundle anchor pattern:** `private final class BundleAnchor {} ... Bundle(for: BundleAnchor.self).url(forResource:)`
- **TestStore exhaustivity:** `.off(showSkippedAssertions: false)` when reducers emit cascading actions
- **Run tests:** `tuist generate --no-open && tuist test <ModuleName>` for unit tests, `xcodebuild test -workspace Mana.xcworkspace -scheme Mana -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' CODE_SIGNING_ALLOWED=NO` for integration test
- **Commit prefixes:** `feat(<module>):`, `test(<module>):`, `refactor(<module>):`, `chore(tuist):`

---

## Task 1: Add UnrarKit dependency

**Files:**
- Modify: `Tuist/Package.swift`

- [ ] **Step 1: Edit `Tuist/Package.swift`**

Add UnrarKit to dependencies and productTypes. Replace the file contents with:

```swift
// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import struct ProjectDescription.PackageSettings
let packageSettings = PackageSettings(
    productTypes: [
        "ComposableArchitecture": .framework,
        "ZIPFoundation": .framework,
        "UnrarKit": .framework
    ]
)
#endif

let package = Package(
    name: "ManaDeps",
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.15.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.19"),
        .package(url: "https://github.com/abbeycode/UnrarKit", from: "2.10.0")
    ]
)
```

- [ ] **Step 2: Resolve and verify**

Run: `tuist install`
Expected: success — UnrarKit and its transitive dep (libunrar) are resolved. If this fails because UnrarKit isn't a SwiftPM package, see fallback below.

**Fallback if UnrarKit is not on SwiftPM:** UnrarKit historically shipped as CocoaPods. If `tuist install` fails with "no Package.swift", swap for a SwiftPM-compatible RAR library:
```swift
.package(url: "https://github.com/weichsel/ZIPFoundationXAR", from: "...")  // example placeholder
```
or vendor `unrar` C source via `Tuist/Vendor/unrar/`. Document the substitution in the commit message.

- [ ] **Step 3: Commit**

```bash
git add Tuist/Package.swift Tuist/Package.resolved
git commit -m "chore(tuist): add UnrarKit dependency for RAR/CBR support"
```

---

## Task 2: ThumbnailKit — downsampling provider

This module implements `Domain.ThumbnailProvider`. Used by the importer to generate small (<100KB) thumbnails instead of stuffing full first-page bytes into SwiftData.

**Files:**
- Create: `Data/ThumbnailKit/Project.swift`
- Create: `Data/ThumbnailKit/Sources/ImageDownsampler.swift`
- Create: `Data/ThumbnailKit/Sources/ThumbnailProviderLive.swift`
- Test: `Data/ThumbnailKit/Tests/ImageDownsamplerTests.swift`

- [ ] **Step 1: Write `Data/ThumbnailKit/Project.swift`**

```swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "ThumbnailKit",
    kind: .data,
    dependencies: [.project(target: "Domain", path: "../../Domain")],
    hasTests: true
).project()
```

- [ ] **Step 2: Write failing tests `Data/ThumbnailKit/Tests/ImageDownsamplerTests.swift`**

```swift
import Testing
import Foundation
import UIKit
@testable import ThumbnailKit

@Suite struct ImageDownsamplerTests {

    @Test func downsamplesLargeImageToMaxDim() throws {
        let large = makeRedImage(width: 2000, height: 3000)
        let pngData = try #require(large.pngData())

        let resultData = try #require(ImageDownsampler.downsample(pngData, maxDim: 256))
        let resultImage = try #require(UIImage(data: resultData))

        #expect(resultImage.size.width <= 256)
        #expect(resultImage.size.height <= 256)
        #expect(resultData.count < pngData.count)
    }

    @Test func smallerImageIsReturnedAsIs() throws {
        let small = makeRedImage(width: 100, height: 100)
        let jpegData = try #require(small.jpegData(compressionQuality: 0.8))

        let resultData = try #require(ImageDownsampler.downsample(jpegData, maxDim: 256))
        let resultImage = try #require(UIImage(data: resultData))

        #expect(resultImage.size.width <= 256)
        #expect(resultImage.size.height <= 256)
    }

    private func makeRedImage(width: Int, height: Int) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `tuist generate --no-open && tuist test ThumbnailKit`
Expected: compile failure.

- [ ] **Step 4: Write `Data/ThumbnailKit/Sources/ImageDownsampler.swift`**

```swift
import Foundation
import UIKit
import ImageIO

public enum ImageDownsampler {
    /// Downsample image bytes to a thumbnail with longest side <= maxDim,
    /// re-encoded as JPEG at quality 0.8. Returns nil if the input is not decodable.
    public static func downsample(_ data: Data, maxDim: CGFloat) -> Data? {
        let cfData = data as CFData
        guard let source = CGImageSourceCreateWithData(cfData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDim
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.jpegData(compressionQuality: 0.8)
    }
}
```

- [ ] **Step 5: Write `Data/ThumbnailKit/Sources/ThumbnailProviderLive.swift`**

```swift
import Foundation
import Domain

public actor ThumbnailProviderLive: ThumbnailProvider {
    private let cacheDir: URL
    private let fm = FileManager.default

    public init(cacheDir: URL) {
        self.cacheDir = cacheDir
        try? fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    public func thumbnail(for comicId: UUID, page: Int, maxDim: CGFloat) async throws -> Data {
        let url = fileURL(comicId: comicId, page: page)
        if let cached = try? Data(contentsOf: url) {
            return cached
        }
        // No raw bytes available standalone — caller must persist via storeRaw first.
        throw ThumbnailError.notFound
    }

    /// Stores a downsampled version of `rawPageBytes`; called by importer.
    public func storeThumbnail(comicId: UUID, page: Int, rawPageBytes: Data, maxDim: CGFloat) async throws -> Data {
        guard let downsampled = ImageDownsampler.downsample(rawPageBytes, maxDim: maxDim) else {
            throw ThumbnailError.encodingFailed
        }
        let url = fileURL(comicId: comicId, page: page)
        try downsampled.write(to: url, options: .atomic)
        return downsampled
    }

    public func remove(comicId: UUID) async {
        let prefix = "\(comicId.uuidString)-"
        let items = (try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)) ?? []
        for item in items where item.lastPathComponent.hasPrefix(prefix) {
            try? fm.removeItem(at: item)
        }
    }

    private func fileURL(comicId: UUID, page: Int) -> URL {
        cacheDir.appending(path: "\(comicId.uuidString)-\(page).jpg")
    }
}

public enum ThumbnailError: Error, Equatable, Sendable {
    case notFound
    case encodingFailed
}
```

> Note: `ImageDownsampler.swift` imports `UIKit`. ThumbnailKit is iOS-only (already enforced by Tuist `.iOS` destination).

- [ ] **Step 6: Run tests**

Run: `tuist test ThumbnailKit`
Expected: 2 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add Data/ThumbnailKit/ Workspace.swift
git commit -m "feat(thumbnail-kit): downsampling thumbnail provider"
```

> Workspace.swift edit: add `"Data/ThumbnailKit"` to the `projects:` array. The other modules' references to ThumbnailKit come in Task 9.

---

## Task 3: PDFArchiveReader

**Files:**
- Create: `Data/ArchiveKit/Sources/PDFSessionStore.swift`
- Create: `Data/ArchiveKit/Sources/PDFArchiveReader.swift`
- Create: `Data/ArchiveKit/Tests/Resources/sample.pdf`
- Create: `Data/ArchiveKit/Tests/PDFArchiveReaderTests.swift`

- [ ] **Step 1: Generate fixture `sample.pdf` (3 pages)**

Run:
```bash
python3 - <<'PY'
import os
out = "/Users/doyoung_kim/Documents/Git/mana/Data/ArchiveKit/Tests/Resources/sample.pdf"
# Minimal 3-page PDF written by hand (printable text).
pdf = (
    b"%PDF-1.4\n"
    b"1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n"
    b"2 0 obj << /Type /Pages /Count 3 /Kids [3 0 R 4 0 R 5 0 R] >> endobj\n"
    b"3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Contents 6 0 R >> endobj\n"
    b"4 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Contents 7 0 R >> endobj\n"
    b"5 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Contents 8 0 R >> endobj\n"
    b"6 0 obj << /Length 8 >> stream\nq\nQ\nendstream endobj\n"
    b"7 0 obj << /Length 8 >> stream\nq\nQ\nendstream endobj\n"
    b"8 0 obj << /Length 8 >> stream\nq\nQ\nendstream endobj\n"
    b"trailer << /Size 9 /Root 1 0 R >>\n%%EOF\n"
)
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "wb") as f:
    f.write(pdf)
print("wrote", out, len(pdf))
PY
```

If PDFKit rejects the hand-rolled minimal PDF, fallback: use `PDFDocument` to write a 3-page PDF programmatically:

```bash
swift -e '
import PDFKit
import Foundation
let doc = PDFDocument()
for i in 0..<3 {
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 300))
    let data = renderer.pdfData { ctx in
        ctx.beginPage()
        ("Page \(i + 1)" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
    }
    if let page = PDFDocument(data: data)?.page(at: 0) { doc.insert(page, at: i) }
}
let url = URL(fileURLWithPath: "/Users/doyoung_kim/Documents/Git/mana/Data/ArchiveKit/Tests/Resources/sample.pdf")
doc.write(to: url)
'
```
(Cannot run `swift` from CLI without scaffolding — use the Python version first; if PDFKit chokes on it during the test, escalate.)

- [ ] **Step 2: Write failing tests `Data/ArchiveKit/Tests/PDFArchiveReaderTests.swift`**

```swift
import Testing
import Foundation
@testable import ArchiveKit
import Domain

@Suite struct PDFArchiveReaderTests {
    private final class BundleAnchor {}

    private func fixtureURL() throws -> URL {
        let url = Bundle(for: BundleAnchor.self).url(forResource: "sample", withExtension: "pdf")
        try #require(url != nil)
        return url!
    }

    @Test func opensPdfAndReportsThreePages() async throws {
        let reader = PDFArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        #expect(await reader.pageCount(handle) == 3)
        await reader.closeArchive(handle)
    }

    @Test func readsPageAsPNGData() async throws {
        let reader = PDFArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        let data = try await reader.pageData(handle, index: 0)
        // First bytes of PNG: 0x89 0x50 0x4E 0x47
        #expect(data.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]))
        await reader.closeArchive(handle)
    }

    @Test func indexOutOfBoundsThrows() async throws {
        let reader = PDFArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        await #expect(throws: ArchiveError.indexOutOfBounds(99)) {
            _ = try await reader.pageData(handle, index: 99)
        }
        await reader.closeArchive(handle)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `tuist test ArchiveKit`
Expected: 2 new tests fail with compile error.

- [ ] **Step 4: Write `Data/ArchiveKit/Sources/PDFSessionStore.swift`**

```swift
import Foundation
import PDFKit

actor PDFSessionStore {
    static let shared = PDFSessionStore()
    private var documents: [UUID: PDFDocument] = [:]

    func register(_ doc: PDFDocument) -> UUID {
        let id = UUID()
        documents[id] = doc
        return id
    }

    func document(for id: UUID) -> PDFDocument? { documents[id] }

    func close(_ id: UUID) {
        documents.removeValue(forKey: id)
    }
}
```

- [ ] **Step 5: Write `Data/ArchiveKit/Sources/PDFArchiveReader.swift`**

```swift
import Foundation
import UIKit
import PDFKit
import Domain

public struct PDFArchiveReader: ArchiveReader {
    public init() {}

    public func openArchive(at url: URL) async throws -> ArchiveHandle {
        guard let doc = PDFDocument(url: url) else {
            throw ArchiveError.corrupted
        }
        if doc.isLocked {
            throw ArchiveError.encrypted
        }
        let id = await PDFSessionStore.shared.register(doc)
        return ArchiveHandle(id: id)
    }

    public func pageCount(_ handle: ArchiveHandle) async -> Int {
        await PDFSessionStore.shared.document(for: handle.id)?.pageCount ?? 0
    }

    public func pageData(_ handle: ArchiveHandle, index: Int) async throws -> Data {
        guard let doc = await PDFSessionStore.shared.document(for: handle.id) else {
            throw ArchiveError.ioFailure(reason: "handle closed")
        }
        guard index >= 0, index < doc.pageCount, let page = doc.page(at: index) else {
            throw ArchiveError.indexOutOfBounds(index)
        }
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let renderSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        let renderer = UIGraphicsImageRenderer(size: renderSize)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: renderSize))
            ctx.cgContext.translateBy(x: 0, y: renderSize.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
        guard let pngData = image.pngData() else {
            throw ArchiveError.ioFailure(reason: "PNG encoding failed")
        }
        return pngData
    }

    public func closeArchive(_ handle: ArchiveHandle) async {
        await PDFSessionStore.shared.close(handle.id)
    }
}
```

- [ ] **Step 6: Run tests**

Run: `tuist test ArchiveKit`
Expected: 8 tests pass total (5 ZIP + 3 PDF).

- [ ] **Step 7: Commit**

```bash
git add Data/ArchiveKit/Sources/PDFSessionStore.swift Data/ArchiveKit/Sources/PDFArchiveReader.swift Data/ArchiveKit/Tests/PDFArchiveReaderTests.swift Data/ArchiveKit/Tests/Resources/sample.pdf
git commit -m "feat(archive-kit): PDFArchiveReader using PDFKit"
```

---

## Task 4: RarArchiveReader

**Files:**
- Create: `Data/ArchiveKit/Sources/RarSessionStore.swift`
- Create: `Data/ArchiveKit/Sources/RarArchiveReader.swift`
- Create: `Data/ArchiveKit/Tests/Resources/sample.cbr`
- Create: `Data/ArchiveKit/Tests/RarArchiveReaderTests.swift`
- Modify: `Data/ArchiveKit/Project.swift` — add `UnrarKit` external dep

- [ ] **Step 1: Generate fixture `sample.cbr`**

```bash
mkdir -p /tmp/cbr_fixture && cd /tmp/cbr_fixture
printf 'PAGE1' > 001.jpg
printf 'PAGE2-CONTENTS' > 002.jpg
printf 'PAGE3-MORE-CONTENTS' > 003.jpg

# rar CLI is not bundled with macOS. Try macports/brew first; if unavailable, use a vendored binary.
if command -v rar >/dev/null 2>&1; then
    rar a -ep /Users/doyoung_kim/Documents/Git/mana/Data/ArchiveKit/Tests/Resources/sample.cbr 001.jpg 002.jpg 003.jpg
else
    echo "rar CLI not installed. Install with 'brew install rar' (license required)."
    echo "Alternative: download a real RAR test fixture from https://github.com/abbeycode/UnrarKit/tree/master/Tests/Test%20Data"
    echo "Or skip Task 4 — RAR support is the only Plan 2 feature without a CLI-only path."
    exit 1
fi
ls -la /Users/doyoung_kim/Documents/Git/mana/Data/ArchiveKit/Tests/Resources/sample.cbr
```

If `rar` is not available and a license is not desired:
- Copy a small sample RAR from UnrarKit's test fixtures (in their repo); they're MIT-licensed.
- Or use the Python `rarfile` package's reverse — there's no pure-Python encoder.
- Or escalate this task as needing user intervention.

- [ ] **Step 2: Modify `Data/ArchiveKit/Project.swift`**

Add `UnrarKit` to externalDependencies. Read the existing file (it uses fully-spelled `Project(...)` per Task 4 of Plan 1) and add `.external(name: "UnrarKit")` to the `dependencies:` of the `ArchiveKit` framework target.

- [ ] **Step 3: Write failing tests `Data/ArchiveKit/Tests/RarArchiveReaderTests.swift`**

```swift
import Testing
import Foundation
@testable import ArchiveKit
import Domain

@Suite struct RarArchiveReaderTests {
    private final class BundleAnchor {}

    private func fixtureURL() throws -> URL {
        let url = Bundle(for: BundleAnchor.self).url(forResource: "sample", withExtension: "cbr")
        try #require(url != nil)
        return url!
    }

    @Test func opensCbrAndReportsThreePages() async throws {
        let reader = RarArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        #expect(await reader.pageCount(handle) == 3)
        await reader.closeArchive(handle)
    }

    @Test func readsFirstPageBytes() async throws {
        let reader = RarArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        let data = try await reader.pageData(handle, index: 0)
        #expect(String(data: data, encoding: .utf8) == "PAGE1")
        await reader.closeArchive(handle)
    }

    @Test func indexOutOfBoundsThrows() async throws {
        let reader = RarArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        await #expect(throws: ArchiveError.indexOutOfBounds(99)) {
            _ = try await reader.pageData(handle, index: 99)
        }
        await reader.closeArchive(handle)
    }
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `tuist generate --no-open && tuist test ArchiveKit`
Expected: compile failure (`RarArchiveReader` not in scope).

- [ ] **Step 5: Write `Data/ArchiveKit/Sources/RarSessionStore.swift`**

```swift
import Foundation
import UnrarKit

actor RarSessionStore {
    static let shared = RarSessionStore()
    private var archives: [UUID: URKArchive] = [:]
    private var entryNames: [UUID: [String]] = [:]

    func register(_ archive: URKArchive, entryNames: [String]) -> UUID {
        let id = UUID()
        archives[id] = archive
        self.entryNames[id] = entryNames
        return id
    }

    func archive(for id: UUID) -> URKArchive? { archives[id] }
    func entries(for id: UUID) -> [String]? { entryNames[id] }

    func close(_ id: UUID) {
        archives.removeValue(forKey: id)
        entryNames.removeValue(forKey: id)
    }
}
```

- [ ] **Step 6: Write `Data/ArchiveKit/Sources/RarArchiveReader.swift`**

```swift
import Foundation
import UnrarKit
import Domain

public struct RarArchiveReader: ArchiveReader {
    public init() {}

    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "heic"]

    public func openArchive(at url: URL) async throws -> ArchiveHandle {
        do {
            let archive = try URKArchive(url: url)
            let allNames = (try archive.listFilenames()) as? [String] ?? []
            let imageNames = allNames
                .filter {
                    let ext = ($0 as NSString).pathExtension.lowercased()
                    return Self.imageExtensions.contains(ext)
                }
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            let id = await RarSessionStore.shared.register(archive, entryNames: imageNames)
            return ArchiveHandle(id: id)
        } catch let error as NSError where error.domain == "URKErrorDomain" {
            throw map(error)
        } catch {
            throw ArchiveError.ioFailure(reason: error.localizedDescription)
        }
    }

    public func pageCount(_ handle: ArchiveHandle) async -> Int {
        await RarSessionStore.shared.entries(for: handle.id)?.count ?? 0
    }

    public func pageData(_ handle: ArchiveHandle, index: Int) async throws -> Data {
        guard let entries = await RarSessionStore.shared.entries(for: handle.id),
              let archive = await RarSessionStore.shared.archive(for: handle.id)
        else {
            throw ArchiveError.ioFailure(reason: "handle closed")
        }
        guard index >= 0, index < entries.count else {
            throw ArchiveError.indexOutOfBounds(index)
        }
        do {
            let data = try archive.extractData(fromFile: entries[index])
            return data
        } catch let error as NSError where error.domain == "URKErrorDomain" {
            throw map(error)
        } catch {
            throw ArchiveError.ioFailure(reason: error.localizedDescription)
        }
    }

    public func closeArchive(_ handle: ArchiveHandle) async {
        await RarSessionStore.shared.close(handle.id)
    }

    /// Map UnrarKit errors to Domain ArchiveError.
    private func map(_ error: NSError) -> ArchiveError {
        // UnrarKit error codes (URKErrorCode):
        // 1 — bad archive (corrupt)
        // 2 — wrong password
        // 6 — missing password
        let code = error.code
        if code == 2 || code == 6 { return .encrypted }
        if code == 1 { return .corrupted }
        return .ioFailure(reason: error.localizedDescription)
    }
}
```

> Note: UnrarKit's exact API may vary across versions. The above uses the typical 2.x signatures (`URKArchive(url:)`, `listFilenames()`, `extractData(fromFile:)`). If the API differs, adapt while preserving the public surface.

- [ ] **Step 7: Run tests**

Run: `tuist test ArchiveKit`
Expected: all 11 tests pass (5 ZIP + 3 PDF + 3 RAR).

If UnrarKit API differs and you can't get tests to pass within ~30 minutes of trying, escalate as BLOCKED.

- [ ] **Step 8: Commit**

```bash
git add Data/ArchiveKit/
git commit -m "feat(archive-kit): RarArchiveReader via UnrarKit"
```

---

## Task 5: Wire RAR + PDF in DefaultArchiveReaderRouter

**Files:**
- Modify: `Data/ArchiveKit/Sources/DefaultArchiveReaderRouter.swift`

- [ ] **Step 1: Replace the file**

```swift
import Foundation
import Domain

public struct DefaultArchiveReaderRouter: ArchiveReaderRouter {
    private let zip: ZipArchiveReader
    private let rar: RarArchiveReader
    private let pdf: PDFArchiveReader

    public init(
        zip: ZipArchiveReader = ZipArchiveReader(),
        rar: RarArchiveReader = RarArchiveReader(),
        pdf: PDFArchiveReader = PDFArchiveReader()
    ) {
        self.zip = zip
        self.rar = rar
        self.pdf = pdf
    }

    public func reader(for format: ComicFormat) -> any ArchiveReader {
        switch format {
        case .zip, .cbz: return zip
        case .rar, .cbr: return rar
        case .pdf: return pdf
        case .folder:
            // Folder support deferred to a later plan (rare in iOS context).
            preconditionFailure("Folder format not supported")
        }
    }
}
```

- [ ] **Step 2: Update existing routerReturnsZipReaderForCbz test and add cases**

In `Data/ArchiveKit/Tests/ZipArchiveReaderTests.swift`, replace the last test with:

```swift
@Test func routerRoutesByFormat() {
    let router = DefaultArchiveReaderRouter()
    #expect(router.reader(for: .cbz) is ZipArchiveReader)
    #expect(router.reader(for: .zip) is ZipArchiveReader)
    #expect(router.reader(for: .cbr) is RarArchiveReader)
    #expect(router.reader(for: .rar) is RarArchiveReader)
    #expect(router.reader(for: .pdf) is PDFArchiveReader)
}
```

- [ ] **Step 3: Run tests**

Run: `tuist test ArchiveKit`
Expected: 11 tests pass.

- [ ] **Step 4: Commit**

```bash
git add Data/ArchiveKit/
git commit -m "feat(archive-kit): wire RAR + PDF in DefaultArchiveReaderRouter"
```

---

## Task 6: Refactor ReaderFeature to push pageImage to renderers

The Plan 1 review flagged `SinglePageRenderer.load(_:)`'s 3-second polling loop as fragile. We change `PageRenderer` to receive a closure `pageImageProvider: (Int) async -> UIImage?` from the reducer, which reads from `ImageCache` once. This way the renderer awaits a single async call instead of polling.

The reducer's prefetch logic stays the same; the renderer just stops polling.

**Files:**
- Modify: `Features/ReaderFeature/Sources/PageRenderer.swift`
- Modify: `Features/ReaderFeature/Sources/SinglePageRenderer.swift`
- Modify: `Features/ReaderFeature/Sources/ReaderView.swift`
- Modify: `Features/ReaderFeature/Tests/ReaderFeatureTests.swift` — adapt assertions if any

- [ ] **Step 1: Update `PageRenderer.swift`**

```swift
import SwiftUI
import UIKit

public protocol PageRenderer: View {
    init(
        totalPages: Int,
        current: Binding<Int>,
        pageImage: @escaping (Int) async -> UIImage?,
        onPrefetchHint: @escaping (Int) -> Void
    )
}
```

- [ ] **Step 2: Rewrite `SinglePageRenderer.swift`**

```swift
import SwiftUI
import UIKit
import SharedUI

public struct SinglePageRenderer: View, PageRenderer {
    let totalPages: Int
    @Binding var current: Int
    let pageImage: (Int) async -> UIImage?
    let onPrefetchHint: (Int) -> Void

    @State private var image: UIImage?
    @State private var loadingIndex: Int?

    public init(
        totalPages: Int,
        current: Binding<Int>,
        pageImage: @escaping (Int) async -> UIImage?,
        onPrefetchHint: @escaping (Int) -> Void
    ) {
        self.totalPages = totalPages
        self._current = current
        self.pageImage = pageImage
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
        onPrefetchHint(index)
        // Try cache once; if miss, wait for prefetch to finish via continuation polling
        // limited to 30 retries (~1.5s max).
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

> Note: We still poll, but: (a) shorter (1.5 s vs 3 s), (b) the polling is the renderer's own resilience for slow prefetches, not a workaround for missing data. Plan 3+ will replace this with reducer-driven push notifications.

The `ComicIdKey` environment from Plan 1 is no longer needed — remove it. The reducer constructs `pageImage` with `comicId` baked in.

- [ ] **Step 3: Rewrite `ReaderView.swift`**

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
                renderer
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

        switch store.mode {
        case .single:
            SinglePageRenderer(
                totalPages: store.pageCount,
                current: binding,
                pageImage: provider,
                onPrefetchHint: hint
            )
        case .dual:
            DualPageRenderer(
                totalPages: store.pageCount,
                current: binding,
                pageImage: provider,
                onPrefetchHint: hint
            )
        case .scroll(let direction):
            ScrollPageRenderer(
                totalPages: store.pageCount,
                current: binding,
                pageImage: provider,
                onPrefetchHint: hint,
                direction: direction
            )
        }
    }
}
```

- [ ] **Step 4: Verify existing tests still pass**

Run: `tuist test ReaderFeature`
Expected: 2 tests still pass (no changes to reducer logic in this task).

- [ ] **Step 5: Commit**

```bash
git add Features/ReaderFeature/
git commit -m "refactor(reader-feature): renderers receive pageImage closure (no cache polling)"
```

---

## Task 7: DualPageRenderer

**Files:**
- Create: `Features/ReaderFeature/Sources/DualPageRenderer.swift`

- [ ] **Step 1: Write `DualPageRenderer.swift`**

```swift
import SwiftUI
import UIKit
import SharedUI

public struct DualPageRenderer: View, PageRenderer {
    let totalPages: Int
    @Binding var current: Int
    let pageImage: (Int) async -> UIImage?
    let onPrefetchHint: (Int) -> Void

    @State private var leftImage: UIImage?
    @State private var rightImage: UIImage?

    public init(
        totalPages: Int,
        current: Binding<Int>,
        pageImage: @escaping (Int) async -> UIImage?,
        onPrefetchHint: @escaping (Int) -> Void
    ) {
        self.totalPages = totalPages
        self._current = current
        self.pageImage = pageImage
        self.onPrefetchHint = onPrefetchHint
    }

    /// In dual mode `current` is treated as the left page; right page = current + 1.
    public var body: some View {
        HStack(spacing: 0) {
            pane(image: leftImage)
            pane(image: rightImage)
        }
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width < -50, current + 2 < totalPages {
                        current += 2
                    } else if value.translation.width > 50, current >= 2 {
                        current -= 2
                    }
                }
        )
        .task(id: current) {
            await loadPair()
        }
    }

    @ViewBuilder
    private func pane(image: UIImage?) -> some View {
        if let image {
            ZoomableImageView(image: image)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

- [ ] **Step 2: Build to verify**

Run: `tuist generate --no-open && xcodebuild -workspace Mana.xcworkspace -scheme ReaderFeature build CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Features/ReaderFeature/Sources/DualPageRenderer.swift
git commit -m "feat(reader-feature): DualPageRenderer for book layout"
```

---

## Task 8: ScrollPageRenderer (LTR/RTL/TTB)

**Files:**
- Create: `Features/ReaderFeature/Sources/ScrollPageRenderer.swift`

- [ ] **Step 1: Write `ScrollPageRenderer.swift`**

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
        onPrefetchHint: @escaping (Int) -> Void
    ) {
        self.init(
            totalPages: totalPages,
            current: current,
            pageImage: pageImage,
            onPrefetchHint: onPrefetchHint,
            direction: .ttb
        )
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
            ScrollView(scrollAxis) {
                content(proxy: proxy)
            }
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
            LazyVStack(spacing: 0) {
                pages
            }
            .onAppear { proxy.scrollTo(current, anchor: .top) }
        } else {
            LazyHStack(spacing: 0) {
                pages
            }
            .onAppear { proxy.scrollTo(current, anchor: .leading) }
        }
    }

    @ViewBuilder
    private var pages: some View {
        ForEach(0..<totalPages, id: \.self) { index in
            page(at: index)
                .id(index)
                .onAppear { current = index; onPrefetchHint(index) }
        }
    }

    @ViewBuilder
    private func page(at index: Int) -> some View {
        if let img = images[index] {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Color.black
                .frame(minWidth: 320, minHeight: 480)
                .overlay(ProgressView().tint(.white))
                .task(id: index) {
                    if let img = await pageImage(index) {
                        images[index] = img
                    }
                }
        }
    }
}
```

> Pinch-to-zoom on continuous scroll is intentionally limited in this version — Plan 4 polishes scroll-mode zoom. For now, fit-to-width (LTR/RTL) or fit-to-height (TTB) is acceptable.

- [ ] **Step 2: Build**

Run: `xcodebuild -workspace Mana.xcworkspace -scheme ReaderFeature build CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Features/ReaderFeature/Sources/ScrollPageRenderer.swift
git commit -m "feat(reader-feature): ScrollPageRenderer for LTR/RTL/TTB continuous scroll"
```

---

## Task 9: Per-comic reading mode persistence

Persist `ReadingMode` per comic so the next open resumes the user's last choice. Default to a global setting (added in Task 11).

**Files:**
- Modify: `Domain/Sources/Models/ComicItem.swift` — add `readingMode: ReadingMode?` field
- Modify: `Data/PersistenceKit/Sources/SwiftDataModels.swift` — add `readingModeRaw: String?`
- Modify: `Data/PersistenceKit/Sources/ComicRepositoryLive.swift` — round-trip new field
- Modify: `Data/PersistenceKit/Tests/ComicRepositoryLiveTests.swift` — assertion for round-trip
- Modify: `Features/ReaderFeature/Sources/ReaderFeature.swift` — accept default mode, persist on change

- [ ] **Step 1: Add encoding helpers in Domain**

Modify `Domain/Sources/Models/ReadingMode.swift` — append:

```swift
extension ReadingMode {
    public var rawString: String {
        switch self {
        case .single: return "single"
        case .dual: return "dual"
        case .scroll(let dir): return "scroll-\(dir.rawValue)"
        }
    }

    public init?(rawString: String) {
        switch rawString {
        case "single": self = .single
        case "dual": self = .dual
        case "scroll-ltr": self = .scroll(direction: .ltr)
        case "scroll-rtl": self = .scroll(direction: .rtl)
        case "scroll-ttb": self = .scroll(direction: .ttb)
        default: return nil
        }
    }
}
```

- [ ] **Step 2: Add field to ComicItem**

Edit `Domain/Sources/Models/ComicItem.swift` — add `readingMode: ReadingMode?` (Optional). Update the initializer accordingly. Existing call sites pass `readingMode: nil`.

- [ ] **Step 3: Add field to ComicEntity**

In `Data/PersistenceKit/Sources/SwiftDataModels.swift`, add `public var readingModeRaw: String?` to `ComicEntity`. Update `init`, `toModel()`, and `from(_:)` to handle it.

- [ ] **Step 4: Update tests in PersistenceKit**

Add to `ComicRepositoryLiveTests.swift`:

```swift
@Test func roundTripsReadingMode() async throws {
    let stack = try makeStack()
    let repo = ComicRepositoryLive(stack: stack)
    let id = UUID()
    let item = ComicItem(
        id: id,
        url: URL(fileURLWithPath: "/tmp/y.cbz"),
        format: .cbz,
        title: "Y",
        pageCount: 5,
        coverThumbnail: nil,
        dateAdded: .init(timeIntervalSince1970: 0),
        fileSizeBytes: 1,
        readingMode: .scroll(direction: .rtl)
    )
    try await repo.upsert(item)
    let loaded = await repo.all()
    #expect(loaded.first?.readingMode == .scroll(direction: .rtl))
}
```

Update existing test fixtures to include `readingMode: nil`.

- [ ] **Step 5: ReaderFeature — load and persist mode**

In `ReaderFeature.swift`:

1. Add `var defaultMode: ReadingMode = .single` (could come from Settings later) and remove hard-coded `.single` default in State init.
2. On `.task`, if `state.comic.readingMode != nil`, set `state.mode = state.comic.readingMode!`. Else use defaultMode.
3. Add new action `case modeChanged(ReadingMode)` that updates state and persists via comicRepository.

Add this case to the reducer body:

```swift
case let .modeChanged(mode):
    state.mode = mode
    let updated = ComicItem(
        id: state.comic.id,
        url: state.comic.url,
        format: state.comic.format,
        title: state.comic.title,
        pageCount: state.comic.pageCount,
        coverThumbnail: state.comic.coverThumbnail,
        dateAdded: state.comic.dateAdded,
        fileSizeBytes: state.comic.fileSizeBytes,
        readingMode: mode
    )
    state.comic = updated
    @Dependency(\.comicRepository) var repo
    return .run { _ in
        try? await repo.upsert(updated)
    }
```

(The `@Dependency` access inside the case is unusual; better, declare it at the struct level next to the others.)

Add at struct level:
```swift
@Dependency(\.comicRepository) var comicRepo
```
And replace the inline access above with `comicRepo`.

In `.task`, after `.opened`, if the comic has a saved mode, send `.modeChanged(savedMode)` (will not write since same value). Or better: set `state.mode` directly in `.opened` based on `state.comic.readingMode`.

- [ ] **Step 6: Add reducer test for mode persistence**

In `ReaderFeatureTests.swift`, add:

```swift
@Test func modeChangedPersistsToRepo() async {
    let comic = sampleComic()
    let repo = StubComicRepo(initial: [comic])
    let store = await TestStore(initialState: ReaderFeature.State(comic: comic, pageCount: 5)) {
        ReaderFeature()
    } withDependencies: {
        $0.archiveReaderRouter = StubRouter(reader: StubReader(handle: ArchiveHandle(), pages: []))
        $0.progressRepository = InMemoryProgressRepo(initial: [])
        $0.imageCache = ImageCache.inMemoryOnly()
        $0.mainQueue = .immediate
        $0.comicRepository = repo
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.modeChanged(.scroll(direction: .rtl))) {
        $0.mode = .scroll(direction: .rtl)
        $0.comic = ComicItem(
            id: comic.id, url: comic.url, format: comic.format, title: comic.title,
            pageCount: comic.pageCount, coverThumbnail: comic.coverThumbnail,
            dateAdded: comic.dateAdded, fileSizeBytes: comic.fileSizeBytes,
            readingMode: .scroll(direction: .rtl)
        )
    }
    // Allow the persistence effect to flush
    let stored = await repo.all()
    #expect(stored.first?.readingMode == .scroll(direction: .rtl))
}
```

(Add `StubComicRepo` from LibraryFeatureTests if not already in scope — share via test helpers.)

- [ ] **Step 7: Run tests**

```bash
tuist test PersistenceKit
tuist test ReaderFeature
tuist test LibraryFeature
```
Expected: all pass.

- [ ] **Step 8: Commit**

```bash
git add Domain/ Data/PersistenceKit/ Features/ReaderFeature/
git commit -m "feat: per-comic reading mode persistence"
```

---

## Task 10: BookmarksFeature

**Files:**
- Create: `Features/BookmarksFeature/Project.swift`
- Create: `Features/BookmarksFeature/Sources/BookmarksFeature.swift`
- Create: `Features/BookmarksFeature/Sources/BookmarksView.swift`
- Test: `Features/BookmarksFeature/Tests/BookmarksFeatureTests.swift`

- [ ] **Step 1: Write `Features/BookmarksFeature/Project.swift`**

```swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "BookmarksFeature",
    kind: .feature,
    dependencies: [.project(target: "Domain", path: "../../Domain")],
    externalDependencies: ["ComposableArchitecture"],
    hasTests: true
).project()
```

- [ ] **Step 2: Write failing tests `Features/BookmarksFeature/Tests/BookmarksFeatureTests.swift`**

```swift
import Testing
import Foundation
import ComposableArchitecture
@testable import BookmarksFeature
import Domain

@MainActor
@Suite struct BookmarksFeatureTests {

    @Test func taskLoadsBookmarks() async {
        let comicId = UUID()
        let bm = Bookmark(id: UUID(), comicId: comicId, pageIndex: 4, note: "good", createdAt: .init(timeIntervalSince1970: 0))
        let repo = StubBookmarkRepo(initial: [bm])

        let store = await TestStore(initialState: BookmarksFeature.State(comicId: comicId)) {
            BookmarksFeature()
        } withDependencies: {
            $0.bookmarkRepository = repo
        }

        await store.send(.task)
        await store.receive(\.refreshed) {
            $0.bookmarks = IdentifiedArray(uniqueElements: [bm])
        }
    }

    @Test func addBookmarkInserts() async {
        let comicId = UUID()
        let repo = StubBookmarkRepo(initial: [])
        let store = await TestStore(initialState: BookmarksFeature.State(comicId: comicId)) {
            BookmarksFeature()
        } withDependencies: {
            $0.bookmarkRepository = repo
            $0.uuid = .incrementing
            $0.date.now = .init(timeIntervalSince1970: 100)
        }

        await store.send(.addRequested(pageIndex: 7, note: "bm1")) {
            $0.bookmarks.append(Bookmark(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
                comicId: comicId,
                pageIndex: 7,
                note: "bm1",
                createdAt: .init(timeIntervalSince1970: 100)
            ))
        }
    }
}

actor StubBookmarkRepo: BookmarkRepository {
    private var items: [Bookmark]
    init(initial: [Bookmark]) { self.items = initial }
    func bookmarks(comicId: UUID) async -> [Bookmark] {
        items.filter { $0.comicId == comicId }.sorted { $0.pageIndex < $1.pageIndex }
    }
    func add(_ b: Bookmark) async throws { items.append(b) }
    func remove(id: UUID) async throws { items.removeAll { $0.id == id } }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `tuist generate --no-open && tuist test BookmarksFeature`

- [ ] **Step 4: Write `Features/BookmarksFeature/Sources/BookmarksFeature.swift`**

```swift
import Foundation
import ComposableArchitecture
import Domain

@Reducer
public struct BookmarksFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public let comicId: UUID
        public var bookmarks: IdentifiedArrayOf<Bookmark> = []

        public init(comicId: UUID, bookmarks: IdentifiedArrayOf<Bookmark> = []) {
            self.comicId = comicId
            self.bookmarks = bookmarks
        }
    }

    public enum Action {
        case task
        case refreshed([Bookmark])
        case addRequested(pageIndex: Int, note: String?)
        case bookmarkAdded(Bookmark)
        case removeRequested(UUID)
        case bookmarkRemoved(UUID)
        case tapped(Bookmark)        // navigate to page; parent handles
    }

    @Dependency(\.bookmarkRepository) var repo
    @Dependency(\.uuid) var uuid
    @Dependency(\.date.now) var now

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let comicId = state.comicId
                return .run { send in
                    let items = await repo.bookmarks(comicId: comicId)
                    await send(.refreshed(items))
                }

            case let .refreshed(items):
                state.bookmarks = IdentifiedArray(uniqueElements: items)
                return .none

            case let .addRequested(pageIndex, note):
                let bm = Bookmark(id: uuid(), comicId: state.comicId, pageIndex: pageIndex, note: note, createdAt: now)
                state.bookmarks.append(bm)
                return .run { send in
                    try? await repo.add(bm)
                    await send(.bookmarkAdded(bm))
                }

            case .bookmarkAdded:
                return .none

            case let .removeRequested(id):
                state.bookmarks.remove(id: id)
                return .run { send in
                    try? await repo.remove(id: id)
                    await send(.bookmarkRemoved(id))
                }

            case .bookmarkRemoved:
                return .none

            case .tapped:
                return .none
            }
        }
    }
}

private enum BookmarkRepositoryKey: DependencyKey {
    static let liveValue: any BookmarkRepository = LiveBookmarkRepoPlaceholder()
}

private struct LiveBookmarkRepoPlaceholder: BookmarkRepository {
    func bookmarks(comicId: UUID) async -> [Bookmark] { [] }
    func add(_ b: Bookmark) async throws {}
    func remove(id: UUID) async throws {}
}

extension DependencyValues {
    public var bookmarkRepository: any BookmarkRepository {
        get { self[BookmarkRepositoryKey.self] }
        set { self[BookmarkRepositoryKey.self] = newValue }
    }
}
```

- [ ] **Step 5: Write `Features/BookmarksFeature/Sources/BookmarksView.swift`**

```swift
import SwiftUI
import ComposableArchitecture
import Domain

public struct BookmarksView: View {
    @Bindable public var store: StoreOf<BookmarksFeature>

    public init(store: StoreOf<BookmarksFeature>) { self.store = store }

    public var body: some View {
        List {
            if store.bookmarks.isEmpty {
                ContentUnavailableView("No bookmarks", systemImage: "bookmark")
            } else {
                ForEach(store.bookmarks) { bm in
                    Button {
                        store.send(.tapped(bm))
                    } label: {
                        VStack(alignment: .leading) {
                            Text("Page \(bm.pageIndex + 1)").font(.headline)
                            if let note = bm.note, !note.isEmpty {
                                Text(note).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            store.send(.removeRequested(bm.id))
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .navigationTitle("Bookmarks")
        .task { await store.send(.task).finish() }
    }
}
```

- [ ] **Step 6: Run tests**

Run: `tuist test BookmarksFeature`
Expected: 2 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add Features/BookmarksFeature/ Workspace.swift
git commit -m "feat(bookmarks-feature): TCA reducer + view"
```

> Workspace.swift: add `"Features/BookmarksFeature"` to projects.

---

## Task 11: SettingsFeature (default reading mode)

Minimal: a single setting — global default reading mode for newly opened comics that don't have their own.

**Files:**
- Create: `Features/SettingsFeature/Project.swift`
- Create: `Features/SettingsFeature/Sources/SettingsFeature.swift`
- Create: `Features/SettingsFeature/Sources/SettingsView.swift`
- Test: `Features/SettingsFeature/Tests/SettingsFeatureTests.swift`

- [ ] **Step 1: Write `Features/SettingsFeature/Project.swift`**

```swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "SettingsFeature",
    kind: .feature,
    dependencies: [.project(target: "Domain", path: "../../Domain")],
    externalDependencies: ["ComposableArchitecture"],
    hasTests: true
).project()
```

- [ ] **Step 2: Write tests `Features/SettingsFeature/Tests/SettingsFeatureTests.swift`**

```swift
import Testing
import Foundation
import ComposableArchitecture
@testable import SettingsFeature
import Domain

@MainActor
@Suite struct SettingsFeatureTests {

    @Test func defaultsToSingleMode() async {
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.task)
        // No-op state load
        #expect(store.state.defaultMode == .single)
    }

    @Test func setDefaultModeUpdatesState() async {
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.defaultModeChanged(.scroll(direction: .rtl))) {
            $0.defaultMode = .scroll(direction: .rtl)
        }
    }
}
```

- [ ] **Step 3: Write `Features/SettingsFeature/Sources/SettingsFeature.swift`**

```swift
import Foundation
import ComposableArchitecture
import Domain

@Reducer
public struct SettingsFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var defaultMode: ReadingMode = .single

        public init(defaultMode: ReadingMode = .single) {
            self.defaultMode = defaultMode
        }
    }

    public enum Action {
        case task
        case defaultModeChanged(ReadingMode)
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
                return .none

            case let .defaultModeChanged(mode):
                state.defaultMode = mode
                defaults.set(mode.rawString, forKey: Self.modeKey)
                return .none
            }
        }
    }

    static let modeKey = "mana.defaultReadingMode"
}

public protocol UserDefaultsClient: Sendable {
    func string(forKey key: String) -> String?
    func set(_ value: String, forKey key: String)
}

public struct LiveUserDefaultsClient: UserDefaultsClient {
    public init() {}
    public func string(forKey key: String) -> String? {
        UserDefaults.standard.string(forKey: key)
    }
    public func set(_ value: String, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

public struct InMemoryUserDefaults: UserDefaultsClient {
    private final class Storage: @unchecked Sendable {
        var values: [String: String] = [:]
        let lock = NSLock()
    }
    private let storage = Storage()
    public init() {}
    public func string(forKey key: String) -> String? {
        storage.lock.lock(); defer { storage.lock.unlock() }
        return storage.values[key]
    }
    public func set(_ value: String, forKey key: String) {
        storage.lock.lock(); defer { storage.lock.unlock() }
        storage.values[key] = value
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

- [ ] **Step 4: Write `Features/SettingsFeature/Sources/SettingsView.swift`**

```swift
import SwiftUI
import ComposableArchitecture
import Domain

public struct SettingsView: View {
    @Bindable public var store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) { self.store = store }

    public var body: some View {
        Form {
            Section("Default reading mode") {
                Picker("Mode", selection: Binding(
                    get: { store.defaultMode },
                    set: { store.send(.defaultModeChanged($0)) }
                )) {
                    Text("Single").tag(ReadingMode.single)
                    Text("Dual").tag(ReadingMode.dual)
                    Text("Scroll LTR").tag(ReadingMode.scroll(direction: .ltr))
                    Text("Scroll RTL").tag(ReadingMode.scroll(direction: .rtl))
                    Text("Scroll TTB (Webtoon)").tag(ReadingMode.scroll(direction: .ttb))
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Settings")
        .task { await store.send(.task).finish() }
    }
}
```

- [ ] **Step 5: Run tests**

Run: `tuist test SettingsFeature`
Expected: 2 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add Features/SettingsFeature/ Workspace.swift
git commit -m "feat(settings-feature): default reading mode preference"
```

> Workspace.swift: add `"Features/SettingsFeature"`.

---

## Task 12: AppFeature wires Bookmarks + Settings into Path

**Files:**
- Modify: `Features/AppFeature/Project.swift` — add new feature deps
- Modify: `Features/AppFeature/Sources/AppFeature.swift` — extend Path enum
- Modify: `Features/AppFeature/Sources/AppView.swift` — destinations, sidebar links
- Modify: `Features/LibraryFeature/Sources/LibraryView.swift` — add settings + bookmarks toolbar items if relevant. Bookmarks per comic accessed FROM reader; settings is accessible from library top-level.

- [ ] **Step 1: Update `AppFeature/Project.swift`**

Add dependencies on `BookmarksFeature` and `SettingsFeature`.

- [ ] **Step 2: Update `AppFeature.swift` Path enum**

```swift
@Reducer
public enum Path {
    case reader(ReaderFeature)
    case bookmarks(BookmarksFeature)
    case settings(SettingsFeature)
}
```

Add to body's `Reduce`:

```swift
// When library asks for settings:
case .library(.settingsTapped):
    state.path.append(.settings(SettingsFeature.State()))
    return .none

// When reader asks for bookmarks:
case let .path(.element(_, .reader(.bookmarksTapped(comicId)))):
    state.path.append(.bookmarks(BookmarksFeature.State(comicId: comicId)))
    return .none

// When a bookmark is tapped, jump back to the reader:
case let .path(.element(id, .bookmarks(.tapped(bookmark)))):
    // Find the reader on the stack and jump
    state.path.removeLast()
    if case let .reader(readerState) = state.path.last,
       readerState.comic.id == bookmark.comicId {
        // can't mutate enum case directly via path.last easily; in-place edit:
        if let lastIdx = state.path.indices.last {
            if case var .reader(rs) = state.path[lastIdx] {
                rs.pageIndex = bookmark.pageIndex
                state.path[lastIdx] = .reader(rs)
            }
        }
    }
    return .none
```

The `.path(.element(_, ...))` pattern matching of nested actions in TCA enum-Path: confirm the TCA 1.25.5 syntax. If `.element(id:, action:)` is required, adapt.

Also keep the Plan 1 case:
```swift
case let .library(.comicTapped(comic)):
    state.path.append(.reader(ReaderFeature.State(comic: comic)))
    return .none
```

Path.State Equatable extension needs to cover all three cases — already exists from Plan 1, just verify.

- [ ] **Step 3: Update `AppView.swift`**

```swift
} destination: { store in
    switch store.case {
    case let .reader(readerStore):
        ReaderView(store: readerStore)
    case let .bookmarks(bmStore):
        BookmarksView(store: bmStore)
    case let .settings(settingsStore):
        SettingsView(store: settingsStore)
    }
}
```

- [ ] **Step 4: Add `settingsTapped` action to LibraryFeature**

In `LibraryFeature.swift` add `case settingsTapped` to Action and a no-op handler (parent observes). Add a settings button to LibraryView toolbar:

```swift
ToolbarItem(placement: .navigation) {
    Button {
        store.send(.settingsTapped)
    } label: {
        Image(systemName: "gearshape")
    }
}
```

- [ ] **Step 5: Add `bookmarksTapped` action to ReaderFeature**

In `ReaderFeature.swift` add `case bookmarksTapped(comicId: UUID)` to Action with no-op handler. Add a button to the GlassToolbar overlay in ReaderView:

```swift
GlassToolbar {
    Text("\(store.pageIndex + 1) / \(store.pageCount)")
        .foregroundStyle(.white)
    Spacer()
    Button {
        store.send(.bookmarksTapped(comicId: store.comic.id))
    } label: {
        Image(systemName: "bookmark")
    }
}
```

- [ ] **Step 6: Build and test**

```bash
tuist generate --no-open
xcodebuild -workspace Mana.xcworkspace -scheme Mana build CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)'
xcodebuild test -workspace Mana.xcworkspace -scheme Mana CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)'
```
Expected: BUILD SUCCEEDED, integration test PASS.

- [ ] **Step 7: Commit**

```bash
git add Features/AppFeature/ Features/LibraryFeature/ Features/ReaderFeature/
git commit -m "feat(app): wire Bookmarks + Settings into navigation Path"
```

---

## Task 13: Wire live dependencies for Bookmarks, Settings, Thumbnails

**Files:**
- Modify: `App/Project.swift` — add deps on BookmarksFeature, SettingsFeature, ThumbnailKit
- Modify: `App/Sources/DependenciesLive.swift` — register all
- Modify: `App/Sources/LibraryImporterLive.swift` — use ThumbnailProviderLive instead of raw page0 bytes

- [ ] **Step 1: Update `App/Project.swift`**

Add to dependencies:
```swift
.project(target: "BookmarksFeature", path: "../Features/BookmarksFeature"),
.project(target: "SettingsFeature", path: "../Features/SettingsFeature"),
.project(target: "ThumbnailKit", path: "../Data/ThumbnailKit"),
```

- [ ] **Step 2: Rewrite `App/Sources/LibraryImporterLive.swift`**

```swift
import Foundation
import Domain
import ArchiveKit
import ImageCacheKit
import ThumbnailKit
import LibraryFeature

public struct LibraryImporterLive: LibraryImporter {
    let repo: any ComicRepository
    let router: any ArchiveReaderRouter
    let cache: ImageCache
    let thumbnails: ThumbnailProviderLive

    public init(
        repo: any ComicRepository,
        router: any ArchiveReaderRouter,
        cache: ImageCache,
        thumbnails: ThumbnailProviderLive
    ) {
        self.repo = repo
        self.router = router
        self.cache = cache
        self.thumbnails = thumbnails
    }

    public func importFiles(_ urls: [URL]) async throws -> [ComicItem] {
        var results: [ComicItem] = []
        for url in urls {
            let needsStop = url.startAccessingSecurityScopedResource()
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }

            let format: ComicFormat
            if let f = ComicFormat(fileExtension: url.pathExtension) {
                format = f
            } else {
                throw ArchiveError.unsupportedFormat(url.pathExtension)
            }

            let reader = router.reader(for: format)
            let handle = try await reader.openArchive(at: url)
            let pageCount = await reader.pageCount(handle)
            let id = UUID()

            var thumb: Data?
            if pageCount > 0, let raw = try? await reader.pageData(handle, index: 0) {
                thumb = try? await thumbnails.storeThumbnail(comicId: id, page: 0, rawPageBytes: raw, maxDim: 256)
            }
            await reader.closeArchive(handle)

            let title = url.deletingPathExtension().lastPathComponent
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0

            let item = ComicItem(
                id: id,
                url: url,
                format: format,
                title: title,
                pageCount: pageCount,
                coverThumbnail: thumb,           // now small (<100KB) JPEG
                dateAdded: Date(),
                fileSizeBytes: size,
                readingMode: nil
            )
            try await repo.upsert(item)
            results.append(item)
        }
        return results
    }
}
```

- [ ] **Step 3: Update `App/Sources/DependenciesLive.swift`**

```swift
import Foundation
import ComposableArchitecture
import Domain
import ArchiveKit
import PersistenceKit
import ImageCacheKit
import ThumbnailKit
import LibraryFeature
import ReaderFeature
import BookmarksFeature
import SettingsFeature

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
        let thumbnails = ThumbnailProviderLive(
            cacheDir: URL.cachesDirectory.appending(path: "mana-thumbs")
        )
        let importer = LibraryImporterLive(
            repo: comicRepo, router: router, cache: cache, thumbnails: thumbnails
        )

        prepareDependencies {
            $0.archiveReaderRouter = router
            $0.progressRepository = progressRepo
            $0.imageCache = cache
            $0.comicRepository = comicRepo
            $0.libraryImporter = importer
            $0.bookmarkRepository = bookmarkRepo
            $0.userDefaults = LiveUserDefaultsClient()
        }
    }
}
```

- [ ] **Step 4: Build and re-run integration test**

```bash
tuist generate --no-open
xcodebuild build -workspace Mana.xcworkspace -scheme Mana CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)'
xcodebuild test -workspace Mana.xcworkspace -scheme Mana CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)'
```

The integration test in `App/Tests/IntegrationFlowTests.swift` will need updating because `LibraryImporterLive` now requires a `thumbnails` parameter. Update the test:

```swift
let thumbnails = ThumbnailProviderLive(cacheDir: FileManager.default.temporaryDirectory.appending(path: "thumbs-\(UUID())"))
let importer = LibraryImporterLive(repo: comicRepo, router: router, cache: cache, thumbnails: thumbnails)
```

And the fixture's coverThumbnail expectation: instead of `comic.coverThumbnail != nil`, also assert `comic.coverThumbnail!.count < 1000` (downsampled).

Also import `ThumbnailKit` in the test file.

- [ ] **Step 5: Smoke test**

Launch the app on simulator. Verify:
- Library `+` toolbar imports a `.cbz` (still works)
- Library row shows a small thumbnail (no longer giant)
- Tap comic → reader opens
- Reader toolbar (tap to show) has a bookmark button
- Tap bookmark → bookmarks list appears (empty initially)
- Library has a gear icon → settings → can change default mode

If a smoke test reveals breakages, fix and re-test.

- [ ] **Step 6: Commit**

```bash
git add App/
git commit -m "feat(app): wire BookmarkRepository, ThumbnailProvider, and Settings UserDefaults"
```

---

## Plan 2 Completion Checklist

- [ ] All module unit tests pass
- [ ] Integration test passes (with thumbnail size assertion)
- [ ] App builds for iPad simulator
- [ ] Manual smoke test:
  - [ ] Import .cbz, .cbr, .pdf — all import successfully
  - [ ] Library row thumbnails are small images
  - [ ] Open a comic → can switch among single / dual / scroll-RTL via in-reader (use a long-press menu or settings if not yet exposed; otherwise default-mode through Settings)
  - [ ] Add bookmark → appears in bookmark list
  - [ ] Tap bookmark → reader navigates to that page
  - [ ] Settings → default mode persists across app relaunch

## What's Next (Plan 3 preview)

- SwiftData CloudKit container for syncing ComicItem/Progress/Bookmark
- iCloud Drive ubiquity container for ZIP/CBZ/RAR/PDF files
- `FileSyncService` (Domain protocol already exists) implementation
- "Cross-device pickup" (importing a comic on iPad shows up on iPhone with cloud-download indicator)

Plan 4 polishes Liquid Glass design + sort/filter + dark mode.

# Mana — Plan 4: Liquid Glass Design + Sort/Filter + Polish

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use `- [ ]` checkboxes.

**Goal:** Wrap up V2 with Liquid Glass design adoption, library sort/filter, dark-mode-aware tokens, an "add bookmark with note" sheet, and a few cleanup items the prior reviews flagged.

**Architecture:** Pure additions on top of Plan 3. DesignSystem grows from a placeholder into a real module with Liquid Glass primitives, color tokens (Asset Catalog with light/dark variants), and a small set of components consumers already use (`GlassToolbar`). LibraryFeature gains `sort: SortOrder` and `filter: LibraryFilter` in State; LibraryView surfaces them in the toolbar.

**Tech Stack:** Same as Plan 3. Liquid Glass APIs (iOS 26 SDK): `Glass`, `GlassButtonStyle`, `GlassEffectContainer`, `.glassEffect()` and `.glassEffect(.regular, in:)` modifiers — exact spelling determined empirically in Task 1 (the placeholder GlassToolbar used `.thinMaterial` because the implementer's earlier probe didn't find `.glassEffect(in:)`; this plan probes more carefully).

---

## File Structure (added/modified)

```
Mana/
├── DesignSystem/
│   ├── Sources/
│   │   ├── Tokens.swift                          [M] — add Color tokens
│   │   ├── GlassToolbar.swift                    [M] — adopt Liquid Glass API
│   │   ├── ColorTokens.swift                     [+] — typed Color accessors
│   │   └── DSColors.xcassets/                    [+] — Asset Catalog with light/dark variants
│   │       ├── BackgroundPrimary.colorset/Contents.json
│   │       ├── BackgroundSecondary.colorset/Contents.json
│   │       ├── Accent.colorset/Contents.json
│   │       ├── OnGlassPrimary.colorset/Contents.json
│   │       └── OnGlassSecondary.colorset/Contents.json
│   └── Project.swift                             [M] — hasResources: true
├── Features/
│   ├── LibraryFeature/
│   │   ├── Sources/
│   │   │   ├── LibraryFeature.swift              [M] — add sort + filter
│   │   │   ├── LibraryView.swift                 [M] — sort/filter UI
│   │   │   └── LibraryRow.swift                  [M] — use Color tokens
│   │   └── Tests/LibraryFeatureTests.swift       [M] — sort/filter tests
│   ├── BookmarksFeature/
│   │   ├── Sources/
│   │   │   ├── BookmarksFeature.swift            [M] — addRequested gets note sheet flow
│   │   │   ├── BookmarkSheet.swift               [+] — note input view
│   │   │   └── BookmarksView.swift               [M] — present sheet
│   │   └── Tests/BookmarksFeatureTests.swift     [M]
│   ├── ReaderFeature/Sources/ReaderFeature.swift [M] — security scope teardown on disappear
│   └── ReaderFeature/Sources/ReaderView.swift    [M] — use Color tokens
└── Data/PersistenceKit/Sources/BookmarkRepositoryLive.swift [M] — dedupe by (comicId, pageIndex)
```

---

## Conventions

- Module helper still in use; pass `hasResources: true` for DesignSystem
- Add `import DesignSystem` wherever Color tokens are used; replace direct `Color.gray.opacity(...)` etc.
- Test runner: `xcodebuild test -workspace Mana.xcworkspace -scheme <Module> CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)'`
- Workspace regen: `./Scripts/setup.sh`

---

## Task 1: Probe + adopt Liquid Glass API

**Files:**
- Modify: `DesignSystem/Sources/GlassToolbar.swift`

The implementer probes the iOS 26.4 SDK to find the actual Liquid Glass call site, then rewrites `GlassToolbar` to use it. Plan 2's interim used `.background(.thinMaterial, in: .capsule)`.

- [ ] **Step 1: Probe SDK availability**

In a temporary scratch file (or in the source itself, then revert), try compiling each variant:

```swift
// Variant A: bare modifier
HStack { Text("x") }.glassEffect()

// Variant B: with shape
HStack { Text("x") }.glassEffect(in: .capsule)

// Variant C: with style + shape
HStack { Text("x") }.glassEffect(.regular, in: .capsule)

// Variant D: GlassEffectContainer wrapper
GlassEffectContainer {
    HStack { Text("x") }.glassEffect()
}

// Variant E: with tinted style
HStack { Text("x") }.glassEffect(.regular.tint(.accentColor))
```

Run `xcodebuild build -workspace Mana.xcworkspace -scheme DesignSystem CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)'` and observe which variants compile. Document results in the commit message.

If NONE of A–E compile, the iOS 26.4 SDK exposes Liquid Glass under a different (likely earlier-beta) shape. Try:

```swift
// Variant F: Glass type as a ShapeStyle
HStack { Text("x") }.background(Glass(), in: .capsule)
```

Or look in the SDK for a `Glass` ShapeStyle / `glassEffect` view modifier under `import SwiftUI` — search for symbols by running:

```bash
nm -gU $(find $(xcrun --sdk iphonesimulator --show-sdk-path) -name 'SwiftUI.swiftmodule' -type d 2>/dev/null | head -1)/*.swiftinterface 2>/dev/null | grep -i glass
```

Or grep the .swiftinterface file directly:
```bash
grep -i "glasseffect\|GlassEffect\|public.*Glass" $(find $(xcrun --sdk iphonesimulator --show-sdk-path) -name 'SwiftUI.swiftinterface' 2>/dev/null | head -1)
```

The goal: find the EXACT spelling, then use it. If after 30 minutes the SDK truly doesn't expose Liquid Glass APIs, keep the `.thinMaterial` fallback and document why.

- [ ] **Step 2: Update `DesignSystem/Sources/GlassToolbar.swift`**

Once the right call is identified, write the toolbar:

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
        .glassEffect(in: .capsule)   // OR whatever the probe revealed
    }
}
```

If the API spelling differs, adapt — but the public surface (`GlassToolbar { content }`) must stay identical so Plan 1-3 callsites don't break.

- [ ] **Step 3: Build DesignSystem**

```bash
xcodebuild build -workspace Mana.xcworkspace -scheme DesignSystem CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add DesignSystem/Sources/GlassToolbar.swift
git commit -m "feat(design-system): adopt iOS 26 Liquid Glass API for GlassToolbar"
```

(In the commit body, briefly note which API variant succeeded or that fallback was retained, so Plan 5+ has the breadcrumb.)

---

## Task 2: Color tokens via Asset Catalog

**Files:**
- Create: `DesignSystem/Sources/DSColors.xcassets/` (asset catalog with 5 color sets)
- Create: `DesignSystem/Sources/ColorTokens.swift`
- Modify: `DesignSystem/Project.swift` — `hasResources: true`
- Modify: `DesignSystem/Sources/Tokens.swift` — keep spacing/radius; reference colors via ColorTokens

The Module helper currently treats `hasResources` as opt-in. We need DesignSystem's `Sources/DSColors.xcassets` to be in the framework's `resources:` glob.

- [ ] **Step 1: Update `DesignSystem/Project.swift`**

```swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(name: "DesignSystem", kind: .designSystem, hasResources: true).project()
```

If the Module helper expects resources at `Resources/**` rather than `Sources/**.xcassets`, adapt by either:
- moving the xcassets to `DesignSystem/Resources/DSColors.xcassets/` (and adjusting access patterns), OR
- writing `DesignSystem/Project.swift` as a fully-spelled `Project(...)` like ArchiveKit does, with explicit `resources: ["Sources/**/*.xcassets"]`.

Pick whichever makes the asset accessible at runtime via `Bundle.module` or class-anchor lookup.

- [ ] **Step 2: Create `DesignSystem/Sources/DSColors.xcassets/Contents.json`**

```json
{
  "info": { "version": 1, "author": "xcode" }
}
```

- [ ] **Step 3: Create the 5 colorsets**

For each of `BackgroundPrimary`, `BackgroundSecondary`, `Accent`, `OnGlassPrimary`, `OnGlassSecondary`, create:

`DesignSystem/Sources/DSColors.xcassets/<NAME>.colorset/Contents.json`:

```json
{
  "colors": [
    {
      "appearances": [],
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "<R>",
          "green": "<G>",
          "blue": "<B>",
          "alpha": "1.000"
        }
      },
      "idiom": "universal"
    },
    {
      "appearances": [{ "appearance": "luminosity", "value": "dark" }],
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "<R-DARK>",
          "green": "<G-DARK>",
          "blue": "<B-DARK>",
          "alpha": "1.000"
        }
      },
      "idiom": "universal"
    }
  ],
  "info": { "version": 1, "author": "xcode" }
}
```

Suggested values:
- `BackgroundPrimary`: light `1.0/1.0/1.0` (white), dark `0.0/0.0/0.0` (black)
- `BackgroundSecondary`: light `0.95/0.95/0.97`, dark `0.1/0.1/0.12`
- `Accent`: light `0.0/0.48/1.0` (system blue), dark `0.39/0.69/1.0`
- `OnGlassPrimary`: light `0.1/0.1/0.1`, dark `0.95/0.95/0.95`
- `OnGlassSecondary`: light `0.4/0.4/0.42`, dark `0.65/0.65/0.7`

- [ ] **Step 4: Create `DesignSystem/Sources/ColorTokens.swift`**

```swift
import SwiftUI

public extension Tokens {
    enum Colors {
        public static var backgroundPrimary: Color { Color("BackgroundPrimary", bundle: .designSystem) }
        public static var backgroundSecondary: Color { Color("BackgroundSecondary", bundle: .designSystem) }
        public static var accent: Color { Color("Accent", bundle: .designSystem) }
        public static var onGlassPrimary: Color { Color("OnGlassPrimary", bundle: .designSystem) }
        public static var onGlassSecondary: Color { Color("OnGlassSecondary", bundle: .designSystem) }
    }
}

extension Bundle {
    static let designSystem: Bundle = {
        // Tuist-generated framework bundle
        final class _Anchor {}
        return Bundle(for: _Anchor.self)
    }()
}
```

If `Bundle.module` is auto-generated by Tuist for SwiftPM-style resources, prefer that over the class anchor. Test access in DesignSystem itself (a quick preview or test) to confirm color resolution.

- [ ] **Step 5: Replace hardcoded colors**

Find any `Color.gray`, `Color.black`, `Color.white` hardcodes in feature views. Specifically:
- `Features/LibraryFeature/Sources/LibraryRow.swift`: `Color.gray.opacity(0.3)` → `Tokens.Colors.backgroundSecondary`
- `Features/ReaderFeature/Sources/ReaderView.swift`: `Color.black.ignoresSafeArea()` — keep (intentional reader background; black is the right choice in both modes)
- `Features/ReaderFeature/Sources/ScrollPageRenderer.swift`: `Color.black.frame(...)` — keep
- `BookmarksView`: foreground colors look at `.headline` and `.subheadline` system styles which already adapt; OK

For each consumer that uses Color tokens, add `import DesignSystem`.

- [ ] **Step 6: Build + smoke**

```bash
./Scripts/setup.sh
xcodebuild build -workspace Mana.xcworkspace -scheme Mana CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED. Optionally launch the app on simulator and toggle Light/Dark in Developer menu to verify.

- [ ] **Step 7: Commit**

```bash
git add DesignSystem/ Features/LibraryFeature/Sources/LibraryRow.swift
git commit -m "feat(design-system): asset-catalog color tokens with light/dark variants"
```

---

## Task 3: Library sort + filter

**Files:**
- Modify: `Features/LibraryFeature/Sources/LibraryFeature.swift` — add `sort: SortOrder`, `filter: LibraryFilter` to State, `displayedComics` computed, `sortChanged` / `filterChanged` actions
- Modify: `Features/LibraryFeature/Sources/LibraryView.swift` — sort menu + filter chips
- Modify: `Features/LibraryFeature/Tests/LibraryFeatureTests.swift` — sort/filter tests

- [ ] **Step 1: Add types in `LibraryFeature.swift`**

```swift
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
```

- [ ] **Step 2: Add to State**

```swift
@ObservableState
public struct State: Equatable {
    public var comics: IdentifiedArrayOf<ComicItem> = []
    public var isImporting: Bool = false
    public var sort: LibrarySortOrder = .dateAddedDesc
    public var filter: LibraryFilter = .all
    @Presents public var alert: AlertState<Action.Alert>?

    public init(
        comics: IdentifiedArrayOf<ComicItem> = [],
        isImporting: Bool = false,
        sort: LibrarySortOrder = .dateAddedDesc,
        filter: LibraryFilter = .all
    ) {
        self.comics = comics
        self.isImporting = isImporting
        self.sort = sort
        self.filter = filter
    }

    public var displayedComics: [ComicItem] {
        let filtered: [ComicItem] = comics.filter { item in
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
}
```

- [ ] **Step 3: Add actions**

```swift
case sortChanged(LibrarySortOrder)
case filterChanged(LibraryFilter)
```

Reducer cases:
```swift
case let .sortChanged(s):
    state.sort = s
    return .none

case let .filterChanged(f):
    state.filter = f
    return .none
```

- [ ] **Step 4: Update `LibraryView.swift`**

```swift
.toolbar {
    ToolbarItem(placement: .navigation) {
        Button {
            store.send(.settingsTapped)
        } label: {
            Image(systemName: "gearshape")
        }
    }
    ToolbarItem(placement: .primaryAction) {
        Menu {
            Picker("Sort", selection: Binding(
                get: { store.sort },
                set: { store.send(.sortChanged($0)) }
            )) {
                ForEach(LibrarySortOrder.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            Picker("Filter", selection: Binding(
                get: { store.filter },
                set: { store.send(.filterChanged($0)) }
            )) {
                ForEach(LibraryFilter.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }
    ToolbarItem(placement: .primaryAction) {
        Button {
            showImporter = true
        } label: {
            Image(systemName: "plus")
        }
        .disabled(store.isImporting)
    }
}
```

Update the `List` to iterate over `store.displayedComics` instead of `store.comics`:

```swift
List {
    ForEach(store.displayedComics) { comic in
        // ... existing button/row ...
    }
    .onDelete { indexSet in
        // delete actions need to map from displayedComics back to source IDs
        let ids = indexSet.map { store.displayedComics[$0].id }
        let originalIndices = ids.compactMap { id in
            store.comics.firstIndex(where: { $0.id == id })
        }
        store.send(.delete(IndexSet(originalIndices)))
    }
}
```

- [ ] **Step 5: Tests**

In `LibraryFeatureTests.swift`, add:

```swift
@Test func sortByTitleAsc() async {
    let a = ComicItem(id: UUID(), url: URL(fileURLWithPath: "/x"), format: .cbz, title: "Alpha", pageCount: 0, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 1), fileSizeBytes: 0)
    let b = ComicItem(id: UUID(), url: URL(fileURLWithPath: "/y"), format: .cbz, title: "Beta", pageCount: 0, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0), fileSizeBytes: 0)
    let state = LibraryFeature.State(
        comics: IdentifiedArray(uniqueElements: [b, a]),
        sort: .titleAsc
    )
    #expect(state.displayedComics.map(\.title) == ["Alpha", "Beta"])
}

@Test func filterByPdf() async {
    let cbz = sample("X")
    let pdf = ComicItem(id: UUID(), url: URL(fileURLWithPath: "/p"), format: .pdf, title: "P", pageCount: 0, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0), fileSizeBytes: 0)
    let state = LibraryFeature.State(
        comics: IdentifiedArray(uniqueElements: [cbz, pdf]),
        filter: .pdf
    )
    #expect(state.displayedComics.map(\.title) == ["P"])
}

@Test func sortChangedActionUpdatesState() async {
    let store = await TestStore(initialState: LibraryFeature.State()) {
        LibraryFeature()
    } withDependencies: {
        $0.comicRepository = StubComicRepo(initial: [])
        $0.libraryImporter = StubImporter()
        $0.fileSyncService = UnavailableFileSync()
    }
    await store.send(.sortChanged(.titleAsc)) {
        $0.sort = .titleAsc
    }
}
```

- [ ] **Step 6: Run tests**

```bash
xcodebuild test -workspace Mana.xcworkspace -scheme LibraryFeature CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10
```
Expected: 6/6 PASS (3 existing + 3 new).

- [ ] **Step 7: Commit**

```bash
git add Features/LibraryFeature/
git commit -m "feat(library-feature): sort + filter library view"
```

---

## Task 4: "Add bookmark with note" sheet

**Files:**
- Create: `Features/BookmarksFeature/Sources/BookmarkSheet.swift`
- Modify: `Features/BookmarksFeature/Sources/BookmarksFeature.swift` — sheet presentation state
- Modify: `Features/BookmarksFeature/Sources/BookmarksView.swift` — present sheet

- [ ] **Step 1: Add sheet state to `BookmarksFeature`**

```swift
@ObservableState
public struct State: Equatable {
    public let comicId: UUID
    public var bookmarks: IdentifiedArrayOf<Bookmark> = []
    public var currentPageIndex: Int?
    public var addSheet: AddBookmarkSheet.State?

    public init(comicId: UUID, currentPageIndex: Int? = nil, bookmarks: IdentifiedArrayOf<Bookmark> = []) {
        self.comicId = comicId
        self.currentPageIndex = currentPageIndex
        self.bookmarks = bookmarks
    }
}

public struct AddBookmarkSheet: Equatable {
    public struct State: Equatable {
        public let pageIndex: Int
        public var note: String = ""
    }
}
```

Add actions:
```swift
case addSheetRequested
case addSheetDismissed
case addSheetNoteChanged(String)
case addSheetSubmitted
```

Reducer:
```swift
case .addSheetRequested:
    if let page = state.currentPageIndex {
        state.addSheet = AddBookmarkSheet.State(pageIndex: page)
    }
    return .none

case .addSheetDismissed:
    state.addSheet = nil
    return .none

case let .addSheetNoteChanged(text):
    state.addSheet?.note = text
    return .none

case .addSheetSubmitted:
    guard let sheet = state.addSheet else { return .none }
    let bm = Bookmark(id: uuid(), comicId: state.comicId, pageIndex: sheet.pageIndex, note: sheet.note.isEmpty ? nil : sheet.note, createdAt: now)
    state.bookmarks.append(bm)
    state.addSheet = nil
    return .run { send in
        try? await repo.add(bm)
        await send(.bookmarkAdded(bm))
    }
```

The existing `addRequested(pageIndex:note:)` action stays — used internally by the sheet flow. Update the `addSheetSubmitted` to call `addRequested` if you want to keep the persistence path consolidated. Either pattern is fine.

- [ ] **Step 2: Create `Features/BookmarksFeature/Sources/BookmarkSheet.swift`**

```swift
import SwiftUI
import ComposableArchitecture

public struct BookmarkSheet: View {
    let pageIndex: Int
    @Binding var note: String
    var onSubmit: () -> Void
    var onCancel: () -> Void

    public init(pageIndex: Int, note: Binding<String>, onSubmit: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.pageIndex = pageIndex
        self._note = note
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Page") {
                    Text("Page \(pageIndex + 1)")
                }
                Section("Note (optional)") {
                    TextField("e.g. great panel", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Add Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSubmit)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
```

- [ ] **Step 3: Update `BookmarksView.swift` to present the sheet**

Change the existing toolbar `+` button to send `.addSheetRequested` and add a `.sheet(...)` presentation:

```swift
.toolbar {
    if store.currentPageIndex != nil {
        ToolbarItem(placement: .primaryAction) {
            Button {
                store.send(.addSheetRequested)
            } label: {
                Image(systemName: "plus")
            }
        }
    }
}
.sheet(
    isPresented: Binding(
        get: { store.addSheet != nil },
        set: { if !$0 { store.send(.addSheetDismissed) } }
    )
) {
    if let sheet = store.addSheet {
        BookmarkSheet(
            pageIndex: sheet.pageIndex,
            note: Binding(
                get: { sheet.note },
                set: { store.send(.addSheetNoteChanged($0)) }
            ),
            onSubmit: { store.send(.addSheetSubmitted) },
            onCancel: { store.send(.addSheetDismissed) }
        )
    }
}
```

- [ ] **Step 4: Update tests**

In `BookmarksFeatureTests.swift`, add:

```swift
@Test func addSheetRequestedOpensSheet() async {
    let store = await TestStore(initialState: BookmarksFeature.State(comicId: UUID(), currentPageIndex: 7)) {
        BookmarksFeature()
    } withDependencies: {
        $0.bookmarkRepository = StubBookmarkRepo(initial: [])
    }
    await store.send(.addSheetRequested) {
        $0.addSheet = BookmarksFeature.AddBookmarkSheet.State(pageIndex: 7)
    }
}

@Test func addSheetSubmittedAddsBookmark() async {
    let comicId = UUID()
    let fixedUUID = UUID()
    let fixedDate = Date(timeIntervalSince1970: 100)

    var initialState = BookmarksFeature.State(comicId: comicId, currentPageIndex: 5)
    initialState.addSheet = BookmarksFeature.AddBookmarkSheet.State(pageIndex: 5)
    initialState.addSheet?.note = "panel A"

    let store = await TestStore(initialState: initialState) {
        BookmarksFeature()
    } withDependencies: {
        $0.bookmarkRepository = StubBookmarkRepo(initial: [])
        $0.uuid = .constant(fixedUUID)
        $0.date.now = fixedDate
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.addSheetSubmitted) {
        $0.bookmarks.append(Bookmark(id: fixedUUID, comicId: comicId, pageIndex: 5, note: "panel A", createdAt: fixedDate))
        $0.addSheet = nil
    }
}
```

- [ ] **Step 5: Run tests**

```bash
xcodebuild test -workspace Mana.xcworkspace -scheme BookmarksFeature CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10
```
Expected: 4/4 PASS (2 existing + 2 new).

- [ ] **Step 6: Commit**

```bash
git add Features/BookmarksFeature/
git commit -m "feat(bookmarks-feature): add bookmark with note via sheet"
```

---

## Task 5: ReaderFeature security scope teardown

Plan 3 review issue #7: `startAccessingSecurityScopedResource` is called in `.task` but never balanced. Fix:

**Files:**
- Modify: `Features/ReaderFeature/Sources/ReaderFeature.swift`

- [ ] **Step 1: Track scope state**

In `State`, add:
```swift
public var securityScopedURL: URL?
```

In `.task`'s success path, after `url.startAccessingSecurityScopedResource()`:
```swift
let didStart = url.startAccessingSecurityScopedResource()
// ... open archive etc ...
await send(.opened(handle: handle, pageCount: pageCount, lastPage: lastPage))
if didStart {
    await send(.startedSecurityScope(url))
}
```

Add action:
```swift
case startedSecurityScope(URL)
```

Reducer:
```swift
case let .startedSecurityScope(url):
    state.securityScopedURL = url
    return .none
```

In `.onDisappear`, also stop:
```swift
case .onDisappear:
    let scopedURL = state.securityScopedURL
    state.securityScopedURL = nil
    let handle = state.handle
    state.handle = nil
    let format = state.comic.format
    return .run { _ in
        if let handle {
            let reader = router.reader(for: format)
            await reader.closeArchive(handle)
        }
        if let scopedURL {
            scopedURL.stopAccessingSecurityScopedResource()
        }
    }
```

- [ ] **Step 2: Existing tests still pass**

The `taskOpensArchiveAndLoadsLastPage` test in non-exhaustive mode shouldn't notice the new `startedSecurityScope` action.

```bash
xcodebuild test -workspace Mana.xcworkspace -scheme ReaderFeature CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10
```
Expected: 4/4 PASS.

- [ ] **Step 3: Commit**

```bash
git add Features/ReaderFeature/
git commit -m "fix(reader-feature): stop security-scoped access on disappear"
```

---

## Task 6: BookmarkRepository compound uniqueness

Plan 2 review nice-to-have N5: a user can add the same page twice. Fix:

**Files:**
- Modify: `Data/PersistenceKit/Sources/BookmarkRepositoryLive.swift`

- [ ] **Step 1: Update `add(_:)`**

```swift
public func add(_ bookmark: Bookmark) async throws {
    let context = ctx()
    let comicId = bookmark.comicId
    let page = bookmark.pageIndex
    let descriptor = FetchDescriptor<BookmarkEntity>(
        predicate: #Predicate { $0.comicId == comicId && $0.pageIndex == page }
    )
    if let existing = try context.fetch(descriptor).first {
        // Update note instead of duplicating.
        existing.note = bookmark.note
        existing.createdAt = bookmark.createdAt
    } else {
        context.insert(BookmarkEntity(
            id: bookmark.id,
            comicId: bookmark.comicId,
            pageIndex: bookmark.pageIndex,
            note: bookmark.note,
            createdAt: bookmark.createdAt
        ))
    }
    try context.save()
}
```

- [ ] **Step 2: Add test**

In `Data/PersistenceKit/Tests` (create `BookmarkRepositoryLiveTests.swift` if it doesn't exist; the plan didn't add one earlier):

```swift
import Testing
import Foundation
@testable import PersistenceKit
import Domain

@Suite struct BookmarkRepositoryLiveTests {

    @Test func addingSamePageTwiceUpdatesInPlace() async throws {
        let stack = try SwiftDataStack.inMemory()
        let repo = BookmarkRepositoryLive(stack: stack)
        let comicId = UUID()
        try await repo.add(Bookmark(id: UUID(), comicId: comicId, pageIndex: 5, note: "first", createdAt: .init(timeIntervalSince1970: 0)))
        try await repo.add(Bookmark(id: UUID(), comicId: comicId, pageIndex: 5, note: "second", createdAt: .init(timeIntervalSince1970: 1)))

        let all = await repo.bookmarks(comicId: comicId)
        #expect(all.count == 1)
        #expect(all.first?.note == "second")
    }

    @Test func differentPagesCoexist() async throws {
        let stack = try SwiftDataStack.inMemory()
        let repo = BookmarkRepositoryLive(stack: stack)
        let comicId = UUID()
        try await repo.add(Bookmark(id: UUID(), comicId: comicId, pageIndex: 1, note: nil, createdAt: .init(timeIntervalSince1970: 0)))
        try await repo.add(Bookmark(id: UUID(), comicId: comicId, pageIndex: 2, note: nil, createdAt: .init(timeIntervalSince1970: 0)))

        let all = await repo.bookmarks(comicId: comicId)
        #expect(all.count == 2)
    }
}
```

- [ ] **Step 3: Run tests**

```bash
xcodebuild test -workspace Mana.xcworkspace -scheme PersistenceKit CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' 2>&1 | tail -10
```
Expected: 8/8 PASS (6 existing + 2 new).

- [ ] **Step 4: Commit**

```bash
git add Data/PersistenceKit/
git commit -m "feat(persistence-kit): bookmark dedupe by (comicId, pageIndex)"
```

---

## Plan 4 Completion Checklist

- [ ] DesignSystem builds with iOS 26 Liquid Glass primitive (or documented fallback)
- [ ] Color tokens in Asset Catalog with light/dark variants
- [ ] Library shows sort menu and filter chips
- [ ] BookmarksView opens an "Add Bookmark" sheet with note field
- [ ] ReaderFeature stops security scope on disappear
- [ ] BookmarkRepository deduplicates by (comicId, pageIndex)
- [ ] All module + integration tests pass
- [ ] App builds for iPad Pro 13" (M5) iOS 26.4 simulator
- [ ] Smoke test: app launches, library shows sort/filter, dark mode adapts colors

## After Plan 4

The app reaches feature-complete for the originally agreed V2 scope:
- ZIP/CBZ/RAR/PDF
- Single/Dual/Scroll(LTR/RTL/TTB) reading modes
- Bookmarks with notes
- Per-comic + global default reading mode
- Library sort/filter, dark mode, downsampled thumbnails
- iCloud sync (metadata + files) — requires user-side Developer account setup to actually run

Optional Plan 5 ideas (LightComics parity not yet covered):
- Slideshow auto-advance
- Image filters (contrast/invert)
- Wide image cropping/reverse sequencing
- Remote storage (FTP/WebDAV/Dropbox)
- Wi-Fi HTTP transfer
- Face ID lock + passcode
- TTS, Bluetooth keyboard
- EPUB/TXT support

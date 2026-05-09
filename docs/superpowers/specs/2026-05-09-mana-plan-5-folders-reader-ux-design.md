# Mana — Plan 5: Folders + Drag Import + Reader UX

> **Status:** Design / Spec
> **Date:** 2026-05-09
> **Builds on:** Mana V2 (Plans 1–4 shipped)

## 1. Goal & Scope

Add user-facing improvements on top of the V2 baseline:

1. **Library folders** — single-level folders to organize comics; auto-generated 2×2 cover grid as folder thumbnail.
2. **Drag-drop import from Files** (iPad Split View) — drop one or more files onto the library to import them.
3. **Page progression direction** — LTR (default) / RTL (manga) setting at the global level with per-comic override; controls swipe AND tap-zone direction.
4. **True full-screen reader** — hide navigation bar, status bar, and home indicator; block swipe-back gesture. Comic fills the entire display.
5. **Reader gestures**:
   - **Single tap on left half** → previous page (LTR) / next page (RTL)
   - **Single tap on right half** → next page (LTR) / previous page (RTL)
   - **Swipe left/right** → page navigation (same direction logic as tap)
   - **Long-press anywhere** → toggle controls overlay (top: back + title + page count; bottom: progress scrubber + bookmarks + mode picker)
   - Controls auto-hide after 3 seconds (configurable)
6. **Settings additions**: app language (English / 한국어 / 日本語), gesture toggles (tap-zones on/off, swipes on/off).

Library-side (1 + 2) and reader-side (3 + 4 + 5 + 6) are independent within the plan; tasks can run in either order.

### In Scope

- 1-depth folders only (no nesting). Comics belong to the root or one folder.
- Drag-drop on the library list/grid only — no folder-as-drop-target in this plan.
- Auto-hide controls after 3 seconds; configurable in Settings (3 / 5 / off).
- Swipe-back gesture blocked while reader is on top of the navigation stack.
- Status bar AND home indicator hidden in reader.
- Both global default page progression direction AND per-comic override.
- Three localizations: en (default), ko, ja.

### Out of Scope (deferred)

- Nested folders (revisit if user feedback demands)
- Drag a comic onto a folder card to move it (this plan keeps move via long-press menu on `LibraryRow`)
- Reordering inside a folder (sort/filter from Plan 4 still applies)
- Slideshow auto-advance, image filters, TTS, remote storage (separate future plans)
- Volume button page turn (deferred — needs AVAudioSession)
- Pinch-to-zoom interaction with tap zones (zoom from `ZoomableImageView` already covers single-page zoom; tap zones are evaluated only when not zoomed in)

## 2. Tech Stack

No new external dependencies. Uses:
- SwiftData CloudKit-compatible models (continued from Plan 3)
- SwiftUI `.onDrop` + `NSItemProvider` for drag-drop
- UIKit `UIViewControllerRepresentable` to disable `interactivePopGestureRecognizer`
- TCA effects with `\.continuousClock` (or `\.mainQueue`) for auto-hide timer

## 3. Domain Changes

### New types

```swift
// Domain/Sources/Models/Folder.swift
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

```swift
// Domain/Sources/Models/PageProgressionDirection.swift
public enum PageProgressionDirection: String, Sendable, Equatable, Hashable, CaseIterable {
    case leftToRight    // Western, default
    case rightToLeft    // Manga
}
```

### `ComicItem` additions

Add two optional fields (default `nil` keeps existing call-sites compiling):

```swift
public let folderId: UUID?
public let pageProgressionDirection: PageProgressionDirection?
```

Both round-trip through PersistenceKit and CloudKit.

### New repository protocol

```swift
// Domain/Sources/Repositories/FolderRepository.swift
public protocol FolderRepository: Sendable {
    func all() async -> [Folder]
    func upsert(_ folder: Folder) async throws
    func delete(_ id: UUID) async throws
}
```

`ComicRepository` already has the methods needed; no protocol change there.

## 4. PersistenceKit Changes

New `FolderEntity` mirroring `ComicEntity` patterns (CloudKit-compatible: no `.unique`, all fields optional or defaulted):

```swift
@Model
public final class FolderEntity {
    public var id: UUID = UUID()
    public var name: String = ""
    public var dateAdded: Date = Date(timeIntervalSince1970: 0)

    public init(id: UUID, name: String, dateAdded: Date) { ... }
    public func toModel() -> Folder { ... }
    public static func from(_ folder: Folder) -> FolderEntity { ... }
}
```

`ComicEntity` gains:

```swift
public var folderId: UUID?
public var pageProgressionDirectionRaw: String?
```

`SwiftDataStack.cloudKit(...)` and `.onDisk(...)` register `FolderEntity.self` alongside the existing three.

`FolderRepositoryLive` is an actor with `inMemory()`-friendly init like the others.

`ComicRepositoryLive.upsert` round-trips the two new fields.

## 5. LibraryFeature Changes

### State additions

```swift
@ObservableState
public struct State: Equatable {
    // existing: comics, isImporting, sort, filter, alert
    public var folders: IdentifiedArrayOf<Folder> = []
    public var currentFolderId: UUID? = nil   // nil = root
    public var newFolderSheet: NewFolderSheet.State?
    // ...
}

public struct NewFolderSheet: Equatable, Sendable {
    public struct State: Equatable, Sendable {
        public var name: String = ""
    }
}
```

### Derived view

```swift
public var displayedFolders: [Folder] {
    // root-level folders shown; folders aren't sortable in v1
    folders.elements.sorted { $0.dateAdded > $1.dateAdded }
}

public var displayedComics: [ComicItem] {
    // existing sort/filter logic, but ALSO filter by currentFolderId
    let scoped = comics.filter { $0.folderId == currentFolderId }
    // ... apply sort/filter from Plan 4 to `scoped` ...
}
```

### New actions

```swift
case folderTapped(Folder)        // navigate into folder
case backToRoot                   // navigate up (only when in folder)
case newFolderRequested
case newFolderSheetDismissed
case newFolderNameChanged(String)
case newFolderSubmitted
case folderCreated(Folder)
case folderDeleteRequested(UUID)
case folderDeleted(UUID)
case comicMoveToFolderRequested(comicId: UUID, folderId: UUID?)
case comicMoved(comicId: UUID, folderId: UUID?)
case droppedURLs([URL])           // drag-drop receiver
```

`droppedURLs` reuses the existing `importPicked` flow but additionally tags imports with `currentFolderId` so dropped files land in the active folder.

### View additions

- **Folder section** above the comic list when at root: horizontally-scrolling `LazyHStack` of `FolderCard` (60×80 image grid + name).
- **Folder header** when inside a folder: breadcrumb `← Library / Folder Name` + "Empty" placeholder when no comics.
- **Long-press menu on `LibraryRow`**: "Move to…" (sheet picker of folders) + "Delete".
- **Long-press menu on `FolderCard`**: "Rename" (in v1, just delete to keep scope tight). v1 ships **without rename**; deletion only. Add a TODO note for rename in Plan 6.
- **Toolbar `+` action**: when in a folder, importing creates inside it; menu with "New Folder" item to create folder via sheet.
- **`.onDrop(of: [.fileURL], delegate:)`** on the root List for drag-drop.

### Folder thumbnail

Computed View `FolderThumbnail(folder:)` queries the comic repo for first 4 comics in that folder (sorted by dateAdded desc) and lays out their `coverThumbnail` Data in a 2×2 grid. Reactive — re-renders when `comics` changes.

Implementation: `FolderThumbnail` reads `comics: IdentifiedArrayOf<ComicItem>` from the parent store. Filters in-place. No async/separate fetch.

## 6. ReaderFeature Changes

### Page progression direction

State already has `mode: ReadingMode`. Add:

```swift
public var pageProgressionDirection: PageProgressionDirection = .leftToRight
```

Resolved on `.opened`:
```swift
state.pageProgressionDirection = state.comic.pageProgressionDirection
    ?? loadGlobalDirectionFromUserDefaults()
    ?? .leftToRight
```

`loadGlobalDirectionFromUserDefaults()` reads `userDefaults.string(forKey: SettingsFeature.directionKey)` and decodes via `PageProgressionDirection(rawValue:)`. The `\.userDefaults` dependency is already injected (Plan 2 SettingsFeature).

```swift
case progressionDirectionChanged(PageProgressionDirection)
```

Reducer: persist to comic via `comicRepo.upsert` (same pattern as `modeChanged`).

`SinglePageRenderer` and `DualPageRenderer` interpret the direction:
- LTR: swipe-left increments page
- RTL: swipe-right increments page

`ScrollPageRenderer` ignores it (it has its own `ScrollDirection`).

### Auto-hide controls

```swift
public var isControlsVisible: Bool = false   // existing
public var controlsAutoHideSeconds: Double = 3.0  // populated from UserDefaults on .task
```

On `.task`, after `.opened`, the reducer reads `userDefaults.double(forKey: SettingsFeature.autoHideKey)` (returns `0.0` if unset → falls back to `3.0`). The value `0.0` is treated as "off" — no debounce is scheduled when controls toggle on.

### Gesture model (the important new bit)

The reader supports four gesture types, each individually toggleable in Settings:

| Gesture | Action |
|---|---|
| Tap on left half of screen | LTR: previous page · RTL: next page |
| Tap on right half of screen | LTR: next page · RTL: previous page |
| Swipe left | LTR: next page · RTL: previous page |
| Swipe right | LTR: previous page · RTL: next page |
| Long-press anywhere (≥0.4s) | Toggle controls overlay |

**Gesture ownership:**
- **Tap zones + swipe** belong to `PageRenderer` (each renderer — Single, Dual, Scroll — chooses whether to honor them).
  - `SinglePageRenderer` and `DualPageRenderer`: both honor tap + swipe.
  - `ScrollPageRenderer`: ignores tap zones (tap should not interfere with continuous scroll); user navigates by scrolling. Long-press still works.
- **Long-press for controls** belongs to `ReaderView` (overlay visibility is reader-scope).

**Disambiguation between single tap and long-press:**
SwiftUI's `LongPressGesture(minimumDuration: 0.4)` runs simultaneously with `TapGesture`. Use `.simultaneousGesture(...)` to layer them; long-press fires after the duration if the finger is still down, tap fires on lift before the duration. The 0.4s delay does NOT defer single-tap — tap fires immediately on touch-up.

**Pinch-zoom interaction:**
`ZoomableImageView` (UIKit) handles pinch-zoom inside a page in single mode. When zoomed in (`zoomScale > 1`), tap zones must NOT trigger page navigation. Implementation: `SinglePageRenderer` queries the underlying scrollView's zoom state via a `Coordinator` callback before invoking the tap action. If zoomed, tap is consumed by the scrollView pan gesture instead.

### Gesture settings in State

```swift
public var tapZonesEnabled: Bool = true
public var swipeEnabled: Bool = true
```

Both populated from `UserDefaults` on `.task`. Defaults: both ON. If both are OFF, the user can still navigate via the progress slider (when controls are visible).

### Full-screen + status bar hidden

```swift
// ReaderView
.toolbar(.hidden, for: .navigationBar)
.statusBarHidden(true)
.persistentSystemOverlays(.hidden)   // iOS 16+ — hides home indicator on iPad
.background(SwipeBackBlocker())
```

```swift
case toggleControls                     // existing
case autoHideControls                   // new (debounced)
case sliderDragStart
case sliderDragEnd
```

When `toggleControls` flips to true, schedule `.autoHideControls` debounced by `controlsAutoHideSeconds` seconds. `sliderDragStart` cancels the debounce; `sliderDragEnd` re-arms it.

### Top + bottom overlays (the new bit)

```swift
// ReaderView (replaces existing single bottom overlay)

if store.isControlsVisible {
    VStack {
        // TOP overlay
        GlassToolbar {
            Button { dismiss() } label: { Image(systemName: "chevron.left") }
            Spacer()
            VStack {
                Text(store.comic.title).font(.headline).lineLimit(1)
                Text("\(store.pageIndex + 1) / \(store.pageCount)").font(.caption2)
            }
            Spacer()
            Button { store.send(.bookmarksTapped(comicId: store.comic.id)) } label: {
                Image(systemName: "bookmark")
            }
        }
        .padding(.horizontal, Tokens.Spacing.m)

        Spacer()

        // BOTTOM overlay
        GlassToolbar {
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
                Picker("Mode", selection: ...) { ... ReadingMode picker ... }
                Picker("Direction", selection: ...) { ... PageProgressionDirection picker ... }
            } label: {
                Image(systemName: "rectangle.split.2x1")
            }
        }
        .padding(.horizontal, Tokens.Spacing.m)
    }
    .padding(.vertical, Tokens.Spacing.l)
    .transition(.opacity.combined(with: .move(edge: .top)))
}
```

(Top transition slides from top; bottom from bottom. Use separate VStacks if needed — single VStack with two GlassToolbars + Spacer is the simplest layout.)

### Reader dismissal path

The user dismisses by long-pressing to show controls, then tapping the back chevron in the top overlay → `dismiss()` (SwiftUI `\.dismiss` env). AppFeature's NavigationStack pops the path. The swipe-back gesture is blocked, status bar and home indicator stay hidden, but the explicit chevron always works.

`SwipeBackBlocker` (in SharedUI) is a `UIViewControllerRepresentable` that walks the responder chain to find the parent `UINavigationController` and sets `interactivePopGestureRecognizer.isEnabled = false` on appear, restores on disappear.

## 7. SettingsFeature Changes

Add five new settings:

```swift
@ObservableState
public struct State: Equatable {
    public var defaultMode: ReadingMode = .single
    public var defaultPageProgressionDirection: PageProgressionDirection = .leftToRight   // NEW
    public var controlsAutoHideSeconds: Double = 3.0   // NEW (3, 5, or 0=off)
    public var tapZonesEnabled: Bool = true   // NEW
    public var swipeEnabled: Bool = true   // NEW
    public var appLanguage: AppLanguage = .system   // NEW
}

public enum AppLanguage: String, Sendable, Equatable, CaseIterable {
    case system   // follow device setting
    case en       // English
    case ko       // 한국어
    case ja       // 日本語
}
```

```swift
case defaultDirectionChanged(PageProgressionDirection)
case controlsAutoHideChanged(Double)
case tapZonesToggled(Bool)
case swipeToggled(Bool)
case appLanguageChanged(AppLanguage)
```

All persist via `\.userDefaults` like the existing mode setting.

### Settings keys

```swift
public extension SettingsFeature {
    static let modeKey = "mana.defaultReadingMode"
    static let directionKey = "mana.defaultPageProgressionDirection"
    static let autoHideKey = "mana.controlsAutoHideSeconds"
    static let tapZonesKey = "mana.tapZonesEnabled"
    static let swipeKey = "mana.swipeEnabled"
    static let languageKey = "mana.appLanguage"
}
```

### Settings UI sections

```
[General]
  Default reading mode    [Single / Dual / Scroll-LTR / Scroll-RTL / Scroll-TTB]
  Default page direction  [LTR / RTL]
  App language            [System / English / 한국어 / 日本語]

[Reader gestures]
  Tap zones to turn pages    [toggle]
  Swipe to turn pages        [toggle]
  Auto-hide controls         [3s / 5s / Off]
```

### App language switching

Switching `appLanguage` writes to `UserDefaults` and updates `Bundle.main` localization. Implementation uses `AppleLanguages` `UserDefaults` key:

```swift
case let .appLanguageChanged(lang):
    state.appLanguage = lang
    let codes: [String] = (lang == .system) ? [] : [lang.rawValue]
    defaults.set(codes, forKey: "AppleLanguages")
    defaults.set(lang.rawValue, forKey: Self.languageKey)
    return .none
```

A relaunch is required for the change to fully apply (alert: "Restart Mana to apply language change."). This is the standard iOS app-language pattern; iOS 13+ supports per-app language in system Settings without code, but in-app picker requires `AppleLanguages` override.

## 8. SwipeBackBlocker (new SharedUI)

```swift
import SwiftUI
import UIKit

public struct SwipeBackBlocker: UIViewControllerRepresentable {
    public init() {}

    public func makeUIViewController(context: Context) -> Holder { Holder() }
    public func updateUIViewController(_: Holder, context: Context) {}

    public final class Holder: UIViewController {
        public override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
        public override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}
```

Lives in `SharedUI` module so any future feature can reuse.

## 9. Drag-Drop Implementation Detail

```swift
// LibraryView
.dropDestination(for: URL.self) { urls, _ in
    store.send(.droppedURLs(urls))
    return true
}
```

iOS 16+ has `.dropDestination` on View; handles `URL.self` via `Transferable` conformance (URL is built-in Transferable). Returns `true` to accept all drops. Multiple URLs come in one call.

The reducer's `.droppedURLs` case mirrors `.importPicked` but tags each item with `currentFolderId`. The importer (`LibraryImporterLive`) gains an optional `folderId: UUID?` parameter; when set, the created `ComicItem.folderId = folderId`.

## 10. Data Flow Examples

### Open a comic in a folder, change progression direction

1. User taps a comic inside "Manga" folder → `comicTapped(item)` → `app.path.append(.reader(item))`
2. ReaderFeature `.task` opens archive, sees `item.pageProgressionDirection == .rightToLeft`, sets state
3. SinglePageRenderer reads `state.pageProgressionDirection`; gesture interprets right-swipe as next
4. User taps screen → `toggleControls` → top + bottom overlays fade in, 3s auto-hide scheduled
5. User opens mode menu → selects "LTR" → `progressionDirectionChanged(.leftToRight)` → state updates, comic upserted to repo

### Drag two .cbz files from Files into "Manga" folder

1. User drags two URLs from Files Split View, drops on LibraryView while inside "Manga"
2. SwiftUI emits `(URLs)` to `dropDestination` callback → `store.send(.droppedURLs([url1, url2]))`
3. Reducer uses `state.currentFolderId` (= "Manga".id) and the importer to ingest both
4. Each new `ComicItem` has `folderId = "Manga".id` → appears in folder, not root

### Create a folder

1. User taps `+` toolbar menu → "New Folder…" → `newFolderRequested` → sheet with name `TextField`
2. User types "Manga" → `newFolderNameChanged` → `newFolderSubmitted`
3. Reducer creates `Folder(id: uuid(), name: "Manga", dateAdded: now)`, appends to state, upserts to repo
4. Sheet closes; folder appears in the horizontal scroller

## 11. Testing Strategy

| Layer | Coverage |
|---|---|
| Domain | new value types pass Equatable round-trip — minimal |
| PersistenceKit | `FolderRepositoryLive` CRUD; `ComicRepositoryLive` round-trips `folderId` + `pageProgressionDirectionRaw`; reuse `inMemory()` stack |
| LibraryFeature | folder load/create/delete; comic move into folder; `displayedComics` filters by current folder; `droppedURLs` triggers import with current folder |
| ReaderFeature | `progressionDirectionChanged` updates state + persists; `toggleControls` schedules auto-hide; `sliderDragStart`/`sliderDragEnd` cancels/re-arms timer |
| SettingsFeature | new pickers persist via `\.userDefaults` |
| SharedUI | `SwipeBackBlocker` is too thin for unit tests; covered by manual smoke |

Use TestStore non-exhaustive mode where reducers emit cascading effects (`toggleControls` → `autoHideControls` debounce). Inject `\.mainQueue = .immediate` for debounce-sensitive tests (consistent with existing Plan 1 ReaderFeature tests).

## 12. Migration

SwiftData lightweight migration handles the new optional fields on `ComicEntity` (defaulted to nil) and the new `FolderEntity`. CloudKit-backed schema picks them up; existing records get `folderId == nil` (= root) automatically.

No explicit migration code required.

## 13. Acceptance Criteria

Plan 5 is complete when:

1. User can create a folder named "Manga" via toolbar menu; it appears in library
2. User can long-press a comic and move it into "Manga"; it disappears from root and shows up inside "Manga"
3. Folder card shows a 2×2 grid of cover thumbnails (or fewer if folder has <4 comics, or empty placeholder if 0)
4. Tapping the folder enters it; breadcrumb header shows "← Library / Manga"
5. While inside "Manga", the toolbar `+` import places the new comic into the folder
6. Dragging files from the Files app (Split View) into the library imports them; if a folder is open, they go into that folder
7. Reader hides nav bar, status bar, AND home indicator; the comic fills the entire screen
8. Reader blocks swipe-back gesture; only way out is long-press-to-show + back chevron
9. **In single or dual mode**, **single tap on the left half** turns to the previous page (or next, in RTL); **single tap on the right half** turns to the next page (or previous, in RTL). Midline = `geometry.size.width / 2`.
10. **In single or dual mode**, **swipe** in either direction also turns the page, respecting LTR/RTL. In scroll mode, swipe is consumed by the scroll view.
11. **Long-press** (≥0.4s) toggles top overlay (back chevron, title, page count, bookmark icon) AND bottom overlay (progress slider, mode/direction menu) simultaneously; both fade out together after the configured auto-hide duration (default 3s)
12. Sliding the progress slider moves through pages; the auto-hide timer pauses while dragging
13. The bottom-bar mode menu lets the user switch between LTR and RTL page direction — applies immediately and persists per-comic
14. Pinch-zoomed in single mode disables tap zones until zoom returns to 1×
15. Settings → "Default page direction" persists across app relaunch and applies to new comics
16. Settings → "Auto-hide controls" with options 3s / 5s / Off works
17. Settings → "Tap zones" and "Swipe" toggles disable the corresponding gesture without affecting the other
18. Settings → "App language" changes between English / 한국어 / 日本語 / System; an alert prompts to restart for the change to apply
19. App-launch with `AppleLanguages = ["ko"]` shows the entire UI in Korean (verify Library title, Settings labels, Reader page count format)
20. All module + integration tests pass; app builds for iPad iOS 26.4 simulator

## 14. Localization (en / ko / ja)

### Strategy

Mana ships three localizations: **English (default), 한국어, 日本語**.

Strings are organized per-module, using each module's `Resources/<lang>.lproj/Localizable.strings` files. The Module helper already supports `hasResources: true`; modules with user-facing text (`LibraryFeature`, `ReaderFeature`, `BookmarksFeature`, `SettingsFeature`) flip it on and add `.lproj` directories.

### Default known regions

The App target's `Project.swift` adds (matching FaceReader's pattern):

```swift
options: .options(
    defaultKnownRegions: ["en", "ja", "ko", "Base"],
    developmentRegion: "en"
)
```

(Workspace's `Project.swift` doesn't have an `options` field; this goes on the App project.)

### String access

Use SwiftUI's built-in `LocalizedStringKey` everywhere user-facing text appears:

```swift
Text("library.title")          // "Library" / "라이브러리" / "ライブラリ"
Text("settings.section.general")
Text("reader.page.format \(idx) \(total)")   // "%@ / %@" → "5 / 240"
```

`Bundle(for: BundleAnchor.self)` is used per-module to pick the right `Localizable.strings`, since strings are scoped to the module that owns the view. iOS auto-resolves the bundle's localization from `AppleLanguages`.

### Strings to translate (initial round)

A starter set; not exhaustive. Translators expand later.

```
library.title              = "Library";
library.empty              = "No comics yet";
library.import             = "Import";
library.new_folder         = "New Folder";
library.move_to            = "Move to…";
library.delete             = "Delete";
library.sort               = "Sort";
library.filter             = "Filter";

reader.controls.back       = "Back";
reader.controls.bookmark   = "Bookmarks";
reader.controls.mode       = "Reading Mode";
reader.controls.direction  = "Page Direction";
reader.page.format         = "%lld / %lld";

settings.title             = "Settings";
settings.general           = "General";
settings.gestures          = "Reader Gestures";
settings.default_mode      = "Default Reading Mode";
settings.default_direction = "Default Page Direction";
settings.app_language      = "App Language";
settings.tap_zones         = "Tap Zones to Turn Pages";
settings.swipe             = "Swipe to Turn Pages";
settings.auto_hide         = "Auto-hide Controls";
settings.relaunch_required = "Restart Mana to apply this change.";

mode.single                = "Single";
mode.dual                  = "Dual";
mode.scroll.ltr            = "Scroll (LTR)";
mode.scroll.rtl            = "Scroll (RTL)";
mode.scroll.ttb            = "Webtoon (TTB)";

direction.ltr              = "Left to Right";
direction.rtl              = "Right to Left";

language.system            = "System";
language.en                = "English";
language.ko                = "한국어";
language.ja                = "日本語";

bookmark.add               = "Add Bookmark";
bookmark.note              = "Note (optional)";
bookmark.empty             = "No bookmarks";
bookmark.page.format       = "Page %lld";

import.failed              = "Import failed";
import.unsupported_format  = "Unsupported format: %@";
```

The English file is the source of truth; `ko.lproj` and `ja.lproj` start with translations of the above. Future Plans extend.

### Switching language at runtime

When `appLanguageChanged(.ko)` fires, the reducer:
1. Sets `UserDefaults.standard.set(["ko"], forKey: "AppleLanguages")`
2. Sets the app-private `mana.appLanguage` key
3. Returns an effect that triggers an alert: "Restart Mana to apply this change."

iOS will read the new locale on next cold launch; partial mid-run swap requires SwiftUI's `Environment(\.locale)` plus aggressive view rebuilds, which is brittle. Restart-required is the standard pattern (FaceReader does the same).

## 15. Open Items / Decisions Deferred

- **Folder rename** — deferred to Plan 6 (UX needs more thought; in-place edit vs sheet)
- **Drag a comic onto a folder card** — deferred (cleaner UX but adds dragSource + dropTarget complexity to LibraryRow + FolderCard)
- **Empty folder UX** — show "Empty" placeholder; no special prompts
- **Top overlay back chevron behavior on iPad with hardware keyboard** — keyboard back-shortcut deferred to a possible Plan 6 keyboard plan

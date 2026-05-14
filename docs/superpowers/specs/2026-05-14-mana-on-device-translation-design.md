# Mana — On-Device Apple Intelligence Translation

> **Status:** Design / Spec
> **Date:** 2026-05-14
> **Builds on:** Mana V2 + Plan 5 (Folders + Reader UX shipped)

## 1. Goal & Scope

Add an in-reader auto-translation overlay powered by Apple's on-device
Foundation Models framework. When a user reads a manga whose text is in a
different language than the app UI, the reader overlays a translation directly
on top of each detected text line. The feature only activates on devices and
OS versions that support Apple Intelligence.

### 1.1 Supported languages

OCR and translation operate over **three languages only: Korean (ko),
Japanese (ja), English (en)** — the same set the app already localizes for.
Anything outside this set is not handled.

### 1.2 In Scope

1. **Device gate.** Translation surfaces (Settings section, Reader popover
   section) are visible only when `SystemLanguageModel` reports the on-device
   language model as `available` AND the build is running on iOS 26+.
2. **Two UI surfaces** for the on/off toggle:
   - `SettingsFeature` — under the existing defaults list, a new "Auto
     translation" section.
   - `ReaderFeature` controls popover — same toggle, mirrored, for in-reader
     quick access.
   Both bind to the same UserDefaults key. There is no per-comic override.
3. **Translation pipeline** (per page):
   - Vision OCR over the page image, constrained to `["ja","ko","en"]`.
   - Language detection over the joined OCR text via `NLLanguageRecognizer`
     constrained to the same three languages.
   - If detected source equals the resolved target language, skip translation
     and cache an empty result.
   - Otherwise, call `SystemLanguageModel` to translate all lines in one
     request, return the translated array.
   - Sample a background color from a small neighborhood around each line's
     bounding box for the overlay fill.
4. **In-place overlay rendering.** Each line is drawn as an opaque rectangle
   (filled with the sampled background color) at the line's bounding box,
   with the translated text on top in the DesignSystem typography. The
   overlay sits inside the page image's aspect-fit container so it scales
   and positions correctly with zoom/pan.
5. **Prefetch.** When the toggle is ON, the current page and pages
   `currentIndex ± 1` are translated. Page changes trigger translation for
   the new neighbors (deduplicating against cache and in-flight set).
6. **Persistent cache.** Translated pages are stored in SwiftData under a
   composite key `(comicId, pageIndex, targetLanguage)`. Cache survives app
   restart. Toggling the feature OFF hides the overlay but does **not**
   invalidate the cache.
7. **Both reading modes.** Single and dual page renderers both render the
   overlay (dual: one overlay per page container).
8. **Library reset.** The existing `LibraryResetService` clears the
   translation cache as part of `resetAll`.

### 1.3 Out of Scope (deferred)

- Speech-bubble / SFX detection or clustering. V1 uses Vision text-line bboxes
  directly.
- Per-comic source-language override.
- Reading PDF embedded text layers; V1 always OCRs the rendered image.
- User feedback on translation quality, manual edits, or alternative variants.
- iCloud sync of the translation cache.
- Manual single-page translate (without enabling the global toggle).
- Translation cache size eviction. Per-page payload is small (KB); even
  thousands of pages stay well under a few MB.

## 2. Capability Gating

A new `IntelligenceAvailability` interface decides whether the feature is
visible anywhere in the UI:

```swift
public protocol IntelligenceAvailability: Sendable {
    var isAvailable: Bool { get }
}
```

Two implementations:

- `LiveIntelligenceAvailability` (iOS 26+) — wraps
  `SystemLanguageModel.default.availability` and returns `true` only for the
  `.available` case.
- `UnavailableIntelligence` — used on iOS < 26 and as the testValue. Returns
  `false` unconditionally.

`DependenciesLive.register()` selects the implementation at runtime:

```swift
if #available(iOS 26.0, *) {
    container.intelligenceAvailability = LiveIntelligenceAvailability()
    container.pageTranslator = LivePageTranslator()
} else {
    container.intelligenceAvailability = UnavailableIntelligence()
    container.pageTranslator = NoopPageTranslator()
}
```

`AppFeature` reads availability once on `.task` and stores it in state.
`SettingsFeature.State` and `ReaderFeature.TranslationState` each carry an
`isIntelligenceAvailable: Bool` so views render or omit the toggle section
without re-checking.

## 3. Architecture

### 3.1 Module Map

```
Domain/Sources/
  Models/
    TextLineBox.swift
    TranslatedLine.swift
    TranslatedPage.swift
  Repositories/
    PageTranslator.swift              (protocol)
    TranslationCache.swift            (protocol)
    IntelligenceAvailability.swift    (protocol)

Data/IntelligenceKit/                  ← NEW Tuist project
  Sources/
    PageTranslatorLive.swift          @available(iOS 26.0, *)
    VisionTextRecognizer.swift
    LanguageDetector.swift
    FoundationModelsTranslator.swift  @available(iOS 26.0, *)
    BackgroundColorSampler.swift
    IntelligenceAvailabilityLive.swift @available(iOS 26.0, *)
    UnavailableIntelligence.swift
    NoopPageTranslator.swift
  Tests/
    LanguageDetectorTests.swift
    BackgroundColorSamplerTests.swift
    VisionTextRecognizerTests.swift   (uses bundled fixture image)

Data/PersistenceKit/Sources/           ← extended
  SwiftDataModels.swift                + TranslatedPageRecord
  TranslationCacheLive.swift           (NEW)

Features/SettingsFeature/Sources/      ← extended
  SettingsFeature.swift                + autoTranslateEnabled state/action
  SettingsView.swift                   + gated section
  Resources/{ko,ja,en}.lproj/Localizable.strings  + new keys

Features/ReaderFeature/Sources/        ← extended
  ReaderFeature.swift                  + TranslationState, actions, prefetch
  ReaderView.swift                     + gated popover section + overlay wiring
  PageTranslationOverlay.swift         (NEW)
  SinglePageRenderer.swift             + overlay parameter
  DualPageRenderer.swift               + overlay parameter
  Resources/{ko,ja,en}.lproj/Localizable.strings  + new keys
```

`Workspace.swift` adds `"Data/IntelligenceKit"`. The new project is a feature
module under `Module(kind: .data)` with external dependency on
`ComposableArchitecture` for the `DependencyKey` plumbing.

### 3.2 Layer rules (unchanged)

- `Domain` has no dependency on any framework other than Foundation.
- `Data/IntelligenceKit` depends on `Domain` and Apple frameworks
  (`Vision`, `NaturalLanguage`, `FoundationModels`, `UIKit`).
- `Data/PersistenceKit` depends on `Domain`; its `TranslationCacheLive`
  conforms to `Domain.TranslationCache`.
- `Features/ReaderFeature` depends on `Domain` and `ImageCacheKit` (unchanged).
  It does **not** import `IntelligenceKit` directly — translation arrives via
  `@Dependency(\.pageTranslator)`.

## 4. Domain Types

```swift
public struct TextLineBox: Equatable, Sendable, Hashable, Codable {
    public let id: UUID
    public let text: String
    /// Vision normalized rect (origin bottom-left, x/y/width/height in 0...1).
    public let boundingBox: CGRect
    public let confidence: Float
}

public struct TranslatedLine: Equatable, Sendable, Codable {
    public let original: TextLineBox
    public let translated: String
    /// ARGB packed (alpha in high byte). Used to fill the opaque overlay.
    public let backgroundColorARGB: UInt32
}

public struct TranslatedPage: Equatable, Sendable, Codable {
    public let comicId: UUID
    public let pageIndex: Int
    /// BCP-47 of the detected source language, or "und" if detection failed.
    public let sourceLanguage: String
    /// BCP-47 of the resolved target language at the time of translation.
    public let targetLanguage: String
    public let lines: [TranslatedLine]
    public let createdAt: Date
}
```

`lines` is empty when:
- OCR found no text on the page.
- Source language equals target (no work to do, but result still cached so we
  don't OCR again on re-open).

Either way, an empty `TranslatedPage` is a valid, fully-resolved state.

## 5. Domain Protocols

```swift
public protocol IntelligenceAvailability: Sendable {
    var isAvailable: Bool { get }
}

public protocol PageTranslator: Sendable {
    /// OCR + language detection + LLM translation for one page.
    /// Returns a `TranslatedPage` (possibly empty) on success.
    /// Throws only on unrecoverable errors (e.g. cancellation).
    func translate(
        imageData: Data,
        comicId: UUID,
        pageIndex: Int,
        targetLanguage: String
    ) async throws -> TranslatedPage
}

public protocol TranslationCache: Sendable {
    func load(comicId: UUID, pageIndex: Int, targetLanguage: String)
        async -> TranslatedPage?
    func save(_ page: TranslatedPage) async throws
    func deleteAll(comicId: UUID) async throws
    func deleteEverything() async throws  // called by LibraryResetService
}
```

`testValue` for both keys uses no-op / in-memory implementations defined in
the IntelligenceKit module so feature tests don't need to wire dependencies
beyond TCA's `withDependencies`.

## 6. Translation Pipeline (`PageTranslatorLive`)

```
imageData ──▶ VisionTextRecognizer
                  recognitionLanguages: ["ja","ko","en"]
                  recognitionLevel: .accurate
                  usesLanguageCorrection: true
              ──▶ [TextLineBox]

if lines.isEmpty:
    return empty TranslatedPage(source: "und", target: targetLanguage)

joinedText = lines.map(\.text).joined(separator: "\n")

LanguageDetector(NLLanguageRecognizer)
  languageConstraints: [.japanese, .korean, .english]
──▶ source ∈ {"ja","ko","en","und"}

if source == targetLanguage:
    return empty TranslatedPage(source: source, target: targetLanguage)

FoundationModelsTranslator(SystemLanguageModel.default)
  prompt template: see §6.1
  input: lines.map(\.text)
──▶ [String]  (must equal lines.count)

if response.count != lines.count:
    return empty TranslatedPage(source: source, target: targetLanguage)
    // silent failure, not cached as success — see §10

BackgroundColorSampler(imageData)
  for each line: sample a small ring around the bbox, average → UInt32
──▶ [UInt32] aligned with lines

return TranslatedPage(
    comicId, pageIndex,
    sourceLanguage: source,
    targetLanguage: targetLanguage,
    lines: zip(lines, translations, backgrounds).map { TranslatedLine(...) },
    createdAt: .now
)
```

### 6.1 Prompt template

```
You translate manga dialogue from {source} to {target}.
Source language is one of: Japanese, Korean, English.
Target language is one of: Japanese, Korean, English.

Rules:
- Translate each line independently, preserve speaker tone, do not merge or
  split lines.
- Keep onomatopoeia (e.g. ドキドキ) untranslated; copy them verbatim.
- Output JSON only: {"lines": ["<t1>", "<t2>", ...]}.
- Output length MUST equal input length.

Input (JSON):
{"lines": ["<l1>", "<l2>", ...]}
```

The translator parses the JSON `lines` array. Any deviation (count mismatch,
parse failure) is treated as a silent failure for that page.

### 6.2 Target-language resolution

```swift
func resolveTargetLanguage(appLanguage: AppLanguage) -> String {
    switch appLanguage {
    case .ko: return "ko"
    case .ja: return "ja"
    case .en: return "en"
    case .system:
        let preferred = Bundle.main.preferredLocalizations.first ?? "ko"
        switch preferred {
        case "ko": return "ko"
        case "ja": return "ja"
        case "en": return "en"
        default: return "ko"  // dev region fallback
        }
    }
}
```

`AppFeature` already owns the `appLanguage` value; it passes the resolved
target language into `ReaderFeature.State` along with the comic when a reader
is pushed.

## 7. ReaderFeature changes

### 7.1 State

```swift
public struct TranslationState: Equatable {
    public var isIntelligenceAvailable: Bool = false
    public var isEnabled: Bool = false
    public var targetLanguage: String = "ko"
    public var pagesInFlight: Set<Int> = []
    public var pages: [Int: TranslatedPage] = [:]
}

public struct State {
    // ...existing fields...
    public var translation: TranslationState
}
```

### 7.2 Actions

```swift
case intelligenceAvailabilityResolved(Bool)
case translationToggleChanged(Bool)
case translatePage(Int)
case translationLoaded(pageIndex: Int, page: TranslatedPage, fromCache: Bool)
case translationFailed(pageIndex: Int)
```

### 7.3 Reducer behavior

- `.task` (extended): after the existing archive open, also dispatch
  `intelligenceAvailabilityResolved(intelligenceAvailability.isAvailable)`
  and read `SettingsFeature.autoTranslateKey` from UserDefaults to seed
  `translation.isEnabled` (clamped to `false` if not available).
- `.intelligenceAvailabilityResolved(true)` AND `translation.isEnabled == true`:
  fire `translatePage` for `[pageIndex - 1, pageIndex, pageIndex + 1]`.
- `.translationToggleChanged(enabled)`:
  - Update state.
  - Persist `enabled ? "true" : "false"` to `SettingsFeature.autoTranslateKey`.
  - If `enabled`: fire `translatePage` for the same ±1 window.
  - If `!enabled`: no-op (cache is preserved; overlay simply not rendered).
- `.translatePage(idx)`:
  - Guard: `idx in 0..<pageCount`, not already in
    `translation.pages`, not in `translation.pagesInFlight`,
    `translation.isEnabled == true`,
    `translation.isIntelligenceAvailable == true`.
  - Add `idx` to `pagesInFlight`, then `.run`:
    - First check `translationCache.load(comicId, idx, targetLanguage)`.
      On hit: dispatch `translationLoaded(idx, cachedPage, fromCache: true)`
      and return.
    - On miss: fetch image bytes from
      `imageCache.data(for: PageKey(comicId, idx))`.
      If missing, decode via `router.reader(for:).pageData(handle, index:)`
      and `imageCache.store(...)` (mirrors existing prefetch pattern).
    - Call `pageTranslator.translate(...)`.
    - On success: dispatch `translationLoaded(idx, page, fromCache: false)`.
    - On any thrown error: dispatch `translationFailed`.
- `.translationLoaded(idx, page, fromCache)`:
  - `translation.pages[idx] = page`.
  - `translation.pagesInFlight.remove(idx)`.
  - If `!fromCache`: save to cache via `translationCache.save(page)`
    (fire-and-forget detached task — same pattern as `persistProgress`).
  - If `fromCache`: skip save (already persisted).
- `.translationFailed(idx)`:
  - `translation.pagesInFlight.remove(idx)`. No retry. No alert.
- `.pageChanged(newIdx)` (extended): if `translation.isEnabled`, additionally
  fire `translatePage(newIdx - 1)`, `translatePage(newIdx)`,
  `translatePage(newIdx + 1)`. Out-of-range and dedup are handled inside
  `translatePage`.

### 7.4 View

`ReaderView.controlsPopover` gets a new section, gated:

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

`SinglePageRenderer` and `DualPageRenderer` accept a new
`pageOverlay: ((Int) -> AnyView)?` closure. ReaderView passes:

```swift
let overlay: (Int) -> AnyView = { idx in
    AnyView(
        PageTranslationOverlay(
            page: store.translation.pages[idx],
            isHidden: !store.translation.isEnabled
        )
    )
}
```

Renderers wrap each visible page with a `ZStack` containing the page image at
its aspect-fit size and `overlay(idx)` matched to the same frame. The overlay
must sit inside the image-sized container, not the screen bounds, so
GeometryReader inside `PageTranslationOverlay` reads the image's drawn rect.

### 7.5 Overlay view

```swift
struct PageTranslationOverlay: View {
    let page: TranslatedPage?
    let isHidden: Bool

    var body: some View {
        if !isHidden, let page, !page.lines.isEmpty {
            GeometryReader { proxy in
                ForEach(page.lines, id: \.original.id) { line in
                    let bb = line.original.boundingBox
                    let w = proxy.size.width * bb.width
                    let h = proxy.size.height * bb.height
                    Text(line.translated)
                        .font(Tokens.Typography.subtitle)
                        .foregroundStyle(Tokens.Colors.ink)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.4)
                        .lineLimit(nil)
                        .padding(2)
                        .frame(width: w, height: h)
                        .background(Color(argb: line.backgroundColorARGB))
                        .position(
                            x: proxy.size.width * bb.midX,
                            y: proxy.size.height * (1 - bb.midY)
                        )
                }
            }
            .allowsHitTesting(false)
        }
    }
}
```

Vision uses origin-bottom-left; SwiftUI uses origin-top-left, hence the
`1 - bb.midY` flip. `Color(argb:)` is a `DesignSystem` extension that
unpacks `UInt32` ARGB into `Color(.sRGB, red:, green:, blue:, opacity:)`.

## 8. SettingsFeature changes

### 8.1 State / Action

```swift
public struct State {
    // ...existing...
    public var isIntelligenceAvailable: Bool = false
    public var autoTranslateEnabled: Bool = false
}

public enum Action {
    // ...existing...
    case autoTranslateChanged(Bool)
}

public static let autoTranslateKey = "mana.autoTranslateEnabled"
```

### 8.2 Reducer

- `.task` (extended): read `autoTranslateKey` from UserDefaults and seed
  `autoTranslateEnabled` (clamped to `false` if `isIntelligenceAvailable` is
  false).
- `.autoTranslateChanged(enabled)`:
  - `state.autoTranslateEnabled = enabled`.
  - `defaults.set(enabled ? "true" : "false", forKey: Self.autoTranslateKey)`.

### 8.3 AppFeature wiring

`AppFeature.State` gains `isIntelligenceAvailable: Bool` (default `false`).
`AppFeature.task` resolves availability via
`@Dependency(\.intelligenceAvailability)`.
The `library(.settingsTapped)` branch constructs
`SettingsFeature.State(appLanguage:, isIntelligenceAvailable:)` so Settings
shows or hides the section based on the value seen at app start.

### 8.4 View

`SettingsView` adds a new gated section between the existing defaults and
the reset button:

```swift
if store.isIntelligenceAvailable {
    Section(localized("settings.translate.section")) {
        Toggle(localized("settings.translate.toggle"),
               isOn: $store.autoTranslateEnabled.sending(\.autoTranslateChanged))
        Text(localized("settings.translate.description"))
            .font(Tokens.Typography.caption)
            .foregroundStyle(Tokens.Colors.ink.opacity(0.6))
    }
}
```

## 9. Caching

### 9.1 SwiftData model

Added to `Data/PersistenceKit/Sources/SwiftDataModels.swift`:

```swift
@Model
public final class TranslatedPageRecord {
    @Attribute(.unique) public var key: String   // "<comicId>|<idx>|<target>"
    public var comicId: UUID
    public var pageIndex: Int
    public var targetLanguage: String
    public var sourceLanguage: String
    public var linesJSON: Data
    public var createdAt: Date

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
}
```

`SwiftDataStack` adds `TranslatedPageRecord.self` to its schema.

### 9.2 TranslationCacheLive

- `load`: query by composite `key`. Decode `linesJSON` into
  `[TranslatedLine]`. Build and return `TranslatedPage`.
- `save`: upsert by `key` (delete existing then insert; simpler than
  partial update). Encode `lines` to JSON.
- `deleteAll(comicId:)`: delete records matching `comicId`.
- `deleteEverything()`: delete all `TranslatedPageRecord`s. Called from
  `LibraryResetServiceLive.resetAll()` alongside the existing comic /
  folder / progress resets.

## 10. Error Handling

V1 fails silently for translation. The user experience for any single-page
failure is "no overlay appeared on this page"; the rest of the reader keeps
working. The toggle stays ON, and a subsequent page change can succeed.

| Condition                                  | Behavior                                                       |
| ------------------------------------------ | -------------------------------------------------------------- |
| Apple Intelligence unavailable             | Toggle UI hidden in Settings and Reader. No code path runs.    |
| OCR returns zero lines                     | Cache empty `TranslatedPage`; overlay renders nothing.         |
| Source language detected = target          | Cache empty `TranslatedPage`; overlay renders nothing.         |
| LLM line count mismatch / JSON parse fail  | Dispatch `translationFailed`; nothing cached; can retry later. |
| Model transiently unavailable / throws     | Dispatch `translationFailed`; nothing cached.                  |
| Cancellation (reader dismissed)            | TCA cancels the effect; no state mutation.                     |
| Image bytes unavailable from cache & router throws | Dispatch `translationFailed`.                          |

All failures log via `os.Logger(subsystem: "com.coby.mana",
category: "translation")` at `.error`. No alert, no banner.

## 11. Testing

### 11.1 Domain
- `TextLineBox` / `TranslatedLine` / `TranslatedPage` equality + Codable
  round-trips.

### 11.2 IntelligenceKit
- `LanguageDetectorTests` — feed strings, expect BCP-47 from
  `{ja,ko,en,und}`.
- `BackgroundColorSamplerTests` — synthesize small `UIImage`s with known
  colors, verify sampled ARGB.
- `VisionTextRecognizerTests` — bundle a small PNG with known text under
  `Tests/Resources/`, assert at least one line recognized at expected
  language.
- Foundation Models is **not** unit-tested live in CI. The translator
  conforms to a thin internal protocol so tests inject a fake.

### 11.3 PersistenceKit
- `TranslationCacheLiveTests` — save / load round-trip, deleteAll(comicId),
  deleteEverything.

### 11.4 ReaderFeature
- Toggle ON dispatches `translatePage` for currentIndex ± 1.
- Toggle OFF does not dispatch new translates and keeps cached pages in
  state.
- Cache hit returns synchronously without entering `pagesInFlight`.
- Translation failure removes the index from `pagesInFlight` and does not
  populate `pages`.
- Page change while ON dispatches the new neighbor window, deduping against
  cache and in-flight set.

### 11.5 SettingsFeature
- `task` reads `autoTranslateKey` and reflects it.
- `autoTranslateChanged(true)` persists to UserDefaults.
- View gating: when `isIntelligenceAvailable == false`, the section is not
  emitted (snapshot via TestStore observation is sufficient — view layer
  tests not required).

### 11.6 Integration
- `App/Tests/IntegrationFlowTests.swift` gains one happy-path case using the
  fake translator: open reader with toggle pre-enabled, expect overlay
  pages populated after a tick.

## 12. Localization Keys

`Features/SettingsFeature/Resources/{ko,ja,en}.lproj/Localizable.strings`:

| Key                                | ko                                     | ja                                       | en                              |
| ---------------------------------- | -------------------------------------- | ---------------------------------------- | ------------------------------- |
| `settings.translate.section`       | 자동 번역                              | 自動翻訳                                 | Auto translation                |
| `settings.translate.toggle`        | 페이지 자동 번역                       | ページ自動翻訳                           | Translate pages automatically   |
| `settings.translate.description`   | 지원되는 기기에서만 표시됩니다.        | 対応デバイスでのみ表示されます。         | Available on supported devices. |

`Features/ReaderFeature/Resources/{ko,ja,en}.lproj/Localizable.strings`:

| Key                          | ko       | ja        | en         |
| ---------------------------- | -------- | --------- | ---------- |
| `reader.controls.translate`  | 번역     | 翻訳      | Translate  |
| `translate.on`               | 켜기     | オン      | On         |
| `translate.off`              | 끄기     | オフ      | Off        |

## 13. Deployment Target

Project remains at iOS 17.0 deployment target. All Foundation Models code
sits behind `@available(iOS 26.0, *)` annotations inside
`Data/IntelligenceKit`. Runtime selection happens in
`App/Sources/DependenciesLive.swift`. No `Info.plist` permission keys are
required for on-device LLM use.

## 14. Risks & Open Questions

- **Vision OCR quality on stylized manga lettering** is the largest unknown.
  Empirically Apple's OCR handles standard printed Japanese well but stumbles
  on hand-lettered SFX and irregular fonts. The chosen scope (line bbox, no
  SFX clustering) keeps us within OCR's strengths.
- **LLM latency.** A page with ~10 lines should complete within ~1–2 s on a
  modern device. Prefetch is the primary mitigation. Worst case: user flips
  faster than translation arrives; the page renders with no overlay until
  `translationLoaded` arrives a moment later — acceptable.
- **Memory.** Translation pages are tiny (≤ a few KB JSON). Holding all
  visited pages in `translation.pages` for a session is fine; SwiftData
  re-hydration on re-open is fast.
- **Adaptive zoom/pan.** Overlay uses normalized coordinates inside the
  image's aspect-fit container, so zoom/pan transforms applied by the
  existing `ZoomableImageView` propagate automatically. Verify during
  implementation.

## 15. Acceptance

The feature is ready to ship when:

1. On an iOS 26 device with Apple Intelligence enabled, the Settings screen
   and the Reader controls popover both show the toggle.
2. On a device without Apple Intelligence (or older OS), neither surface
   shows the toggle and no Foundation Models symbols are touched at runtime.
3. With the toggle ON, opening a Japanese-text manga in the reader renders a
   Korean overlay on each detected text line within ~2 s for the current
   page, and prefetched neighbors render instantly when flipped to.
4. Toggling OFF immediately hides the overlay; toggling ON again
   instantly restores it from cache.
5. `LibraryResetServiceLive.resetAll()` clears the translation cache along
   with the rest of the library state.
6. All new unit tests pass (`Domain`, `IntelligenceKit`, `PersistenceKit`,
   `ReaderFeature`, `SettingsFeature`).

import SwiftUI
import ComposableArchitecture
import Domain
import DesignSystem

private extension Bundle {
    func localized(_ key: String, for locale: Locale) -> String {
        let langCode = locale.language.languageCode?.identifier ?? "en"
        if let path = path(forResource: langCode, ofType: "lproj"), let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return localizedString(forKey: key, value: nil, table: nil)
    }
}

public struct MangaDetailView: View {
    @Bindable public var store: StoreOf<MangaDetailFeature>
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<MangaDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            BrowseChromeHeader(onBack: { dismiss() }) { headerTrailing }
            Group {
                if store.loading {
                    ManaLoader()
                } else if store.error || store.detail == nil {
                    BrowseRetryBlock(title: localized("detail.error"), retryTitle: localized("detail.retry")) {
                        store.send(.retry)
                    }
                } else if let detail = store.detail {
                    content(detail)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .browseScreenChrome()
        .overlay(alignment: .bottom) {
            if store.selectionMode {
                selectionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: store.selectionMode)
        .overlay(alignment: .bottom) { toast }
        .animation(.easeOut(duration: 0.2), value: store.queuedToastCount)
        .overlay { downloadAllDialog }
        .task { await store.send(.task).finish() }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerTrailing: some View {
        if store.selectionMode {
            Button { store.send(.selectAll) } label: {
                MangaIconBadge(systemName: "checklist.checked")
            }
            .buttonStyle(MangaPressStyle(haptic: .tick))
            Button { store.send(.clearSelection) } label: {
                MangaIconBadge(systemName: "checkmark", isAccent: true)
            }
            .buttonStyle(MangaPressStyle())
        } else if store.detail != nil {
            Button { store.send(.downloadAllTapped) } label: {
                MangaIconBadge(systemName: "arrow.down.circle")
            }
            .buttonStyle(MangaPressStyle())
            Button { store.send(.enterSelection) } label: {
                MangaIconBadge(systemName: "checklist")
            }
            .buttonStyle(MangaPressStyle(haptic: .tick))
        }
    }

    // MARK: - Content

    private func content(_ detail: SourceDetail) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                infoBlock(detail)
                    .padding(.bottom, 4)
                if let synopsis = detail.synopsis, !synopsis.isEmpty {
                    Text(verbatim: synopsis)
                        .font(Tokens.Typography.body)
                        .foregroundStyle(Tokens.Colors.ink.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 4)
                }
                Text(verbatim: localized("detail.chapters"))
                    .font(Tokens.Typography.title)
                    .foregroundStyle(Tokens.Colors.ink)
                    .padding(.top, Tokens.Spacing.s)
                // Oldest-first, matching Android.
                ForEach(detail.chapters) { chapter in
                    chapterRow(chapter)
                }
            }
            .padding(.horizontal, Tokens.Spacing.m)
            .padding(.top, Tokens.Spacing.s)
            .padding(.bottom, store.selectionMode ? 96 : Tokens.Spacing.m)
        }
    }

    private func infoBlock(_ detail: SourceDetail) -> some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.m) {
            MangaPanel(surface: .paper, strokeWidth: Tokens.Stroke.panel) {
                Color.clear
                    .frame(width: 120, height: 170)
                    .overlay { SourceImage(url: detail.coverURL ?? store.preview?.coverURL, headers: store.imageHeaders) }
                    .clipped()
            }
            .padding(.trailing, 4)
            .padding(.bottom, 5)
            VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
                SoundEffectText(
                    detail.title,
                    font: Tokens.Typography.title,
                    fill: Tokens.Colors.accent,
                    stroke: Tokens.Colors.ink,
                    strokeWidth: 3,
                    tilt: -2,
                    shadowOffset: .init(width: 2, height: 3)
                )
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                if !detail.genres.isEmpty {
                    Text(verbatim: detail.genres.map(\.name).joined(separator: " · "))
                        .font(Tokens.Typography.caption)
                        .foregroundStyle(Tokens.Colors.ink.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Chapter row

    private func chapterRow(_ chapter: SourceChapter) -> some View {
        let isDownloaded = store.downloaded.contains(chapter.url)
        let progress = store.downloading[chapter.url]
        let isFailed = store.failed.contains(chapter.url)
        let isRead = store.read.contains(chapter.url)
        let isSelected = store.selected.contains(chapter.url)
        // Dim chapters read online that aren't downloaded, so you see where you are.
        let dimmed = isRead && !isDownloaded

        return HStack(spacing: 0) {
            Button {
                if store.selectionMode { store.send(.toggleSelect(chapter)) }
                else { store.send(.chapterTapped(chapter)) }
            } label: {
                HStack(spacing: Tokens.Spacing.s) {
                    if store.selectionMode {
                        Image(systemName: isSelected ? "checkmark" : "circle")
                            .font(.system(size: 18, weight: isSelected ? .black : .regular))
                            .foregroundStyle(isSelected ? Tokens.Colors.accent : Tokens.Colors.ink.opacity(0.5))
                            .frame(width: 22, height: 22)
                    }
                    if dimmed {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Tokens.Colors.ink.opacity(0.5))
                            .frame(width: 16, height: 16)
                    }
                    Text(verbatim: chapter.name)
                        .font(Tokens.Typography.body)
                        .foregroundStyle(dimmed ? Tokens.Colors.ink.opacity(0.5) : Tokens.Colors.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, Tokens.Spacing.m)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(MangaPressStyle(haptic: store.selectionMode ? .tick : .tap, pressedScale: 1))

            // Fixed-size status slot so the row height never shifts between states.
            if !store.selectionMode {
                statusSlot(chapter, isDownloaded: isDownloaded, progress: progress, isFailed: isFailed)
                    .frame(width: 72, height: 36)
                    .padding(.trailing, Tokens.Spacing.s)
            }
        }
        .frame(height: 44)
        .background(isSelected ? Tokens.Colors.accent.opacity(0.18) : Tokens.Colors.paper)
        .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular))
    }

    @ViewBuilder
    private func statusSlot(_ chapter: SourceChapter, isDownloaded: Bool, progress: ChapterProgress?, isFailed: Bool) -> some View {
        if let progress {
            Button { store.send(.cancelChapter(chapter)) } label: {
                HStack(spacing: 6) {
                    ChapterProgressRing(
                        fraction: progress.total > 0 ? Double(progress.done) / Double(progress.total) : nil
                    )
                    .frame(width: 18, height: 18)
                    if progress.total > 0 {
                        Text(verbatim: "\(progress.done)/\(progress.total)")
                            .font(Tokens.Typography.caption)
                            .foregroundStyle(Tokens.Colors.ink.opacity(0.7))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(width: 72, height: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(MangaPressStyle())
        } else if isDownloaded {
            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Tokens.Colors.accent)
                .frame(width: 22, height: 22)
        } else {
            Button { store.send(.downloadChapter(chapter)) } label: {
                Image(systemName: isFailed ? "arrow.clockwise" : "arrow.down.to.line")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isFailed ? Tokens.Colors.paper : Tokens.Colors.ink)
                    .frame(width: 18, height: 18)
                    .padding(.horizontal, Tokens.Spacing.s)
                    .padding(.vertical, 4)
                    .background(isFailed ? Tokens.Colors.accent : Tokens.Colors.paper)
                    .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: 1.5))
                    .frame(width: 72, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MangaPressStyle(haptic: .confirm))
        }
    }

    // MARK: - Selection bar

    private var selectionBar: some View {
        let count = store.selected.count
        let enabled = count > 0
        return Button { store.send(.downloadSelected) } label: {
            HStack(spacing: Tokens.Spacing.s) {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 17, weight: .black))
                Text(verbatim: String(format: localized("detail.download_count"), count))
                    .font(Tokens.Typography.title)
            }
            .foregroundStyle(enabled ? Tokens.Colors.paper : Tokens.Colors.ink.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Spacing.m)
            .background(enabled ? Tokens.Colors.accent : Tokens.Colors.paper)
            .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.bold))
            .background(Rectangle().fill(Tokens.Colors.ink).offset(x: 5, y: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(MangaPressStyle(haptic: .confirm))
        .disabled(!enabled)
        .padding(Tokens.Spacing.m)
    }

    // MARK: - Download all dialog + toast

    private var downloadAllDialog: some View {
        MangaDialogHost(
            isPresented: store.downloadAllPresented,
            onDismiss: { store.send(.downloadAllDismissed) }
        ) {
            let pending = store.downloadAllPending
            if pending > 0 {
                MangaDialogPanel(
                    title: localized("detail.download_all_title"),
                    message: String(format: localized("detail.download_all_message"), pending),
                    cancelTitle: localized("detail.cancel"),
                    confirmTitle: localized("detail.download_all_confirm"),
                    onCancel: { store.send(.downloadAllDismissed) },
                    onConfirm: { store.send(.downloadAllConfirmed) }
                )
            } else {
                // Nothing to queue: a single acknowledge button.
                MangaDialogPanel(
                    title: localized("detail.download_all_title"),
                    message: localized("detail.download_all_none"),
                    cancelTitle: nil,
                    confirmTitle: localized("detail.ok"),
                    onConfirm: { store.send(.downloadAllDismissed) }
                )
            }
        }
    }

    @ViewBuilder
    private var toast: some View {
        if let count = store.queuedToastCount {
            Text(verbatim: String(format: localized("detail.download_queued_toast"), count))
                .font(Tokens.Typography.subtitle)
                .foregroundStyle(Tokens.Colors.paper)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Spacing.m)
                .padding(.vertical, 10)
                .background(Capsule().fill(Tokens.Colors.ink.opacity(0.9)))
                .padding(.horizontal, Tokens.Spacing.l)
                .padding(.bottom, Tokens.Spacing.l)
                .allowsHitTesting(false)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func localized(_ key: String) -> String { Bundle.module.localized(key, for: locale) }
}

/// 18pt accent ring: determinate arc when `fraction` is known, spinning arc otherwise
/// (Android `CircularProgressIndicator`, strokeWidth 2dp).
struct ChapterProgressRing: View {
    let fraction: Double?

    var body: some View {
        if let fraction {
            ZStack {
                Circle().stroke(Tokens.Colors.accent.opacity(0.2), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: max(0.02, min(1, fraction)))
                    .stroke(Tokens.Colors.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(1)
        } else {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Tokens.Colors.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees((t * 360).truncatingRemainder(dividingBy: 360)))
                    .padding(1)
            }
        }
    }
}

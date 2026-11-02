import SwiftUI
import UIKit
import ComposableArchitecture
import Domain
import DesignSystem
import ReaderFeature

private extension Bundle {
    func localized(_ key: String, for locale: Locale) -> String {
        let langCode = locale.language.languageCode?.identifier ?? "en"
        if let path = path(forResource: langCode, ofType: "lproj"), let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return localizedString(forKey: key, value: nil, table: nil)
    }
}

public struct OnlineReaderView: View {
    @Bindable public var store: StoreOf<OnlineReaderFeature>
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    public init(store: StoreOf<OnlineReaderFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if store.loading {
                ProgressView().tint(Tokens.Colors.accent)
            } else if store.error {
                errorState
            } else if store.pageCount > 0 {
                renderer.ignoresSafeArea()
            }
            if store.isControlsVisible { controlsOverlay }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .statusBarHidden(true)
        .task { await store.send(.task).finish() }
    }

    @ViewBuilder
    private var renderer: some View {
        let headers = store.imageHeaders
        let urls = store.pageURLs
        let provider: (Int) async -> UIImage? = { idx in
            guard idx >= 0, idx < urls.count else { return nil }
            for _ in 0..<3 {
                if let img = await RemoteImageLoader.shared.load(urls[idx], headers: headers) { return img }
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
            return nil
        }
        let binding = Binding<Int>(get: { store.pageIndex }, set: { store.send(.pageChanged($0)) })
        // Warm the next few pages so page turns are instant.
        let hint: (Int) -> Void = { idx in
            let upcoming = urls.indices.filter { $0 > idx && $0 <= idx + 4 }.map { urls[$0] }
            RemoteImageLoader.shared.prefetch(upcoming, headers: headers)
        }
        let centerTap: () -> Void = { store.send(.toggleControls) }

        switch store.mode {
        case .single:
            SinglePageRenderer(totalPages: store.pageCount, current: binding, pageImage: provider,
                               onPrefetchHint: hint, progressionDirection: store.direction,
                               tapZonesEnabled: true, swipeEnabled: true, onCenterTap: centerTap,
                               pageOffset: store.pageOffset, pageOverlay: nil)
        case .dual:
            DualPageRenderer(totalPages: store.pageCount, current: binding, pageImage: provider,
                             onPrefetchHint: hint, progressionDirection: store.direction,
                             tapZonesEnabled: true, swipeEnabled: true, onCenterTap: centerTap,
                             pageOffset: store.pageOffset, pageOverlay: nil)
        case .webtoon:
            WebtoonRenderer(totalPages: store.pageCount, current: binding, pageImage: provider,
                            onPrefetchHint: hint, onCenterTap: centerTap, pageOverlay: nil)
        }
    }

    @ViewBuilder
    private var controlsOverlay: some View {
        VStack {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .black))
                        .foregroundStyle(Tokens.Colors.paper).frame(width: 36, height: 36).background(Tokens.Colors.ink)
                }
                Text(verbatim: store.title).font(Tokens.Typography.subtitle).foregroundStyle(Tokens.Colors.paper).lineLimit(1)
                Spacer()
                optionsMenu
            }
            .padding(12).background(Tokens.Colors.ink.opacity(0.85))
            Spacer()
            HStack {
                Spacer()
                Text(verbatim: "\(store.pageIndex + 1) / \(store.pageCount)")
                    .font(Tokens.Typography.mono).foregroundStyle(Tokens.Colors.paper)
                    .padding(.horizontal, 10).padding(.vertical, 4).background(Tokens.Colors.ink)
                Spacer()
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 12).foregroundStyle(Tokens.Colors.paper)
    }

    private var optionsMenu: some View {
        Menu {
            Picker(localized("online.mode"), selection: Binding(get: { store.mode }, set: { store.send(.modeChanged($0)) })) {
                Text(verbatim: localized("online.mode.single")).tag(ReadingMode.single)
                Text(verbatim: localized("online.mode.dual")).tag(ReadingMode.dual)
                Text(verbatim: localized("online.mode.webtoon")).tag(ReadingMode.webtoon)
            }
            Picker(localized("online.direction"), selection: Binding(get: { store.direction }, set: { store.send(.directionChanged($0)) })) {
                Text(verbatim: localized("online.ltr")).tag(PageProgressionDirection.leftToRight)
                Text(verbatim: localized("online.rtl")).tag(PageProgressionDirection.rightToLeft)
            }
            Toggle(localized("online.offset"), isOn: Binding(get: { store.pageOffset }, set: { store.send(.pageOffsetChanged($0)) }))
        } label: {
            Image(systemName: "slider.horizontal.3").font(.system(size: 18, weight: .black))
                .foregroundStyle(Tokens.Colors.paper).frame(width: 36, height: 36).background(Tokens.Colors.ink)
        }
    }

    private var errorState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 40, weight: .bold)).foregroundStyle(Tokens.Colors.accent)
            Button { store.send(.retry) } label: {
                Text(verbatim: localized("online.retry")).font(Tokens.Typography.subtitle)
                    .foregroundStyle(Tokens.Colors.ink).padding(.horizontal, 20).padding(.vertical, 10).background(Tokens.Colors.paper)
            }
            Button { dismiss() } label: {
                Text(verbatim: localized("online.back")).foregroundStyle(Tokens.Colors.paper)
            }
        }
    }

    private func localized(_ key: String) -> String { Bundle.module.localized(key, for: locale) }
}

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

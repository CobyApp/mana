import SwiftUI
import ComposableArchitecture
import LibraryFeature
import ReaderFeature
import BookmarksFeature
import SettingsFeature

public struct AppView: View {
    @Bindable public var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            LibraryView(store: store.scope(state: \.library, action: \.library))
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
    }
}

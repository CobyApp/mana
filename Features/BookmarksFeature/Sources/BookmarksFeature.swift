import Foundation
import ComposableArchitecture
import Domain

@Reducer
public struct BookmarksFeature {
    public init() {}

    public struct AddBookmarkSheet: Equatable, Sendable {
        public struct State: Equatable, Sendable {
            public let pageIndex: Int
            public var note: String = ""

            public init(pageIndex: Int) {
                self.pageIndex = pageIndex
            }
        }
    }

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

    public enum Action {
        case task
        case refreshed([Bookmark])
        case addRequested(pageIndex: Int, note: String?)
        case addSheetRequested
        case addSheetDismissed
        case addSheetNoteChanged(String)
        case addSheetSubmitted
        case bookmarkAdded(Bookmark)
        case removeRequested(UUID)
        case bookmarkRemoved(UUID)
        case tapped(Bookmark)
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
                let bm = Bookmark(
                    id: uuid(),
                    comicId: state.comicId,
                    pageIndex: sheet.pageIndex,
                    note: sheet.note.isEmpty ? nil : sheet.note,
                    createdAt: now
                )
                state.bookmarks.append(bm)
                state.addSheet = nil
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

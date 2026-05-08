import Foundation
import ComposableArchitecture
import Domain

public protocol LibraryImporter: Sendable {
    /// Take user-picked file URLs, ingest them, and return persisted ComicItems.
    func importFiles(_ urls: [URL]) async throws -> [ComicItem]
}

@Reducer
public struct LibraryFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var comics: IdentifiedArrayOf<ComicItem> = []
        public var isImporting: Bool = false
        @Presents public var alert: AlertState<Action.Alert>?

        public init(
            comics: IdentifiedArrayOf<ComicItem> = [],
            isImporting: Bool = false
        ) {
            self.comics = comics
            self.isImporting = isImporting
        }
    }

    public enum Action {
        case task
        case refreshed([ComicItem])
        case importTapped
        case importPicked([URL])
        case imported([ComicItem])
        case importFailed(String)
        case comicTapped(ComicItem)
        case delete(IndexSet)
        case settingsTapped
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    @Dependency(\.comicRepository) var repo
    @Dependency(\.libraryImporter) var importer

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    let items = await repo.all()
                    await send(.refreshed(items))
                }

            case let .refreshed(items):
                state.comics = IdentifiedArray(uniqueElements: items)
                return .none

            case .importTapped:
                // Parent presents Files picker; reducer reacts to .importPicked
                return .none

            case let .importPicked(urls):
                state.isImporting = true
                return .run { send in
                    do {
                        let imported = try await importer.importFiles(urls)
                        await send(.imported(imported))
                    } catch {
                        await send(.importFailed(error.localizedDescription))
                    }
                }

            case let .imported(items):
                state.isImporting = false
                for item in items {
                    state.comics.updateOrAppend(item)
                }
                return .none

            case let .importFailed(message):
                state.isImporting = false
                state.alert = AlertState {
                    TextState("Import failed")
                } message: {
                    TextState(message)
                }
                return .none

            case .comicTapped:
                // Parent (AppFeature) handles navigation
                return .none

            case .settingsTapped:
                // Parent (AppFeature) handles navigation
                return .none

            case let .delete(indexSet):
                let ids = indexSet.map { state.comics[$0].id }
                for id in ids { state.comics.remove(id: id) }
                return .run { _ in
                    for id in ids {
                        try? await repo.delete(id)
                    }
                }

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

private enum ComicRepositoryKey: DependencyKey {
    static let liveValue: any ComicRepository = LiveComicRepoPlaceholder()
}

private struct LiveComicRepoPlaceholder: ComicRepository {
    func all() async -> [ComicItem] { [] }
    func comic(id: UUID) async -> ComicItem? { nil }
    func upsert(_ item: ComicItem) async throws {}
    func delete(_ id: UUID) async throws {}
}

private enum LibraryImporterKey: DependencyKey {
    static let liveValue: any LibraryImporter = LiveImporterPlaceholder()
}

private struct LiveImporterPlaceholder: LibraryImporter {
    func importFiles(_ urls: [URL]) async throws -> [ComicItem] { [] }
}

extension DependencyValues {
    public var comicRepository: any ComicRepository {
        get { self[ComicRepositoryKey.self] }
        set { self[ComicRepositoryKey.self] = newValue }
    }
    public var libraryImporter: any LibraryImporter {
        get { self[LibraryImporterKey.self] }
        set { self[LibraryImporterKey.self] = newValue }
    }
}

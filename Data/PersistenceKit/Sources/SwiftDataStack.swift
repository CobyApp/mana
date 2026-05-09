import Foundation
import SwiftData

public final class SwiftDataStack: @unchecked Sendable {
    public let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public static func inMemory() throws -> SwiftDataStack {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ComicEntity.self, ReadingProgressEntity.self, BookmarkEntity.self, FolderEntity.self,
            configurations: config
        )
        return SwiftDataStack(container: container)
    }

    public static func onDisk(url: URL) throws -> SwiftDataStack {
        let config = ModelConfiguration(url: url)
        let container = try ModelContainer(
            for: ComicEntity.self, ReadingProgressEntity.self, BookmarkEntity.self, FolderEntity.self,
            configurations: config
        )
        return SwiftDataStack(container: container)
    }

    public static func cloudKit(containerIdentifier: String) throws -> SwiftDataStack {
        let config = ModelConfiguration(cloudKitDatabase: .private(containerIdentifier))
        let container = try ModelContainer(
            for: ComicEntity.self, ReadingProgressEntity.self, BookmarkEntity.self, FolderEntity.self,
            configurations: config
        )
        return SwiftDataStack(container: container)
    }
}

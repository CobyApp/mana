import Foundation
import SwiftData
import Domain

public actor TranslationCacheLive: TranslationCache {
    private let stack: SwiftDataStack
    private lazy var context: ModelContext = ModelContext(stack.container)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(stack: SwiftDataStack) {
        self.stack = stack
    }

    public func load(comicId: UUID, pageIndex: Int, targetLanguage: String) async -> TranslatedPage? {
        let key = TranslatedPageRecord.compositeKey(
            comicId: comicId, pageIndex: pageIndex, targetLanguage: targetLanguage
        )
        let predicate = #Predicate<TranslatedPageRecord> { $0.key == key }
        var descriptor = FetchDescriptor<TranslatedPageRecord>(predicate: predicate)
        descriptor.fetchLimit = 1
        guard
            let record = try? context.fetch(descriptor).first,
            let lines = try? decoder.decode([TranslatedLine].self, from: record.linesJSON)
        else { return nil }

        return TranslatedPage(
            comicId: record.comicId,
            pageIndex: record.pageIndex,
            sourceLanguage: record.sourceLanguage,
            targetLanguage: record.targetLanguage,
            lines: lines,
            createdAt: record.createdAt
        )
    }

    public func save(_ page: TranslatedPage) async throws {
        let key = TranslatedPageRecord.compositeKey(
            comicId: page.comicId, pageIndex: page.pageIndex, targetLanguage: page.targetLanguage
        )
        let predicate = #Predicate<TranslatedPageRecord> { $0.key == key }
        let descriptor = FetchDescriptor<TranslatedPageRecord>(predicate: predicate)
        let existing = try context.fetch(descriptor)
        for record in existing {
            context.delete(record)
        }

        let json = try encoder.encode(page.lines)
        let record = TranslatedPageRecord(
            comicId: page.comicId,
            pageIndex: page.pageIndex,
            targetLanguage: page.targetLanguage,
            sourceLanguage: page.sourceLanguage,
            linesJSON: json,
            createdAt: page.createdAt
        )
        context.insert(record)
        try context.save()
    }

    public func deleteAll(comicId: UUID) async throws {
        let predicate = #Predicate<TranslatedPageRecord> { $0.comicId == comicId }
        let descriptor = FetchDescriptor<TranslatedPageRecord>(predicate: predicate)
        for record in try context.fetch(descriptor) {
            context.delete(record)
        }
        try context.save()
    }

    public func deleteEverything() async throws {
        let descriptor = FetchDescriptor<TranslatedPageRecord>()
        for record in try context.fetch(descriptor) {
            context.delete(record)
        }
        try context.save()
    }
}

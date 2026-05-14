// Features/ReaderFeature/Sources/TranslationDependencyKeys.swift
import Foundation
import ComposableArchitecture
import Domain
import IntelligenceKit

private enum PageTranslatorKey: DependencyKey {
    static let liveValue: any PageTranslator = NoopPageTranslator()
    static let testValue: any PageTranslator = NoopPageTranslator()
}

private enum TranslationCacheKey: DependencyKey {
    static let liveValue: any TranslationCache = InMemoryTranslationCache()
    static let testValue: any TranslationCache = InMemoryTranslationCache()
}

extension DependencyValues {
    public var pageTranslator: any PageTranslator {
        get { self[PageTranslatorKey.self] }
        set { self[PageTranslatorKey.self] = newValue }
    }
    public var translationCache: any TranslationCache {
        get { self[TranslationCacheKey.self] }
        set { self[TranslationCacheKey.self] = newValue }
    }
}

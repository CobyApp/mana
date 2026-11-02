import Foundation
import Domain

/// v1 registry — rawkuma is the only registered source.
public struct RawkumaRegistry: SourceRegistry {
    private let rawkuma: MangaSource

    public init(rawkuma: MangaSource = RawkumaSource()) {
        self.rawkuma = rawkuma
    }

    public func active() -> MangaSource { rawkuma }
    public func all() -> [MangaSource] { [rawkuma] }
}

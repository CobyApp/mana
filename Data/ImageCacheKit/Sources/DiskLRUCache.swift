import Foundation

actor DiskLRUCache {
    private let directory: URL
    private let capacityBytes: Int
    private var totalBytes: Int = 0
    private var accessOrder: [String] = []   // newest at end

    init(directory: URL, capacityBytes: Int) {
        self.directory = directory
        self.capacityBytes = capacityBytes
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Inline index rebuild — avoids calling actor-isolated method before init completes (Swift 6).
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey]
        )) ?? []
        let sorted = items.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? .distantPast
            return l < r
        }
        self.accessOrder = sorted.map { $0.lastPathComponent }
        self.totalBytes = sorted.reduce(0) { acc, url in
            acc + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    func read(name: String) -> Data? {
        let url = directory.appending(path: name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        touch(name)
        return data
    }

    func write(name: String, data: Data) throws {
        let url = directory.appending(path: name)
        try data.write(to: url, options: .atomic)
        if let idx = accessOrder.firstIndex(of: name) {
            accessOrder.remove(at: idx)
        } else {
            totalBytes += data.count
        }
        accessOrder.append(name)
        evictIfNeeded()
    }

    private func touch(_ name: String) {
        if let idx = accessOrder.firstIndex(of: name) {
            accessOrder.remove(at: idx)
            accessOrder.append(name)
        }
    }

    private func evictIfNeeded() {
        let fm = FileManager.default
        while totalBytes > capacityBytes, let oldest = accessOrder.first {
            let url = directory.appending(path: oldest)
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            try? fm.removeItem(at: url)
            totalBytes -= size
            accessOrder.removeFirst()
        }
    }
}

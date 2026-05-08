import Foundation

public actor ImageCache {
    private let memoryLimit: Int
    private var memory: [PageKey: Data] = [:]
    private var memoryOrder: [PageKey] = []
    private let disk: DiskLRUCache?

    public init(diskDirectory: URL?, diskCapacityBytes: Int = 200_000_000, memoryLimit: Int = 50) {
        self.memoryLimit = memoryLimit
        self.disk = diskDirectory.map { DiskLRUCache(directory: $0, capacityBytes: diskCapacityBytes) }
    }

    public static func inMemoryOnly(memoryLimit: Int = 50) -> ImageCache {
        ImageCache(diskDirectory: nil, memoryLimit: memoryLimit)
    }

    public func data(for key: PageKey) async -> Data? {
        if let cached = memory[key] {
            touchMemory(key)
            return cached
        }
        if let disk, let bytes = await disk.read(name: key.fileName) {
            putMemory(key, data: bytes)
            return bytes
        }
        return nil
    }

    public func store(_ data: Data, for key: PageKey) async {
        putMemory(key, data: data)
        if let disk {
            try? await disk.write(name: key.fileName, data: data)
        }
    }

    public func evictMemory() {
        memory.removeAll()
        memoryOrder.removeAll()
    }

    private func putMemory(_ key: PageKey, data: Data) {
        if memory[key] == nil {
            memoryOrder.append(key)
        } else {
            touchMemory(key)
        }
        memory[key] = data
        while memoryOrder.count > memoryLimit {
            let evicted = memoryOrder.removeFirst()
            memory.removeValue(forKey: evicted)
        }
    }

    private func touchMemory(_ key: PageKey) {
        if let idx = memoryOrder.firstIndex(of: key) {
            memoryOrder.remove(at: idx)
            memoryOrder.append(key)
        }
    }
}

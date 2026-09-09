import Foundation

public class MemoryStorageAdapter: IStorageAdapter {
    private var store: [String: String] = [:]

    public init() {}

    public func get(key: String) async throws -> String? {
        return store[key]
    }

    public func set(key: String, value: String) async throws {
        store[key] = value
    }

    public func remove(key: String) async throws {
        store.removeValue(forKey: key)
    }

    public func clear() {
        store.removeAll()
    }
}

public typealias MemoryStorage = MemoryStorageAdapter
public typealias LocalStorageAdapter = KeychainStorageAdapter

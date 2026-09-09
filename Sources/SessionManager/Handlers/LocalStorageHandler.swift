import Foundation

protocol KeyValueStore {
    func getItem(_ key: String) -> String?
    func setItem(_ key: String, _ value: String)
    func removeItem(_ key: String)
    func keys(withPrefix prefix: String) -> [String]
}

final class KeychainKeyValueStore: KeyValueStore {
    func getItem(_ key: String) -> String? {
        KeychainManager.shared.get(key: .custom(key))
    }

    func setItem(_ key: String, _ value: String) {
        KeychainManager.shared.save(key: .custom(key), val: value)
    }

    func removeItem(_ key: String) {
        KeychainManager.shared.delete(key: .custom(key))
    }

    func keys(withPrefix prefix: String) -> [String] {
        KeychainManager.shared.keys(withPrefix: prefix)
    }
}

final class MemoryKeyValueStore: KeyValueStore {
    private var items: [String: String] = [:]

    func getItem(_ key: String) -> String? {
        items[key]
    }

    func setItem(_ key: String, _ value: String) {
        items[key] = value
    }

    func removeItem(_ key: String) {
        items.removeValue(forKey: key)
    }

    func keys(withPrefix prefix: String) -> [String] {
        items.keys.filter { $0.hasPrefix(prefix) }
    }
}

public class LocalStorageHandler<T: Codable>: StorageHandler {
    public typealias SessionData = T

    private let store: KeyValueStore
    private let baseStorageKey: String

    public init(baseStorageKey: String) {
        self.baseStorageKey = baseStorageKey
        self.store = KeychainKeyValueStore()
    }

    init(baseStorageKey: String, store: KeyValueStore) {
        self.baseStorageKey = baseStorageKey
        self.store = store
    }

    public func storeData<U: Encodable>(key: Hex, data: U, options: StorageHandlerStoreOptions = StorageHandlerStoreOptions()) async throws {
        let storageKey = try getStorageKey(key: key)
        let encoded = try JSONEncoder().encode(data)
        guard let json = String(data: encoded, encoding: .utf8) else {
            throw StorageManagerError.stringEncodingError
        }
        store.setItem(storageKey, json)
    }

    public func retrieveData(key: Hex, options: StorageHandlerRetrieveOptions = StorageHandlerRetrieveOptions()) async throws -> T? {
        let storageKey = try getStorageKey(key: key)
        guard let localData = store.getItem(storageKey) else { return nil }
        guard let data = localData.data(using: .utf8) else {
            store.removeItem(storageKey)
            return nil
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            store.removeItem(storageKey)
            return nil
        }
    }

    public func clearStorage(key: Hex) throws {
        let storageKey = try getStorageKey(key: key)
        store.removeItem(storageKey)
    }

    public func clearOrphanedData(baseKey: String? = nil) throws {
        let keyPrefix = "\(baseStorageKey)\(baseKey ?? "")"
        store.keys(withPrefix: keyPrefix).forEach { store.removeItem($0) }
    }

    public func getStorageKey(key: Hex) throws -> String {
        return "\(baseStorageKey)\(remove0x(key))"
    }
}

import Foundation

public class KeychainStorageAdapter: IStorageAdapter {
    private let manager: KeychainManager

    public init(keyPrefix: String = "", accessGroup: String? = nil) {
        if keyPrefix.isEmpty && accessGroup == nil {
            self.manager = .shared
        } else {
            self.manager = KeychainManager(keyPrefix: keyPrefix, accessGroup: accessGroup)
        }
    }

    public func get(key: String) async throws -> String? {
        return manager.get(key: .custom(key))
    }

    public func set(key: String, value: String) async throws {
        manager.save(key: .custom(key), val: value)
    }

    public func remove(key: String) async throws {
        manager.delete(key: .custom(key))
    }
}

import KeychainSwift

public enum KeychainConstantEnum {
    case sessionID
    case custom(String)

    public var value: String {
        switch self {
        case .sessionID:
            return "sessionID"
        case let .custom(string):
            return string
        }
    }
}

protocol KeychainManagerProtocol {
    func get(key: KeychainConstantEnum) -> String?

    func delete(key: KeychainConstantEnum)

    func save(key: KeychainConstantEnum, val: String)
}

public class KeychainManager: KeychainManagerProtocol {
    private let keychain: KeychainSwift
    public static let shared = KeychainManager()
    public var getAllKeys: [String] {
        return keychain.allKeys
    }

    public init(keyPrefix: String = "", accessGroup: String? = nil) {
        if keyPrefix.isEmpty {
            keychain = KeychainSwift()
        } else {
            keychain = KeychainSwift(keyPrefix: keyPrefix)
        }
        keychain.accessGroup = accessGroup
    }

    public func get(key: KeychainConstantEnum) -> String? {
        return keychain.get(key.value)
    }

    public func delete(key: KeychainConstantEnum) {
        keychain.delete(key.value)
    }

    public func save(key: KeychainConstantEnum, val: String) {
        keychain.set(val, forKey: key.value)
    }

    public func keys(withPrefix prefix: String) -> [String] {
        return keychain.allKeys.filter { $0.hasPrefix(prefix) }
    }

    public func deleteKeys(withPrefix prefix: String) {
        keys(withPrefix: prefix).forEach { keychain.delete($0) }
    }
}

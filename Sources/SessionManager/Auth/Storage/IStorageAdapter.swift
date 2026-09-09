import Foundation

public protocol IStorageAdapter {
    func get(key: String) async throws -> String?
    func set(key: String, value: String) async throws
    func remove(key: String) async throws
}

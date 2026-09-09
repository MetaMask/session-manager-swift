import Foundation

public protocol StorageHandler {
    associatedtype SessionData: Codable

    func getStorageKey(key: Hex) throws -> String
    func storeData<U: Encodable>(key: Hex, data: U, options: StorageHandlerStoreOptions) async throws
    func retrieveData(key: Hex, options: StorageHandlerRetrieveOptions) async throws -> SessionData?
    func clearStorage(key: Hex) throws
    func clearOrphanedData(baseKey: String?) throws
}

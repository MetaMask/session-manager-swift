import Foundation

public protocol IStorageManager {
    associatedtype SessionData: Codable

    func createSession(data: SessionData) async throws -> String
    func authorizeSession() async throws -> SessionData
    func updateSession(data: SessionData) async throws
    func invalidateSession() async throws -> Bool
}

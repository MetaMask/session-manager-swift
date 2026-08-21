import Foundation
import curveSecp256k1

private let defaultSessionTimeout = 86400
private let maxSessionTimeout = 30 * 86400

public class StorageManager<T: Codable>: BaseStorageManager<T> {

    public let sessionServerBaseUrl: String
    public var sessionNamespace: String = ""
    public var allowedOrigin: String
    public let sessionTime: Int

    private var serverHandler: ServerHandler<T>!
    private let useLocalStorage: Bool
    private var localStorageHandler: LocalStorageHandler<T>?

    public var localStorageHandlerStorageKey: String? {
        guard let handler = getLocalStorageHandler() else { return nil }
        return try? handler.getStorageKey(key: sessionId)
    }

    public var serverHandlerStorageKey: String {
        return (try? serverHandler.getStorageKey(key: sessionId)) ?? ""
    }

    var baseLocalStorageKey: String {
        let namespace = sessionNamespace.isEmpty ? "w3a_session_manager_default" : sessionNamespace
        return "\(namespace):"
    }

    public init(
        sessionServerBaseUrl: String,
        sessionNamespace: String? = nil,
        sessionTime: Int = 86400,
        sessionId: Hex? = nil,
        allowedOrigin: String? = "*",
        useLocalStorage: Bool = false
    ) {
        self.sessionServerBaseUrl = sessionServerBaseUrl
        if let sessionNamespace = sessionNamespace {
            self.sessionNamespace = sessionNamespace
        }
        self.sessionTime = min(sessionTime, maxSessionTimeout)
        self.allowedOrigin = allowedOrigin ?? "*"
        self.useLocalStorage = useLocalStorage
        super.init()
        self.serverHandler = ServerHandler<T>(sessionServerBaseUrl: sessionServerBaseUrl) { [weak self] params in
            guard let self = self else { throw StorageManagerError.runtimeError("StorageManager deallocated") }
            return try await self.request(params)
        }
        if let sessionId = sessionId {
            try? setSessionId(sessionId: sessionId)
        }
    }

    public convenience init(options: StorageManagerOptions) {
        self.init(
            sessionServerBaseUrl: options.sessionServerBaseUrl,
            sessionNamespace: options.sessionNamespace,
            sessionTime: options.sessionTime ?? defaultSessionTimeout,
            sessionId: options.sessionId,
            allowedOrigin: options.allowedOrigin,
            useLocalStorage: options.useLocalStorage
        )
    }

    public static func generateRandomSessionKey() throws -> Hex {
        let key = try curveSecp256k1.SecretKey().serialize()
        return add0x(padHexString(key))
    }

    @available(*, deprecated, renamed: "generateRandomSessionKey()")
    public static func generateRandomSessionID() throws -> Hex {
        try generateRandomSessionKey()
    }

    public static func saveSessionIdToStorage(_ sessionId: String) {
        if !sessionId.isEmpty {
            KeychainManager.shared.save(key: .sessionID, val: sessionId)
        }
    }

    public static func getSessionIdFromStorage() -> String? {
        return KeychainManager.shared.get(key: .sessionID)
    }

    public static func deleteSessionIdFromStorage() {
        KeychainManager.shared.delete(key: .sessionID)
    }

    public func getSessionId() -> String {
        return sessionId
    }

    public override func setSessionId(sessionId: Hex) throws {
        _sessionId = try normalizeSessionId(sessionId)
    }

    public func createSession(data: T, headers: [String: String] = [:]) async throws -> String {
        try checkSessionParams()
        try await serverHandler.storeData(key: sessionId, data: data, options: StorageHandlerStoreOptions(
            headers: headers,
            namespace: sessionNamespace.isEmpty ? nil : sessionNamespace,
            timeout: sessionTime,
            allowedOrigin: allowedOrigin,
            operation: .create
        ))
        await safeLocalStorageOp { handler in
            try await handler.storeData(key: self.sessionId, data: data, options: StorageHandlerStoreOptions())
        }
        return sessionId
    }

    public override func createSession(data: T) async throws -> String {
        try await createSession(data: data, headers: [:])
    }

    public func authorizeSession(origin: String = "", headers: [String: String] = [:]) async throws -> T {
        try checkSessionParams()
        if let localData: T = await safeLocalStorageOp({ handler in
            try await handler.retrieveData(key: self.sessionId, options: StorageHandlerRetrieveOptions())
        }) {
            return localData
        }
        guard let response = try await serverHandler.retrieveData(
            key: sessionId,
            options: StorageHandlerRetrieveOptions(
                headers: headers,
                namespace: sessionNamespace.isEmpty ? nil : sessionNamespace,
                origin: origin
            )
        ) else {
            throw StorageManagerError.dataNotFound
        }
        await safeLocalStorageOp { handler in
            try await handler.storeData(key: self.sessionId, data: response, options: StorageHandlerStoreOptions())
        }
        return response
    }

    public override func authorizeSession() async throws -> T {
        try await authorizeSession(origin: "", headers: [:])
    }

    public func updateSession<U: Encodable>(data: U, headers: [String: String] = [:]) async throws {
        try checkSessionParams()
        try await serverHandler.storeData(key: sessionId, data: data, options: StorageHandlerStoreOptions(
            headers: headers,
            namespace: sessionNamespace.isEmpty ? nil : sessionNamespace,
            allowedOrigin: allowedOrigin,
            operation: .update
        ))
        await safeLocalStorageOp { handler in
            try await handler.storeData(key: self.sessionId, data: data, options: StorageHandlerStoreOptions())
        }
    }

    public override func updateSession(data: T) async throws {
        try await updateSession(data: data, headers: [:])
    }

    public func invalidateSession(headers: [String: String] = [:]) async throws -> Bool {
        try checkSessionParams()
        try await serverHandler.storeData(key: sessionId, data: EmptyEncodable(), options: StorageHandlerStoreOptions(
            headers: headers,
            namespace: sessionNamespace.isEmpty ? nil : sessionNamespace,
            operation: .invalidate
        ))
        try clearStorage()
        _sessionId = nil
        return true
    }

    public override func invalidateSession() async throws -> Bool {
        try await invalidateSession(headers: [:])
    }

    public func clearStorage() throws {
        try checkSessionParams()
        guard let handler = getLocalStorageHandler() else { return }
        try handler.clearStorage(key: sessionId)
    }

    public func clearOrphanedData(baseKey: String? = nil) throws {
        guard let handler = getLocalStorageHandler() else { return }
        try handler.clearOrphanedData(baseKey: baseKey)
    }

    public func encryptData(privkeyHex: String, _ dataToEncrypt: String) throws -> String {
        try CryptoHelpers.encryptData(privkeyHex: privkeyHex, dataToEncrypt)
    }

    public func decryptData(privKeyHex: String, d: String) throws -> [String: Any] {
        try CryptoHelpers.decryptData(privKeyHex: privKeyHex, d: d)
    }

    @discardableResult
    private func safeLocalStorageOp<R>(_ fn: (LocalStorageHandler<T>) async throws -> R?) async -> R? {
        do {
            guard let handler = getLocalStorageHandler() else { return nil }
            return try await fn(handler)
        } catch {
            return nil
        }
    }

    private func getLocalStorageHandler() -> LocalStorageHandler<T>? {
        guard useLocalStorage else { return nil }
        if let localStorageHandler = localStorageHandler {
            return localStorageHandler
        }
        let handler = LocalStorageHandler<T>(baseStorageKey: baseLocalStorageKey)
        localStorageHandler = handler
        return handler
    }
}

@available(*, deprecated, renamed: "StorageManager")
public typealias SessionManager<T: Codable> = StorageManager<T>

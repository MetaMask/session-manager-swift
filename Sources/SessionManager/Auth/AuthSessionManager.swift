import Foundation

private let defaultSessionsEndpoint = "/v1/auth/session"
private let defaultLogoutEndpoint = "/v1/auth/logout"

public class AuthSessionManager<T: Decodable>: IHttpSessionAuthProvider {
    public var accessTokenProvider: AccessTokenProvider?

    private var sessionData: String?
    private let storageKeyPrefix: String
    private let storage: ResolvedStorage
    private var accessToken: String?
    private var _sessionId: Hex?
    private let config: ApiClientConfig?
    private let urlSession: URLSession
    private let refreshCoordinator = RefreshCoordinator()

    private struct ResolvedStorage {
        let sessionId: IStorageAdapter
        let accessToken: IStorageAdapter
        let refreshToken: IStorageAdapter
        let idToken: IStorageAdapter
    }

    public init(options: AuthSessionManagerOptions = AuthSessionManagerOptions()) {
        self.accessTokenProvider = options.accessTokenProvider
        self.config = options.apiClientConfig
        self.storage = AuthSessionManager.resolveStorage(options.storage)
        self.storageKeyPrefix = options.storageKeyPrefix
        self.urlSession = options.urlSession
    }

    public convenience init(
        apiClientConfig: ApiClientConfig,
        storage: StorageConfig? = nil,
        storageKeyPrefix: String = "w3a",
        accessTokenProvider: AccessTokenProvider? = nil
    ) {
        self.init(options: AuthSessionManagerOptions(
            apiClientConfig: apiClientConfig,
            storage: storage,
            storageKeyPrefix: storageKeyPrefix,
            accessTokenProvider: accessTokenProvider
        ))
    }

    private var sessionIdKey: String { "\(storageKeyPrefix):\(STORAGE_KEYS.SESSION_ID)" }
    private var accessTokenKey: String { "\(storageKeyPrefix):\(STORAGE_KEYS.ACCESS_TOKEN)" }
    private var refreshTokenKey: String { "\(storageKeyPrefix):\(STORAGE_KEYS.REFRESH_TOKEN)" }
    private var idTokenKey: String { "\(storageKeyPrefix):\(STORAGE_KEYS.ID_TOKEN)" }

    public func getAccessToken() async throws -> String? {
        if let accessTokenProvider = accessTokenProvider {
            return try await accessTokenProvider()
        }
        return try await getStoredAccessToken()
    }

    public func getRefreshToken() async throws -> String? {
        try await storage.refreshToken.get(key: refreshTokenKey)
    }

    public func getIdToken() async throws -> String? {
        try await storage.idToken.get(key: idTokenKey)
    }

    public func getSessionId() async throws -> String? {
        if let _sessionId = _sessionId { return _sessionId }
        return try await storage.sessionId.get(key: sessionIdKey)
    }

    public func setTokens(_ tokens: AuthTokens) async throws {
        if let sessionId = tokens.sessionId {
            _sessionId = try normalizeSessionId(sessionId)
        }
        if let accessToken = tokens.accessToken {
            self.accessToken = accessToken
        }
        if let sessionId = _sessionId, tokens.sessionId != nil {
            try await storage.sessionId.set(key: sessionIdKey, value: sessionId)
        }
        if let accessToken = tokens.accessToken {
            try await storage.accessToken.set(key: accessTokenKey, value: accessToken)
        }
        if let refreshToken = tokens.refreshToken {
            try await storage.refreshToken.set(key: refreshTokenKey, value: refreshToken)
        }
        if let idToken = tokens.idToken {
            try await storage.idToken.set(key: idTokenKey, value: idToken)
        }
    }

    public func setAccessToken(_ token: String) async throws {
        accessToken = token
        try await storage.accessToken.set(key: accessTokenKey, value: token)
    }

    public func setRefreshToken(_ token: String) async throws {
        try await storage.refreshToken.set(key: refreshTokenKey, value: token)
    }

    public func isAuthenticated() -> Bool {
        return sessionData != nil
    }

    public func clearSessionData() async throws {
        accessToken = nil
        _sessionId = nil
        sessionData = nil
        try await storage.sessionId.remove(key: sessionIdKey)
        try await storage.accessToken.remove(key: accessTokenKey)
        try await storage.refreshToken.remove(key: refreshTokenKey)
        try await storage.idToken.remove(key: idTokenKey)
    }

    public func getState() async throws -> SessionState {
        SessionState(isAuthenticated: isAuthenticated(), sessionId: try await getSessionId())
    }

    public func authorize() async throws -> T? {
        _ = try requireConfig()
        let sessionId = try await getSessionId()
        let accessToken = try await getAccessToken()
        let refreshToken = try await getRefreshToken()
        if let sessionId = sessionId, accessToken != nil || refreshToken != nil {
            do {
                let response = try await ensureRefresh(skipIfFresh: false)
                sessionData = response.session_data
                return try decryptSessionData(sessionIdHex: sessionId, data: response.session_data)
            } catch {
                try await clearSessionData()
            }
        }
        return nil
    }

    public func ensureRefresh(skipIfFresh: Bool = false) async throws -> RefreshResponse {
        _ = try requireConfig()
        return try await refreshCoordinator.ensureRefresh(
            skipIfFresh: skipIfFresh,
            resolveFresh: { [weak self] in
                guard let self = self else { return nil }
                return try await self.tryResolveFreshFromStorage()
            },
            perform: { [weak self] in
                guard let self = self else {
                    throw AuthError(message: "AuthSessionManager deallocated", code: .invalid)
                }
                return try await self.performRefresh()
            }
        )
    }

    public func handleUnauthorized() async throws -> String {
        let response = try await ensureRefresh(skipIfFresh: true)
        return response.access_token
    }

    public func logout() async throws {
        let cfg = try requireConfig()
        let endpoint = joinURL(cfg.baseURL, cfg.logoutEndpoint.isEmpty ? defaultLogoutEndpoint : cfg.logoutEndpoint)
        do {
            let accessToken = try await getAccessToken()
            let refreshToken = try await getRefreshToken()
            var headers = ["Content-Type": "application/json"]
            if let accessToken = accessToken {
                headers["Authorization"] = "Bearer \(accessToken)"
            }
            let body = RefreshRequestBody(refresh_token: refreshToken)
            _ = try await send(url: endpoint, method: "POST", headers: headers, body: body)
        } catch {
            // Always clear local session data, even when the network call fails.
        }
        try await clearSessionData()
    }

    private func getStoredAccessToken() async throws -> String? {
        if let accessToken = accessToken { return accessToken }
        return try await storage.accessToken.get(key: accessTokenKey)
    }

    private static func resolveStorage(_ storageConfig: StorageConfig?) -> ResolvedStorage {
        let keychain = KeychainStorageAdapter()
        // Cookie analog: isolate refresh tokens in a separate Keychain prefix/access group.
        let refreshKeychain = KeychainStorageAdapter(keyPrefix: "w3a.refresh.")
        return ResolvedStorage(
            sessionId: storageConfig?.sessionId ?? keychain,
            accessToken: storageConfig?.accessToken ?? keychain,
            refreshToken: storageConfig?.refreshToken ?? refreshKeychain,
            idToken: storageConfig?.idToken ?? keychain
        )
    }

    private func requireConfig() throws -> ApiClientConfig {
        guard let config = config else {
            throw AuthError(message: "apiClientConfig is required for API operations", code: .invalid)
        }
        return config
    }

    private func tryResolveFreshFromStorage() async throws -> RefreshResponse? {
        let storedAccessToken = try await storage.accessToken.get(key: accessTokenKey)
        if let storedAccessToken = storedAccessToken, storedAccessToken != accessToken {
            accessToken = storedAccessToken
            return RefreshResponse(
                access_token: storedAccessToken,
                refresh_token: try await getRefreshToken() ?? "",
                session_data: sessionData ?? ""
            )
        }
        return nil
    }

    private func performRefresh() async throws -> RefreshResponse {
        let cfg = try requireConfig()
        let accessToken = try await getAccessToken()
        let refreshToken = try await getRefreshToken()
        if accessToken == nil && refreshToken == nil {
            throw AuthError(message: "No access token or refresh token available", code: .expired)
        }
        let endpoint = joinURL(cfg.baseURL, cfg.sessionsEndpoint.isEmpty ? defaultSessionsEndpoint : cfg.sessionsEndpoint)
        var headers = ["Content-Type": "application/json"]
        if let accessToken = accessToken {
            headers["Authorization"] = "Bearer \(accessToken)"
        }
        do {
            let data = try await send(url: endpoint, method: "POST", headers: headers, body: RefreshRequestBody(refresh_token: refreshToken))
            let response = try JSONDecoder().decode(RefreshResponse.self, from: data)
            if !response.access_token.isEmpty {
                try await setAccessToken(response.access_token)
            }
            if !response.refresh_token.isEmpty {
                try await setRefreshToken(response.refresh_token)
            }
            return response
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError(message: "Token refresh failed", code: .refreshFailed)
        }
    }

    private func decryptSessionData(sessionIdHex: String, data: String) throws -> T {
        do {
            return try CryptoHelpers.decryptData(privKeyHex: sessionIdHex, d: data)
        } catch {
            throw AuthError(message: "There was an error decrypting data.", code: .decryptFailed)
        }
    }

    private func send<U: Encodable>(url: String, method: String, headers: [String: String], body: U) async throws -> Data {
        guard let requestURL = URL(string: url) else {
            throw AuthError(message: "Invalid URL", code: .network)
        }
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        request.httpBody = try JSONEncoder().encode(body)
        if let timeout = config?.timeout {
            request.timeoutInterval = timeout
        }
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AuthError(message: "Invalid response", code: .network)
        }
        guard (200...299).contains(http.statusCode) else {
            throw HTTPStatusError(statusCode: http.statusCode, data: data)
        }
        return data
    }
}

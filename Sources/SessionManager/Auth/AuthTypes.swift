import Foundation

public struct AuthTokens: Codable {
    public var sessionId: Hex?
    public var accessToken: String?
    public var refreshToken: String?
    public var idToken: String?

    public init(sessionId: Hex? = nil, accessToken: String? = nil, refreshToken: String? = nil, idToken: String? = nil) {
        self.sessionId = sessionId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
    }
}

public struct RefreshResponse: Codable {
    public let access_token: String
    public let refresh_token: String
    public let session_data: String

    public init(access_token: String, refresh_token: String, session_data: String) {
        self.access_token = access_token
        self.refresh_token = refresh_token
        self.session_data = session_data
    }
}

public struct SessionState {
    public let isAuthenticated: Bool
    public let sessionId: String?

    public init(isAuthenticated: Bool, sessionId: String?) {
        self.isAuthenticated = isAuthenticated
        self.sessionId = sessionId
    }
}

public typealias AccessTokenProvider = () async throws -> String

public struct ApiClientConfig {
    public let baseURL: String
    public var timeout: TimeInterval?
    public var sessionsEndpoint: String
    public var logoutEndpoint: String

    public init(
        baseURL: String,
        timeout: TimeInterval? = nil,
        sessionsEndpoint: String = "/v1/auth/session",
        logoutEndpoint: String = "/v1/auth/logout"
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.sessionsEndpoint = sessionsEndpoint
        self.logoutEndpoint = logoutEndpoint
    }
}

public struct StorageConfig {
    public var sessionId: IStorageAdapter?
    public var accessToken: IStorageAdapter?
    public var refreshToken: IStorageAdapter?
    public var idToken: IStorageAdapter?

    public init(
        sessionId: IStorageAdapter? = nil,
        accessToken: IStorageAdapter? = nil,
        refreshToken: IStorageAdapter? = nil,
        idToken: IStorageAdapter? = nil
    ) {
        self.sessionId = sessionId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
    }
}

public struct AuthSessionManagerOptions {
    public var apiClientConfig: ApiClientConfig?
    public var storage: StorageConfig?
    public var storageKeyPrefix: String
    public var accessTokenProvider: AccessTokenProvider?
    public var urlSession: URLSession

    public init(
        apiClientConfig: ApiClientConfig? = nil,
        storage: StorageConfig? = nil,
        storageKeyPrefix: String = "w3a",
        accessTokenProvider: AccessTokenProvider? = nil,
        urlSession: URLSession = .shared
    ) {
        self.apiClientConfig = apiClientConfig
        self.storage = storage
        self.storageKeyPrefix = storageKeyPrefix
        self.accessTokenProvider = accessTokenProvider
        self.urlSession = urlSession
    }
}

public protocol IHttpSessionAuthProvider {
    func getAccessToken() async throws -> String?
    func handleUnauthorized() async throws -> String
}

public struct HttpClientRequestOptions {
    public var headers: [String: String]
    public var authenticated: Bool
    public var timeout: TimeInterval?

    public init(headers: [String: String] = [:], authenticated: Bool = false, timeout: TimeInterval? = nil) {
        self.headers = headers
        self.authenticated = authenticated
        self.timeout = timeout
    }
}

public struct STORAGE_KEYS {
    public static let SESSION_ID = "session_id"
    public static let ACCESS_TOKEN = "access_token"
    public static let REFRESH_TOKEN = "refresh_token"
    public static let ID_TOKEN = "id_token"
}

public struct EmptyResponse: Decodable {
    public init() {}
}

struct RefreshRequestBody: Encodable {
    let refresh_token: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(refresh_token, forKey: .refresh_token)
    }

    enum CodingKeys: String, CodingKey {
        case refresh_token
    }
}

struct HTTPStatusError: Error {
    let statusCode: Int
    let data: Data
}

import Foundation

public typealias Hex = String

public let SESSION_SERVER_API_URL = "https://api.web3auth.io/session-service"

public enum StorageOperation {
    case create
    case update
    case invalidate
}

public struct StorageManagerOptions {
    public let sessionServerBaseUrl: String
    public var sessionNamespace: String?
    public var sessionTime: Int?
    public var sessionId: Hex?
    public var allowedOrigin: String?
    public var useLocalStorage: Bool

    public init(
        sessionServerBaseUrl: String,
        sessionNamespace: String? = nil,
        sessionTime: Int? = nil,
        sessionId: Hex? = nil,
        allowedOrigin: String? = nil,
        useLocalStorage: Bool = false
    ) {
        self.sessionServerBaseUrl = sessionServerBaseUrl
        self.sessionNamespace = sessionNamespace
        self.sessionTime = sessionTime
        self.sessionId = sessionId
        self.allowedOrigin = allowedOrigin
        self.useLocalStorage = useLocalStorage
    }
}

public struct StorageHandlerStoreOptions {
    public var headers: [String: String]
    public var namespace: String?
    public var timeout: Int?
    public var allowedOrigin: String?
    public var operation: StorageOperation

    public init(
        headers: [String: String] = [:],
        namespace: String? = nil,
        timeout: Int? = nil,
        allowedOrigin: String? = nil,
        operation: StorageOperation = .create
    ) {
        self.headers = headers
        self.namespace = namespace
        self.timeout = timeout
        self.allowedOrigin = allowedOrigin
        self.operation = operation
    }
}

public struct StorageHandlerRetrieveOptions {
    public var headers: [String: String]
    public var namespace: String?
    public var origin: String?

    public init(headers: [String: String] = [:], namespace: String? = nil, origin: String? = nil) {
        self.headers = headers
        self.namespace = namespace
        self.origin = origin
    }
}

public struct ApiRequestParams {
    public var url: String
    public var method: String
    public var headers: [String: String]
    public var body: Data?

    public init(url: String, method: String = "GET", headers: [String: String] = [:], body: Data? = nil) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

struct SessionApiResponse: Codable {
    let message: String?
}

struct EmptyEncodable: Encodable {}

import Foundation

open class BaseStorageManager<T: Codable>: IStorageManager {
    public typealias SessionData = T

    var _sessionId: Hex?

    public var sessionId: Hex {
        return _sessionId ?? ""
    }

    public init() {}

    public func checkSessionParams() throws {
        guard let current = _sessionId, !current.isEmpty else {
            throw StorageManagerError.sessionIdAbsent
        }
        _sessionId = add0x(padHexString(current))
    }

    open func setSessionId(sessionId: Hex) throws {
        _sessionId = try normalizeSessionId(sessionId)
    }

    open func createSession(data: T) async throws -> String {
        fatalError("createSession(data:) must be overridden")
    }

    open func authorizeSession() async throws -> T {
        fatalError("authorizeSession() must be overridden")
    }

    open func updateSession(data: T) async throws {
        fatalError("updateSession(data:) must be overridden")
    }

    open func invalidateSession() async throws -> Bool {
        fatalError("invalidateSession() must be overridden")
    }

    func request(_ params: ApiRequestParams) async throws -> Data {
        guard let url = URL(string: params.url) else {
            throw StorageManagerError.invalidURL
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = params.method
        urlRequest.allHTTPHeaderFields = params.headers
        urlRequest.httpBody = params.body
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NetworkingError.invalidResponse
        }
        return data
    }
}

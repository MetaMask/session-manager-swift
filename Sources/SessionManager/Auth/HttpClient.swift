import Foundation

public class HttpClient {
    private let authSessionProvider: IHttpSessionAuthProvider
    private let urlSession: URLSession
    private let refreshCoordinator = HttpRefreshCoordinator()

    public init(authSessionProvider: IHttpSessionAuthProvider, urlSession: URLSession = .shared) {
        self.authSessionProvider = authSessionProvider
        self.urlSession = urlSession
    }

    public func get<T: Decodable>(_ url: String, options: HttpClientRequestOptions = HttpClientRequestOptions()) async throws -> T {
        return try await withAuth(options: options) { headers in
            try await self.send(url: url, method: "GET", headers: headers, body: Optional<EmptyEncodable>.none, timeout: options.timeout)
        }
    }

    public func post<T: Decodable, U: Encodable>(_ url: String, data: U, options: HttpClientRequestOptions = HttpClientRequestOptions()) async throws -> T {
        return try await withAuth(options: options) { headers in
            try await self.send(url: url, method: "POST", headers: headers, body: data, timeout: options.timeout)
        }
    }

    public func post<T: Decodable>(_ url: String, options: HttpClientRequestOptions = HttpClientRequestOptions()) async throws -> T {
        return try await post(url, data: EmptyEncodable(), options: options)
    }

    public func put<T: Decodable, U: Encodable>(_ url: String, data: U, options: HttpClientRequestOptions = HttpClientRequestOptions()) async throws -> T {
        return try await withAuth(options: options) { headers in
            try await self.send(url: url, method: "PUT", headers: headers, body: data, timeout: options.timeout)
        }
    }

    public func patch<T: Decodable, U: Encodable>(_ url: String, data: U, options: HttpClientRequestOptions = HttpClientRequestOptions()) async throws -> T {
        return try await withAuth(options: options) { headers in
            try await self.send(url: url, method: "PATCH", headers: headers, body: data, timeout: options.timeout)
        }
    }

    public func delete<T: Decodable, U: Encodable>(_ url: String, data: U, options: HttpClientRequestOptions = HttpClientRequestOptions()) async throws -> T {
        return try await withAuth(options: options) { headers in
            try await self.send(url: url, method: "DELETE", headers: headers, body: data, timeout: options.timeout)
        }
    }

    public func delete<T: Decodable>(_ url: String, options: HttpClientRequestOptions = HttpClientRequestOptions()) async throws -> T {
        return try await delete(url, data: EmptyEncodable(), options: options)
    }

    private func withAuth<T: Decodable>(options: HttpClientRequestOptions, send: @escaping ([String: String]) async throws -> T) async throws -> T {
        if !options.authenticated {
            return try await send(try await buildHeaders(options: options))
        }
        if let inFlight = await refreshCoordinator.currentTask() {
            _ = try? await inFlight.value
        }
        var headers = try await buildHeaders(options: options)
        do {
            return try await send(headers)
        } catch let error as HTTPStatusError where error.statusCode == 401 {
            do {
                let newToken = try await enqueueRefresh()
                headers["Authorization"] = "Bearer \(newToken)"
                return try await send(headers)
            } catch {
                throw AuthError(message: "Session expired, please re-authenticate", code: .sessionExpired)
            }
        }
    }

    private func enqueueRefresh() async throws -> String {
        try await refreshCoordinator.run {
            try await self.authSessionProvider.handleUnauthorized()
        }
    }

    private func buildHeaders(options: HttpClientRequestOptions) async throws -> [String: String] {
        var headers = options.headers
        if options.authenticated {
            if let token = try await authSessionProvider.getAccessToken() {
                headers["Authorization"] = "Bearer \(token)"
            }
        }
        if headers["Content-Type"] == nil {
            headers["Content-Type"] = "application/json"
        }
        return headers
    }

    private func send<T: Decodable, U: Encodable>(url: String, method: String, headers: [String: String], body: U?, timeout: TimeInterval?) async throws -> T {
        guard let requestURL = URL(string: url) else {
            throw NetworkingError.invalidURL
        }
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        if let body = body, method != "GET" {
            request.httpBody = try JSONEncoder().encode(body)
        }
        if let timeout = timeout {
            request.timeoutInterval = timeout
        }
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NetworkingError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw HTTPStatusError(statusCode: http.statusCode, data: data)
        }
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

actor HttpRefreshCoordinator {
    private var refreshTask: Task<String, Error>?

    func currentTask() -> Task<String, Error>? {
        refreshTask
    }

    func run(_ operation: @escaping () async throws -> String) async throws -> String {
        if let refreshTask = refreshTask {
            return try await refreshTask.value
        }
        let task = Task<String, Error> {
            try await operation()
        }
        refreshTask = task
        do {
            let result = try await task.value
            refreshTask = nil
            return result
        } catch {
            refreshTask = nil
            throw error
        }
    }
}

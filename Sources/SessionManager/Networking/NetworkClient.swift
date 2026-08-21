import Foundation

enum Router: NetworkManagerProtocol {
    case get([URLQueryItem])
    case set(T: Encodable)
    case update(T: Encodable)
    case authorizeSession(T: Encodable, origin: String)

    var path: String {
        switch self {
        case .get:
            return "v2/store/get"
        case .set:
            return "v2/store/set"
        case .update:
            return "v2/store/update"
        case .authorizeSession:
            return "v2/store/get"
        }
    }

    var httpMethod: HTTPMethod {
        switch self {
        case let .get(params):
            return .get(params)
        case let .set(params):
            return .post(T: params)
        case let .update(params):
            return .put(T: params)
        case let .authorizeSession(params, _):
            return .post(T: params)
        }
    }

    var headers: [String: String] {
        switch self {
        case .get, .set, .update:
            return ["Content-Type": "application/json"]
        case let .authorizeSession(_, origin):
            return [
                "Content-Type": "application/json",
                "origin": origin
            ]
        }
    }
}

class Service {
    static func request(router: Router, baseURL: String, extraHeaders: [String: String] = [:]) async -> Result<Data, Error> {
        do {
            guard let url = URL(string: joinURL(baseURL, router.path)) else { throw NetworkingError.invalidURL }
            var request = URLRequest(url: url)
            request.httpMethod = router.httpMethod.name
            request.allHTTPHeaderFields = router.headers.merging(extraHeaders) { _, new in new }
            switch router.httpMethod {
            case let .get(params):
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.queryItems = params
                guard let url = components?.url else { throw NetworkingError.invalidURL }
                request = URLRequest(url: url)
                request.allHTTPHeaderFields = router.headers.merging(extraHeaders) { _, new in new }
            case let .post(data), let .put(data), let .patch(data), let .delete(data):
                request.httpBody = try JSONEncoder().encode(data)
            }
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode >= 200 && response.statusCode <= 299 else {
                throw NetworkingError.invalidResponse
            }
            return .success(data)
        } catch let error {
            return .failure(error)
        }
    }
}

@testable import SessionManager
import XCTest

private struct Echo: Codable, Equatable {
    let value: String
}

private final class MockAuthProvider: IHttpSessionAuthProvider {
    var token: String?
    var unauthorizedCalls = 0
    var onUnauthorized: (() async throws -> String)?

    func getAccessToken() async throws -> String? {
        token
    }

    func handleUnauthorized() async throws -> String {
        unauthorizedCalls += 1
        if let onUnauthorized = onUnauthorized {
            return try await onUnauthorized()
        }
        token = "refreshed"
        return "refreshed"
    }
}

final class HttpClientTest: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testUnauthenticatedPassthroughDoesNotAttachBearer() async throws {
        let provider = MockAuthProvider()
        provider.token = "secret"
        MockURLProtocol.handler = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            return (200, try JSONEncoder().encode(Echo(value: "ok")))
        }
        let client = HttpClient(authSessionProvider: provider, urlSession: MockURLProtocol.makeSession())
        let result: Echo = try await client.get("https://api.example/health")
        XCTAssertEqual(result, Echo(value: "ok"))
        XCTAssertEqual(provider.unauthorizedCalls, 0)
    }

    func testAuthenticatedRequestAttachesBearerAndRetriesOnceOn401() async throws {
        let provider = MockAuthProvider()
        provider.token = "old"
        var statuses = [401, 200]
        MockURLProtocol.handler = { request in
            let status = statuses.removeFirst()
            if status == 401 {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer old")
                return (401, Data())
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer refreshed")
            return (200, try JSONEncoder().encode(Echo(value: "done")))
        }
        let client = HttpClient(authSessionProvider: provider, urlSession: MockURLProtocol.makeSession())
        let result: Echo = try await client.get("https://api.example/me", options: HttpClientRequestOptions(authenticated: true))
        XCTAssertEqual(result, Echo(value: "done"))
        XCTAssertEqual(provider.unauthorizedCalls, 1)
    }

    func testConcurrent401TriggersSingleRefresh() async throws {
        let provider = MockAuthProvider()
        provider.token = "old"
        var unauthorizedStarted = 0
        provider.onUnauthorized = {
            unauthorizedStarted += 1
            try await Task.sleep(nanoseconds: 250_000_000)
            provider.token = "refreshed"
            return "refreshed"
        }
        MockURLProtocol.handler = { request in
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer old" {
                return (401, Data())
            }
            return (200, try JSONEncoder().encode(Echo(value: "ok")))
        }
        let client = HttpClient(authSessionProvider: provider, urlSession: MockURLProtocol.makeSession())
        async let first: Echo = client.get("https://api.example/a", options: HttpClientRequestOptions(authenticated: true))
        async let second: Echo = client.get("https://api.example/b", options: HttpClientRequestOptions(authenticated: true))
        let results = try await [first, second]
        XCTAssertEqual(results, [Echo(value: "ok"), Echo(value: "ok")])
        XCTAssertEqual(provider.unauthorizedCalls, 1)
        XCTAssertEqual(unauthorizedStarted, 1)
    }
}

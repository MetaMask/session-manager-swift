@testable import SessionManager
import XCTest

private struct DemoSession: Codable, Equatable {
    let userId: String
}

final class AuthSessionManagerTest: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testSetTokensAndGetters() async throws {
        let memory = MemoryStorageAdapter()
        let session = AuthSessionManager<DemoSession>(options: AuthSessionManagerOptions(
            storage: StorageConfig(sessionId: memory, accessToken: memory, refreshToken: memory, idToken: memory),
            storageKeyPrefix: "test"
        ))
        let sessionId = try StorageManager<DemoSession>.generateRandomSessionKey()
        try await session.setTokens(AuthTokens(
            sessionId: sessionId,
            accessToken: "access",
            refreshToken: "refresh",
            idToken: "id"
        ))
        let access = try await session.getAccessToken()
        let refresh = try await session.getRefreshToken()
        let idToken = try await session.getIdToken()
        let storedSessionId = try await session.getSessionId()
        XCTAssertEqual(access, "access")
        XCTAssertEqual(refresh, "refresh")
        XCTAssertEqual(idToken, "id")
        XCTAssertEqual(storedSessionId, add0x(padHexString(sessionId)))
        XCTAssertFalse(session.isAuthenticated())
        let state = try await session.getState()
        XCTAssertFalse(state.isAuthenticated)
        XCTAssertEqual(state.sessionId, storedSessionId)
    }

    func testAuthorizeDecryptsSessionData() async throws {
        let memory = MemoryStorageAdapter()
        let urlSession = MockURLProtocol.makeSession()
        let sessionId = try StorageManager<DemoSession>.generateRandomSessionKey()
        let encrypted = try CryptoHelpers.encryptEncodable(privkeyHex: sessionId, DemoSession(userId: "42"))
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/auth/session")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access")
            let payload = RefreshResponse(access_token: "new-access", refresh_token: "new-refresh", session_data: encrypted)
            return (200, try JSONEncoder().encode(payload))
        }
        let session = AuthSessionManager<DemoSession>(options: AuthSessionManagerOptions(
            apiClientConfig: ApiClientConfig(baseURL: "https://auth.example"),
            storage: StorageConfig(sessionId: memory, accessToken: memory, refreshToken: memory, idToken: memory),
            urlSession: urlSession
        ))
        try await session.setTokens(AuthTokens(sessionId: sessionId, accessToken: "access", refreshToken: "refresh"))
        let data = try await session.authorize()
        XCTAssertEqual(data, DemoSession(userId: "42"))
        XCTAssertTrue(session.isAuthenticated())
        let access = try await session.getAccessToken()
        let refresh = try await session.getRefreshToken()
        XCTAssertEqual(access, "new-access")
        XCTAssertEqual(refresh, "new-refresh")
    }

    func testLogoutClearsTokensOnNetworkError() async throws {
        let memory = MemoryStorageAdapter()
        let urlSession = MockURLProtocol.makeSession()
        MockURLProtocol.handler = { _ in
            (500, Data("fail".utf8))
        }
        let session = AuthSessionManager<DemoSession>(options: AuthSessionManagerOptions(
            apiClientConfig: ApiClientConfig(baseURL: "https://auth.example"),
            storage: StorageConfig(sessionId: memory, accessToken: memory, refreshToken: memory, idToken: memory),
            storageKeyPrefix: "w3a",
            urlSession: urlSession
        ))
        try await session.setTokens(AuthTokens(
            sessionId: try StorageManager<DemoSession>.generateRandomSessionKey(),
            accessToken: "access",
            refreshToken: "refresh",
            idToken: "id"
        ))
        try await session.logout()
        let access = try await session.getAccessToken()
        let refresh = try await session.getRefreshToken()
        let idToken = try await session.getIdToken()
        let sessionId = try await session.getSessionId()
        XCTAssertNil(access)
        XCTAssertNil(refresh)
        XCTAssertNil(idToken)
        XCTAssertNil(sessionId)
        XCTAssertFalse(session.isAuthenticated())
    }

    func testSkipIfFreshUsesStorageTokenWithoutNetwork() async throws {
        let memory = MemoryStorageAdapter()
        let urlSession = MockURLProtocol.makeSession()
        var networkCalls = 0
        MockURLProtocol.handler = { _ in
            networkCalls += 1
            return (200, try JSONEncoder().encode(RefreshResponse(access_token: "from-network", refresh_token: "r", session_data: "")))
        }
        let session = AuthSessionManager<DemoSession>(options: AuthSessionManagerOptions(
            apiClientConfig: ApiClientConfig(baseURL: "https://auth.example"),
            storage: StorageConfig(sessionId: memory, accessToken: memory, refreshToken: memory, idToken: memory),
            urlSession: urlSession
        ))
        try await session.setTokens(AuthTokens(accessToken: "memory-token", refreshToken: "refresh"))
        try await memory.set(key: "w3a:\(STORAGE_KEYS.ACCESS_TOKEN)", value: "storage-token")
        let response = try await session.ensureRefresh(skipIfFresh: true)
        XCTAssertEqual(response.access_token, "storage-token")
        XCTAssertEqual(networkCalls, 0)
        let access = try await session.getAccessToken()
        XCTAssertEqual(access, "storage-token")
    }

    func testRefreshDedupSharesInFlightRequest() async throws {
        let memory = MemoryStorageAdapter()
        let urlSession = MockURLProtocol.makeSession()
        var networkCalls = 0
        MockURLProtocol.handler = { _ in
            networkCalls += 1
            Thread.sleep(forTimeInterval: 0.25)
            return (200, try JSONEncoder().encode(RefreshResponse(access_token: "shared", refresh_token: "r", session_data: "s")))
        }
        let session = AuthSessionManager<DemoSession>(options: AuthSessionManagerOptions(
            apiClientConfig: ApiClientConfig(baseURL: "https://auth.example"),
            storage: StorageConfig(sessionId: memory, accessToken: memory, refreshToken: memory, idToken: memory),
            urlSession: urlSession
        ))
        try await session.setTokens(AuthTokens(accessToken: "access", refreshToken: "refresh"))
        async let first = session.ensureRefresh(skipIfFresh: false)
        async let second = session.ensureRefresh(skipIfFresh: false)
        let results = try await [first, second]
        XCTAssertEqual(results[0].access_token, "shared")
        XCTAssertEqual(results[1].access_token, "shared")
        XCTAssertEqual(networkCalls, 1)
    }
}

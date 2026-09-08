@testable import SessionManager
import XCTest
import curveSecp256k1

final class SessionManagementTest: XCTestCase {
    private let sessionServer = SESSION_SERVER_API_URL

    private func generatePrivateandPublicKey() throws -> (privKey: String, pubKey: String) {
        let privKeyData = curveSecp256k1.SecretKey()
        let publicKey = try privKeyData.toPublic()
        let serialized = try publicKey.serialize(compressed: false)
        return (privKey: try privKeyData.serialize(), pubKey: serialized)
    }

    private func makeSession(sessionTime: Int = 86400, sessionId: String? = nil, namespace: String? = "sfa", useLocalStorage: Bool = false) throws -> StorageManager<SFAModel> {
        let id = try sessionId ?? StorageManager<SFAModel>.generateRandomSessionKey()
        return try StorageManager<SFAModel>(
            sessionServerBaseUrl: sessionServer,
            sessionNamespace: namespace,
            sessionTime: sessionTime,
            sessionId: id,
            useLocalStorage: useLocalStorage
        )
    }

    func test_createSessionID() async throws {
        let session = try makeSession()
        let (privKey, pubKey) = try generatePrivateandPublicKey()
        let sfa = SFAModel(publicKey: pubKey, privateKey: privKey)
        let _ = try await session.createSession(data: sfa)
    }

    func test_authoriseSessionID() async throws {
        let session = try makeSession()
        let (privKey, pubKey) = try generatePrivateandPublicKey()
        let sfa = SFAModel(publicKey: pubKey, privateKey: privKey)
        let created = try await session.createSession(data: sfa)
        StorageManager<SFAModel>.saveSessionIdToStorage(created)
        XCTAssertFalse(created.isEmpty)
        let auth = try await session.authorizeSession()
        XCTAssertEqual(auth.privateKey, privKey)
        XCTAssertEqual(auth.publicKey, pubKey)
    }

    func testEncryptDecryptData() throws {
        let session = try StorageManager<SFAModel>(sessionServerBaseUrl: sessionServer)
        let privKey = "dda863b615ac6de27fb680b5563db3c19176a6f42cc1dee1768e220983385e3e"
        let dt = ["data": "data"]
        let dataToEncrypt = try JSONSerialization.data(withJSONObject: dt)
        let dataToEncryptStr = String(data: dataToEncrypt, encoding: .utf8)!
        let encryptdata = try session.encryptData(privkeyHex: privKey, dataToEncryptStr)
        let decrypted = try session.decryptData(privKeyHex: privKey, d: encryptdata)
        let decryptedToString = String(data: try JSONSerialization.data(withJSONObject: decrypted), encoding: .utf8)!
        XCTAssertEqual(dataToEncryptStr, decryptedToString)
    }

    func testSign() throws {
        let privKey = "bce6550a433b2e38067501222f9e75a2d4c5a433a6d27ec90cd81fbd4194cc2b"
        let encData = "test data"
        let hashData = try curveSecp256k1.keccak256(data: encData.data(using: .utf8)!)
        let secretKey = try curveSecp256k1.SecretKey(hex: privKey)
        let sig = try curveSecp256k1.ECDSA.signRecoverable(key: secretKey, hash: hashData.hexString).serialize()
        XCTAssertEqual(sig.suffix(130).prefix(64), "d7736799107d8e6308af995d827dc8772993cd8ccab5c230fe8277cecb02f31a")
        XCTAssertEqual(sig.suffix(66).prefix(64), "4df631a4059f45d8cb0e8889ff1b8096243796189ec00440883b1c0271a19e80")
    }

    func testEncryptAndSign() throws {
        let privKey = "dda863b615ac6de27fb680b5563db3c19176a6f42cc1dee1768e220983385e3e"
        let encdata = "{\"iv\":\"693407372626b11017d0ec30acd29e6a\",\"ciphertext\":\"cbe09442851a0463b3e34e2f912c6aee\",\"ephemPublicKey\":\"0477e20c5d9e3281a4eca7d07c1c4cc9765522ea7966cd7ea8f552da42049778d4fcf44b35b59e84eddb1fa3266350e4f2d69d62da82819d51f107550e03852661\",\"mac\":\"96d358f46ef371982af600829c101e78f6c5d5f960bd96fdd2ca52763ee50f65\"}"
        let hashData = try curveSecp256k1.keccak256(data: encdata.data(using: .utf8)!)
        let secretKey = try curveSecp256k1.SecretKey(hex: privKey)
        let sig = try curveSecp256k1.ECDSA.signRecoverable(key: secretKey, hash: hashData.hexString).serialize()
        XCTAssertEqual(sig.suffix(130).prefix(64), "b0161b8abbd66da28734d105e28455bf9a48a33ee1dfde71f96e2e9197175650")
        XCTAssertEqual(sig.suffix(66).prefix(64), "4d53303ec05596ca6784cff1d25eb0e764f70ff5e1ce16a896ec58255b25b5ff")
    }

    func test_invalidateSession() async throws {
        let session = try makeSession()
        let (privKey, pubKey) = try generatePrivateandPublicKey()
        let sfa = SFAModel(publicKey: pubKey, privateKey: privKey)
        let created = try await session.createSession(data: sfa)
        StorageManager<SFAModel>.saveSessionIdToStorage(created)
        let invalidated = try await session.invalidateSession()
        XCTAssertTrue(invalidated)
        XCTAssertTrue(session.getSessionId().isEmpty)
    }

    func test_updateSession() async throws {
        let session = try makeSession()
        let (privKey, pubKey) = try generatePrivateandPublicKey()
        let sfa = SFAModel(publicKey: pubKey, privateKey: privKey)
        _ = try await session.createSession(data: sfa)
        let updated = SFAModel(publicKey: pubKey, privateKey: privKey)
        try await session.updateSession(data: updated)
        let auth = try await session.authorizeSession()
        XCTAssertEqual(auth, updated)
    }

    func test_session_expired_error() async throws {
        var caughtCorrectError: Bool = false
        do {
            let session = try makeSession(sessionTime: 1, namespace: nil)
            let (privKey, pubKey) = try generatePrivateandPublicKey()
            let sfa = SFAModel(publicKey: pubKey, privateKey: privKey)
            _ = try await session.createSession(data: sfa)
            _ = try await session.authorizeSession()
            sleep(2)
            _ = try await session.authorizeSession()
        } catch StorageManagerError.dataNotFound {
            caughtCorrectError = true
        }
        XCTAssertTrue(caughtCorrectError)
    }

    func test_authorize_local_cache_hit() async throws {
        let namespace = "sfa-local-\(UUID().uuidString.prefix(8))"
        let sessionId = try StorageManager<SFAModel>.generateRandomSessionKey()
        let live = try makeSession(sessionId: sessionId, namespace: namespace, useLocalStorage: true)
        let (privKey, pubKey) = try generatePrivateandPublicKey()
        let sfa = SFAModel(publicKey: pubKey, privateKey: privKey)
        _ = try await live.createSession(data: sfa)

        let cached = try StorageManager<SFAModel>(
            sessionServerBaseUrl: "https://invalid.example.invalid",
            sessionNamespace: namespace,
            sessionId: sessionId,
            useLocalStorage: true
        )
        let auth = try await cached.authorizeSession()
        XCTAssertEqual(auth, sfa)
        try cached.clearStorage()
    }

    func test_authorize_local_cache_miss_without_server_fails() async throws {
        let session = try StorageManager<SFAModel>(
            sessionServerBaseUrl: "https://invalid.example.invalid",
            sessionNamespace: "sfa-miss",
            sessionId: try StorageManager<SFAModel>.generateRandomSessionKey(),
            useLocalStorage: true
        )
        do {
            _ = try await session.authorizeSession()
            XCTFail("Expected server fallback to fail when local cache misses")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func test_authorize_corrupted_cache_falls_back_to_server() async throws {
        let namespace = "sfa-corrupt-\(UUID().uuidString.prefix(8))"
        let sessionId = try StorageManager<SFAModel>.generateRandomSessionKey()
        let session = try makeSession(sessionId: sessionId, namespace: namespace, useLocalStorage: true)
        let (privKey, pubKey) = try generatePrivateandPublicKey()
        let sfa = SFAModel(publicKey: pubKey, privateKey: privKey)
        _ = try await session.createSession(data: sfa)
        let cacheKey = try XCTUnwrap(session.localStorageHandlerStorageKey)
        KeychainManager.shared.save(key: .custom(cacheKey), val: "{not-json")
        let auth = try await session.authorizeSession()
        XCTAssertEqual(auth, sfa)
        try session.clearStorage()
    }

    func test_invalidate_clears_local_cache_and_session_id() async throws {
        let namespace = "sfa-invalidate-\(UUID().uuidString.prefix(8))"
        let session = try makeSession(namespace: namespace, useLocalStorage: true)
        let (privKey, pubKey) = try generatePrivateandPublicKey()
        let sfa = SFAModel(publicKey: pubKey, privateKey: privKey)
        _ = try await session.createSession(data: sfa)
        let cacheKey = try XCTUnwrap(session.localStorageHandlerStorageKey)
        XCTAssertNotNil(KeychainManager.shared.get(key: .custom(cacheKey)))
        _ = try await session.invalidateSession()
        XCTAssertTrue(session.getSessionId().isEmpty)
        XCTAssertNil(KeychainManager.shared.get(key: .custom(cacheKey)))
    }
}

@testable import SessionManager
import XCTest
import curveSecp256k1

struct SFAModel: Codable {
    let publicKey: String
    let privateKey: String
}

final class SessionManagementTest: XCTestCase {
    private func generatePrivateandPublicKey() throws -> (privKey: String, pubKey: String) {
        let privKeyData = curveSecp256k1.SecretKey()
        let publicKey = try privKeyData.toPublic()
        let serialized = try publicKey.serialize(compressed: false)
        return (privKey: try privKeyData.serialize(), pubKey: serialized)
    }

    func test_createSessionID() async throws {
        let sessionId = try SessionManager.generateRandomSessionID();
        let session = SessionManager(sessionId: sessionId, sessionNamespace: "sfa")
        let (privKey, pubKey) = try generatePrivateandPublicKey()
        let sfa = SFAModel(publicKey: pubKey, privateKey: privKey)
        let _ = try await session.createSession(data: sfa)
    }

    func test_authoriseSessionID() async throws {
        let sessionId = try SessionManager.generateRandomSessionID();
        let session = SessionManager(sessionId: sessionId, sessionNamespace: "sfa")
        let (privKey, pubKey) = try generatePrivateandPublicKey()
        let sfa = SFAModel(publicKey: pubKey, privateKey: privKey)
        let created = try await session.createSession(data: sfa)
        SessionManager.saveSessionIdToStorage(created)
        XCTAssertFalse(created.isEmpty)
        let auth = try await session.authorizeSession(origin: "") //Pass refirectUrl as origin
        XCTAssertTrue(auth.keys.contains("privateKey"))
        XCTAssertTrue(auth.keys.contains("publicKey"))
    }

    func testEncryptDecryptData() throws {
        let session = SessionManager()
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
        let sessionId = try SessionManager.generateRandomSessionID();
        let session = SessionManager(sessionId: sessionId, sessionNamespace: "sfa")
        let (privKey, pubKey) = try generatePrivateandPublicKey()
        let sfa = SFAModel(publicKey: pubKey, privateKey: privKey)
        let created = try await session.createSession(data: sfa)
        SessionManager.saveSessionIdToStorage(created)
        try await session.invalidateSession()
    }
    
    func test_session_expired_error() async throws {
        var caughtCorrectError: Bool = false;
        do {
            let sessionId = try SessionManager.generateRandomSessionID();
            let session = SessionManager(sessionTime: 1, sessionId: sessionId)
            let (privKey, pubKey) = try generatePrivateandPublicKey()
            let sfa = SFAModel(publicKey: pubKey, privateKey: privKey)
            let created = try await session.createSession(data: sfa)
            let _ = try await session.authorizeSession(origin: "origin")
            sleep(2)
            let _ = try await session.authorizeSession(origin: "origin")
        } catch SessionManagerError.dataNotFound {
            caughtCorrectError = true
        }
        XCTAssertTrue(caughtCorrectError)
    }
}

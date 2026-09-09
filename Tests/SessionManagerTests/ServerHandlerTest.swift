@testable import SessionManager
import XCTest

final class ServerHandlerTest: XCTestCase {
    func testStoreDataCreateUsesPostSetAndSignsPayload() async throws {
        let captured = RequestCapture()
        let handler = ServerHandler<SFAModel>(sessionServerBaseUrl: "https://session.example") { params in
            captured.params = params
            return Data("{}".utf8)
        }
        let key = try StorageManager<SFAModel>.generateRandomSessionKey()
        let model = SFAModel(publicKey: "pub", privateKey: "priv")
        try await handler.storeData(key: key, data: model, options: StorageHandlerStoreOptions(
            namespace: "sfa",
            timeout: 60,
            allowedOrigin: "*",
            operation: .create
        ))
        XCTAssertEqual(captured.params?.method, "POST")
        XCTAssertEqual(captured.params?.url, "https://session.example/v2/store/set")
        let body = try XCTUnwrap(decodedBody(captured.params?.body))
        XCTAssertEqual(body.timeout, 60)
        XCTAssertEqual(body.namespace, "sfa")
        XCTAssertEqual(body.allowedOrigin, "*")
        XCTAssertFalse(body.data.isEmpty)
        XCTAssertTrue(body.signature.contains("\"r\""))
        XCTAssertTrue(body.signature.contains("\"s\""))
        XCTAssertTrue(body.key.hasPrefix("04"))
        XCTAssertEqual(body.key.count, 130)
    }

    func testStoreDataUpdateUsesPutUpdate() async throws {
        let captured = RequestCapture()
        let handler = ServerHandler<SFAModel>(sessionServerBaseUrl: "https://session.example/") { params in
            captured.params = params
            return Data("{}".utf8)
        }
        let key = try StorageManager<SFAModel>.generateRandomSessionKey()
        try await handler.storeData(key: key, data: SFAModel(publicKey: "pub", privateKey: "priv"), options: StorageHandlerStoreOptions(operation: .update))
        XCTAssertEqual(captured.params?.method, "PUT")
        XCTAssertEqual(captured.params?.url, "https://session.example/v2/store/update")
        let body = try XCTUnwrap(decodedBody(captured.params?.body))
        XCTAssertNil(body.timeout)
    }

    func testInvalidateUsesTimeoutOne() async throws {
        let captured = RequestCapture()
        let handler = ServerHandler<SFAModel>(sessionServerBaseUrl: "https://session.example") { params in
            captured.params = params
            return Data("{}".utf8)
        }
        let key = try StorageManager<SFAModel>.generateRandomSessionKey()
        try await handler.storeData(key: key, data: EmptyEncodable(), options: StorageHandlerStoreOptions(operation: .invalidate))
        XCTAssertEqual(captured.params?.method, "POST")
        XCTAssertEqual(captured.params?.url, "https://session.example/v2/store/set")
        let body = try XCTUnwrap(decodedBody(captured.params?.body))
        XCTAssertEqual(body.timeout, 1)
    }

    func testGetStorageKeyIsUncompressedPublicKey() throws {
        let handler = ServerHandler<SFAModel>(sessionServerBaseUrl: "https://session.example") { _ in Data() }
        let key = "dda863b615ac6de27fb680b5563db3c19176a6f42cc1dee1768e220983385e3e"
        let pub = try handler.getStorageKey(key: key)
        XCTAssertTrue(pub.hasPrefix("04"))
        XCTAssertEqual(pub.count, 130)
        XCTAssertEqual(try handler.getStorageKey(key: "0x" + key), pub)
    }

    func testEncryptDecryptRoundTrip() throws {
        let privKey = "dda863b615ac6de27fb680b5563db3c19176a6f42cc1dee1768e220983385e3e"
        let encrypted = try CryptoHelpers.encryptEncodable(privkeyHex: privKey, SFAModel(publicKey: "pub", privateKey: "priv"))
        let decrypted: SFAModel = try CryptoHelpers.decryptData(privKeyHex: privKey, d: encrypted)
        XCTAssertEqual(decrypted.publicKey, "pub")
        XCTAssertEqual(decrypted.privateKey, "priv")
    }

    private func decodedBody(_ data: Data?) throws -> SessionRequestBodyDecoded {
        let data = try XCTUnwrap(data)
        return try JSONDecoder().decode(SessionRequestBodyDecoded.self, from: data)
    }
}

private final class RequestCapture {
    var params: ApiRequestParams?
}

private struct SessionRequestBodyDecoded: Decodable {
    let key: String
    let data: String
    let signature: String
    let timeout: Int?
    let allowedOrigin: String?
    let namespace: String?
}

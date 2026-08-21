@testable import SessionManager
import XCTest

final class StorageManagerTest: XCTestCase {
    func testGenerateRandomSessionKeyHasPrefixedHex() throws {
        let key = try StorageManager<SFAModel>.generateRandomSessionKey()
        XCTAssertTrue(key.hasPrefix("0x"))
        XCTAssertEqual(remove0x(key).count, 64)
        XCTAssertTrue(isHexString(key))
    }

    func testSetSessionIdPadsAndPrefixes() throws {
        let session = StorageManager<SFAModel>(sessionServerBaseUrl: SESSION_SERVER_API_URL)
        try session.setSessionId(sessionId: "abc")
        XCTAssertEqual(session.sessionId, "0x" + String(repeating: "0", count: 61) + "abc")
    }

    func testSetSessionIdRejectsNonHex() {
        let session = StorageManager<SFAModel>(sessionServerBaseUrl: SESSION_SERVER_API_URL)
        XCTAssertThrowsError(try session.setSessionId(sessionId: "not-hex")) { error in
            XCTAssertEqual(error as? StorageManagerError, StorageManagerError.invalidSessionId)
        }
    }

    func testCheckSessionParamsThrowsWhenMissing() {
        let session = StorageManager<SFAModel>(sessionServerBaseUrl: SESSION_SERVER_API_URL)
        XCTAssertThrowsError(try session.checkSessionParams()) { error in
            XCTAssertEqual(error as? StorageManagerError, StorageManagerError.sessionIdAbsent)
        }
    }

    func testSessionServerBaseUrlIsPerInstance() {
        let first = StorageManager<SFAModel>(sessionServerBaseUrl: "https://session-a.example")
        let second = StorageManager<SFAModel>(sessionServerBaseUrl: "https://session-b.example")
        XCTAssertEqual(first.sessionServerBaseUrl, "https://session-a.example")
        XCTAssertEqual(second.sessionServerBaseUrl, "https://session-b.example")
    }

    func testLocalStorageHandlerRoundTrip() async throws {
        let store = MemoryKeyValueStore()
        let handler = LocalStorageHandler<SFAModel>(baseStorageKey: "sfa:", store: store)
        let key = "0x" + String(repeating: "a", count: 64)
        let model = SFAModel(publicKey: "pub", privateKey: "priv")
        try await handler.storeData(key: key, data: model, options: StorageHandlerStoreOptions())
        let loaded = try await handler.retrieveData(key: key, options: StorageHandlerRetrieveOptions())
        XCTAssertEqual(loaded, model)
        XCTAssertEqual(try handler.getStorageKey(key: key), "sfa:" + String(repeating: "a", count: 64))
    }

    func testLocalStorageHandlerCorruptedCacheReturnsNil() async throws {
        let store = MemoryKeyValueStore()
        let handler = LocalStorageHandler<SFAModel>(baseStorageKey: "sfa:", store: store)
        let key = "0x" + String(repeating: "b", count: 64)
        store.setItem(try handler.getStorageKey(key: key), "{not-json")
        let loaded = try await handler.retrieveData(key: key, options: StorageHandlerRetrieveOptions())
        XCTAssertNil(loaded)
        XCTAssertNil(store.getItem(try handler.getStorageKey(key: key)))
    }

    func testClearOrphanedDataRemovesPrefixedKeys() throws {
        let store = MemoryKeyValueStore()
        let handler = LocalStorageHandler<SFAModel>(baseStorageKey: "sfa:", store: store)
        store.setItem("sfa:one", "1")
        store.setItem("sfa:two", "2")
        store.setItem("other:three", "3")
        try handler.clearOrphanedData(baseKey: nil)
        XCTAssertNil(store.getItem("sfa:one"))
        XCTAssertNil(store.getItem("sfa:two"))
        XCTAssertEqual(store.getItem("other:three"), "3")
    }

    func testPadHexHelpers() {
        XCTAssertEqual(padHexString("0xabc"), String(repeating: "0", count: 61) + "abc")
        XCTAssertEqual(add0x("aa"), "0xaa")
        XCTAssertEqual(remove0x("0xAA"), "AA")
        XCTAssertTrue(isHexString("0xabc123"))
        XCTAssertFalse(isHexString(""))
        XCTAssertFalse(isHexString("zz"))
    }
}

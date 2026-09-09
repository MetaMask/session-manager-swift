@testable import SessionManager
import XCTest

final class StorageAdapterTest: XCTestCase {
    func testMemoryAdapterReadWriteRemove() async throws {
        let adapter = MemoryStorageAdapter()
        let missing = try await adapter.get(key: "k")
        XCTAssertNil(missing)
        try await adapter.set(key: "k", value: "v")
        let value = try await adapter.get(key: "k")
        XCTAssertEqual(value, "v")
        try await adapter.remove(key: "k")
        let removed = try await adapter.get(key: "k")
        XCTAssertNil(removed)
    }

    func testKeychainAdapterReadWriteRemove() async throws {
        let adapter = KeychainStorageAdapter()
        let key = "session-manager-test-\(UUID().uuidString)"
        try await adapter.remove(key: key)
        let missing = try await adapter.get(key: key)
        XCTAssertNil(missing)
        try await adapter.set(key: key, value: "secret")
        let value = try await adapter.get(key: key)
        XCTAssertEqual(value, "secret")
        try await adapter.remove(key: key)
        let removed = try await adapter.get(key: key)
        XCTAssertNil(removed)
    }

    func testRefreshTokenAdapterIsIsolatedByKeyPrefix() async throws {
        let access = KeychainStorageAdapter()
        let refresh = KeychainStorageAdapter(keyPrefix: "w3a.refresh.")
        let key = "w3a:refresh_token_test_\(UUID().uuidString)"
        try await refresh.set(key: key, value: "rt")
        let isolated = try await access.get(key: key)
        XCTAssertNil(isolated)
        let stored = try await refresh.get(key: key)
        XCTAssertEqual(stored, "rt")
        try await refresh.remove(key: key)
    }
}

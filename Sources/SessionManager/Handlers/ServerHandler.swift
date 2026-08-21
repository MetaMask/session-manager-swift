import Foundation

public class ServerHandler<T: Codable>: StorageHandler {
    public typealias SessionData = T

    private let sessionServerBaseUrl: String
    private let request: (ApiRequestParams) async throws -> Data

    public init(sessionServerBaseUrl: String, request: @escaping (ApiRequestParams) async throws -> Data) {
        self.sessionServerBaseUrl = sessionServerBaseUrl
        self.request = request
    }

    public func storeData<U: Encodable>(key: Hex, data: U, options: StorageHandlerStoreOptions = StorageHandlerStoreOptions()) async throws {
        let pubKey = try getStorageKey(key: key)
        let encData = try CryptoHelpers.encryptEncodable(privkeyHex: key, data)
        let signature = try CryptoHelpers.signEncryptedPayload(privkeyHex: key, encData: encData)
        var timeout: Int? = nil
        switch options.operation {
        case .create:
            timeout = options.timeout
        case .invalidate:
            timeout = 1
        case .update:
            timeout = nil
        }
        let body = SessionRequestBody(
            key: pubKey,
            data: encData,
            signature: signature,
            timeout: timeout,
            allowedOrigin: options.allowedOrigin,
            namespace: options.namespace
        )
        let encoded = try JSONEncoder().encode(body)
        if options.operation == .update {
            _ = try await request(ApiRequestParams(
                url: joinURL(sessionServerBaseUrl, "v2/store/update"),
                method: "PUT",
                headers: mergedHeaders(options.headers),
                body: encoded
            ))
            return
        }
        _ = try await request(ApiRequestParams(
            url: joinURL(sessionServerBaseUrl, "v2/store/set"),
            method: "POST",
            headers: mergedHeaders(options.headers),
            body: encoded
        ))
    }

    public func retrieveData(key: Hex, options: StorageHandlerRetrieveOptions = StorageHandlerRetrieveOptions()) async throws -> T? {
        let pubKey = try getStorageKey(key: key)
        let body = AuthorizeSessionRequest(key: pubKey, namespace: options.namespace)
        var headers = mergedHeaders(options.headers)
        if let origin = options.origin {
            headers["origin"] = origin
        }
        let data = try await request(ApiRequestParams(
            url: joinURL(sessionServerBaseUrl, "v2/store/get"),
            method: "POST",
            headers: headers,
            body: try JSONEncoder().encode(body)
        ))
        let result = try JSONDecoder().decode(SessionApiResponse.self, from: data)
        guard let message = result.message, !message.isEmpty else {
            throw StorageManagerError.dataNotFound
        }
        return try CryptoHelpers.decryptData(privKeyHex: key, d: message)
    }

    public func clearStorage(key: Hex) {}

    public func clearOrphanedData(baseKey: String?) {}

    public func getStorageKey(key: Hex) throws -> String {
        try CryptoHelpers.uncompressedPublicKey(privkeyHex: key)
    }

    private func mergedHeaders(_ extra: [String: String]) -> [String: String] {
        var headers = ["Content-Type": "application/json"]
        extra.forEach { headers[$0.key] = $0.value }
        return headers
    }
}

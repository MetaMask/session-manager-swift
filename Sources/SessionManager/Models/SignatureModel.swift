import Foundation

public struct Signature: Codable {
    let r: String
    let s: String

    public init(r: String, s: String) {
        self.r = r
        self.s = s
    }
}

struct SessionRequestBody: Encodable {
    var key: String
    var data: String
    var signature: String
    var timeout: Int?
    var allowedOrigin: String?
    var namespace: String?

    public init(key: String, data: String, signature: String, timeout: Int? = nil, allowedOrigin: String? = nil, namespace: String? = nil) {
        self.key = key
        self.data = data
        self.signature = signature
        self.timeout = timeout
        self.allowedOrigin = allowedOrigin
        self.namespace = namespace
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(data, forKey: .data)
        try container.encode(signature, forKey: .signature)
        try container.encodeIfPresent(timeout, forKey: .timeout)
        try container.encodeIfPresent(allowedOrigin, forKey: .allowedOrigin)
        try container.encodeIfPresent(namespace, forKey: .namespace)
    }

    enum CodingKeys: String, CodingKey {
        case key, data, signature, timeout, allowedOrigin, namespace
    }
}

struct AuthorizeSessionRequest: Encodable {
    var key: String
    var namespace: String?

    public init(key: String, namespace: String?) {
        self.key = key
        self.namespace = namespace
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encodeIfPresent(namespace, forKey: .namespace)
    }

    enum CodingKeys: String, CodingKey {
        case key, namespace
    }
}

public struct ECIES: Codable {
    public init(iv: String, ephemPublicKey: String, ciphertext: String, mac: String) {
        self.iv = iv
        self.ephemPublicKey = ephemPublicKey
        self.ciphertext = ciphertext
        self.mac = mac
    }

    var iv: String
    var ephemPublicKey: String
    var ciphertext: String
    var mac: String
}

import Foundation

public struct Signature: Codable {
    let r: String
    let s: String

    public init(r: String, s: String) {
        self.r = r
        self.s = s
    }
}

struct SessionRequestModel: Codable {
    var key: String
    var data: String
    var signature: String
    var timeout: Int
    var allowedOrigin: String?
    var namespace: String?

    public init(key: String, data: String, signature: String, timeout: Int, allowedOrigin: String? = "*", namespace: String? = nil) {
        self.key = key
        self.data = data
        self.signature = signature
        self.timeout = timeout
        self.allowedOrigin = allowedOrigin
        if namespace != nil {
            self.namespace = namespace
        }
    }
}

struct AuthorizeSessionRequest: Codable {
    var key: String
    var namespace: String?
    public init(key: String, namespace: String?) {
        self.key = key
        if namespace != nil {
            self.namespace = namespace
        }
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

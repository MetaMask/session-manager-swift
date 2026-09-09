import Foundation
import curveSecp256k1

public enum CryptoHelpers {
    public static func decryptData(privKeyHex: String, d: String) throws -> [String: Any] {
        let decrypted = try decryptToData(privKeyHex: privKeyHex, d: d)
        guard let dict = try JSONSerialization.jsonObject(with: decrypted) as? [String: Any] else {
            throw StorageManagerError.decodingError
        }
        return dict
    }

    public static func decryptData<T: Decodable>(privKeyHex: String, d: String) throws -> T {
        let decrypted = try decryptToData(privKeyHex: privKeyHex, d: d)
        return try JSONDecoder().decode(T.self, from: decrypted)
    }

    public static func encryptData(privkeyHex: String, _ dataToEncrypt: String) throws -> String {
        let secretKey = try curveSecp256k1.SecretKey(hex: remove0x(privkeyHex))
        let encParams = try curveSecp256k1.Encryption.encrypt(pk: secretKey.toPublic(), plainText: dataToEncrypt.data(using: .utf8)!)
        let ecies: ECIES = try .init(
            iv: encParams.iv(),
            ephemPublicKey: encParams.ephemeralPublicKey().serialize(compressed: false),
            ciphertext: encParams.chipherText(),
            mac: encParams.mac()
        )
        let data = try JSONEncoder().encode(ecies)
        guard let string = String(data: data, encoding: .utf8) else {
            throw StorageManagerError.runtimeError("Invalid String from enc Params")
        }
        return string
    }

    public static func encryptEncodable<T: Encodable>(privkeyHex: String, _ data: T) throws -> String {
        let encodedObj = try JSONEncoder().encode(data)
        guard let jsonString = String(data: encodedObj, encoding: .utf8) else {
            throw StorageManagerError.stringEncodingError
        }
        return try encryptData(privkeyHex: privkeyHex, jsonString)
    }

    public static func signEncryptedPayload(privkeyHex: String, encData: String) throws -> String {
        guard let encodedData = encData.data(using: .utf8) else {
            throw StorageManagerError.encodingError
        }
        let hashData = try curveSecp256k1.keccak256(data: encodedData)
        let secretKey = try curveSecp256k1.SecretKey(hex: remove0x(privkeyHex))
        let hashHex = hashData.map { String(format: "%02x", $0) }.joined()
        let sig = try curveSecp256k1.ECDSA.signRecoverable(key: secretKey, hash: hashHex).serialize()
        let sigRS: [String: String] = [
            "r": String(sig.suffix(130).prefix(64)),
            "s": String(sig.suffix(66).prefix(64))
        ]
        let sigData = try JSONSerialization.data(withJSONObject: sigRS)
        guard let sigJsonStr = String(data: sigData, encoding: .utf8) else {
            throw StorageManagerError.stringEncodingError
        }
        return sigJsonStr
    }

    public static func uncompressedPublicKey(privkeyHex: String) throws -> String {
        let secretKey = try curveSecp256k1.SecretKey(hex: remove0x(privkeyHex))
        return try secretKey.toPublic().serialize(compressed: false)
    }

    static func decryptToData(privKeyHex: String, d: String) throws -> Data {
        let secretKey = try curveSecp256k1.SecretKey(hex: remove0x(privKeyHex))
        let data = d.data(using: .utf8) ?? Data()
        let ecies = try JSONDecoder().decode(ECIES.self, from: data)
        let encrytedFormat = try EncryptedMessage(
            cipherText: ecies.ciphertext,
            ephemeralPublicKey: curveSecp256k1.PublicKey(hex: ecies.ephemPublicKey),
            iv: ecies.iv,
            mac: ecies.mac
        )
        return try curveSecp256k1.Encryption.decrypt(sk: secretKey, encrypted: encrytedFormat)
    }
}

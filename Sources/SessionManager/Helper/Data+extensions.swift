//
//  File.swift
//
//
//  Created by Michael Lee on 8/3/2022.
//
import Foundation

extension Data {
    static func fromBase64URL(_ str: String) -> Data? {
        var base64 = str
        base64 = base64.replacingOccurrences(of: "-", with: "+")
        base64 = base64.replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64 = base64.appending("=")
        }
        guard let data = Data(base64Encoded: base64) else {
            return nil
        }
        return data
    }

    func toBase64URL() -> String {
        var result = base64EncodedString()
        result = result.replacingOccurrences(of: "+", with: "-")
        result = result.replacingOccurrences(of: "/", with: "_")
        result = result.replacingOccurrences(of: "=", with: "")
        return result
    }
}

extension Data {
    init?(hexString: String) {
        let length = hexString.count / 2
        var data = Data(capacity: length)
        for i in 0 ..< length {
            let j = hexString.index(hexString.startIndex, offsetBy: i * 2)
            let k = hexString.index(j, offsetBy: 2)
            let bytes = hexString[j ..< k]
            if var byte = UInt8(bytes, radix: 16) {
                data.append(&byte, count: 1)
            } else {
                return nil
            }
        }
        self = data
    }

    func addLeading0sForLength64() -> Data {
        let hex = map { String(format: "%02x", $0) }.joined()
        return Data(hexString: hex.padStart(toLength: 64, padString: "0")) ?? Data()
    }

    static func randomOfLength(_ length: Int) -> Data? {
        var data = [UInt8](repeating: 0, count: length)
        let result = SecRandomCopyBytes(kSecRandomDefault,
                                        data.count,
                                        &data)
        if result == errSecSuccess {
            return Data(data)
        }

        return nil
    }
}

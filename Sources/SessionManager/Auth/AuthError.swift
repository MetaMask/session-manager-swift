import Foundation

public enum AuthErrorCode: String {
    case expired = "EXPIRED"
    case invalid = "INVALID"
    case refreshFailed = "REFRESH_FAILED"
    case network = "NETWORK"
    case decryptFailed = "DECRYPT_FAILED"
    case noSessionId = "NO_SESSION_ID"
    case sessionExpired = "SESSION_EXPIRED"
}

public struct AuthError: Error, LocalizedError, Equatable {
    public let message: String
    public let code: AuthErrorCode

    public init(message: String, code: AuthErrorCode) {
        self.message = message
        self.code = code
    }

    public var errorDescription: String? {
        return message
    }
}

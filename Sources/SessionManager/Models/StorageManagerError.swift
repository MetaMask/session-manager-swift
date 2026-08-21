import Foundation

public enum StorageManagerError: Error, Equatable {
    case runtimeError(String)
    case decodingError
    case encodingError
    case sessionIdAbsent
    case dataNotFound
    case stringEncodingError
    case invalidSessionId
    case invalidURL
}

extension StorageManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .runtimeError(msg):
            return msg
        case .decodingError:
            return "Decoding error"
        case .encodingError:
            return "Encoding error"
        case .sessionIdAbsent:
            return "SessionId not found!"
        case .dataNotFound:
            return "Data not found!"
        case .stringEncodingError:
            return "String Encoding error"
        case .invalidSessionId:
            return "Session id must be a hex string"
        case .invalidURL:
            return "Invalid URL"
        }
    }
}

@available(*, deprecated, renamed: "StorageManagerError")
public typealias SessionManagerError = StorageManagerError

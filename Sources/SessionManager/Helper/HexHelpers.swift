import Foundation

public func remove0x(_ hex: String) -> String {
    if hex.count >= 2 {
        let prefix = hex.prefix(2).lowercased()
        if prefix == "0x" {
            return String(hex.dropFirst(2))
        }
    }
    return hex
}

public func add0x(_ hex: String) -> Hex {
    let stripped = remove0x(hex)
    return "0x\(stripped)"
}

public func padHexString(_ hexString: String) -> String {
    let stripped = remove0x(hexString)
    return String(stripped.padStart(toLength: 64, padString: "0").prefix(64))
}

public func isHexString(_ value: String) -> Bool {
    guard !value.isEmpty else { return false }
    return value.range(of: "^(0x|0X)?[0-9a-fA-F]+$", options: .regularExpression) != nil
}

func normalizeSessionId(_ sessionId: String) throws -> Hex {
    guard isHexString(sessionId) else {
        throw StorageManagerError.invalidSessionId
    }
    return add0x(padHexString(sessionId))
}

func joinURL(_ base: String, _ path: String) -> String {
    let trimmedBase = base.hasSuffix("/") ? String(base.dropLast()) : base
    let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
    return "\(trimmedBase)/\(trimmedPath)"
}

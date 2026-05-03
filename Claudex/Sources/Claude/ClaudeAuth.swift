import Foundation

enum ClaudeAuthError: Error, Equatable {
    case missingSessionKey
    case invalidFormat
}

enum ClaudeAuth {
    static let sessionKeyPrefix = "sk-ant-"

    static func currentSessionKey() throws -> String {
        let value: String
        do {
            value = try KeychainStore.read(.claudeSessionKey)
        } catch KeychainError.itemNotFound {
            throw ClaudeAuthError.missingSessionKey
        }
        try validate(value)
        return value
    }

    static func validate(_ sessionKey: String) throws {
        let trimmed = sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(sessionKeyPrefix), trimmed.count > sessionKeyPrefix.count else {
            throw ClaudeAuthError.invalidFormat
        }
    }

    static func mask(_ sessionKey: String) -> String {
        let prefix = String(sessionKey.prefix(sessionKeyPrefix.count))
        return "\(prefix)****"
    }
}

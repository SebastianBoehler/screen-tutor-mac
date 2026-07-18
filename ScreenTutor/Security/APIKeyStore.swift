import Foundation
import Security

@MainActor
final class APIKeyStore {
    private let service = "com.sebastianboehler.ScreenTutor"
    private let account = "openai-api-key"

    var hasAPIKey: Bool {
        (try? load()) != nil
    }

    func load() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.status(status) }
        guard
            let data = result as? Data,
            let key = String(data: data, encoding: .utf8),
            !key.isEmpty
        else {
            throw KeychainError.invalidData
        }
        return key
    }

    func save(_ key: String) throws {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedKey.hasPrefix("sk-") else { throw KeychainError.invalidKey }
        guard let data = trimmedKey.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let updateStatus = SecItemUpdate(
            identity as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainError.status(updateStatus)
        }

        var insertion = identity
        insertion[kSecValueData as String] = data
        let addStatus = SecItemAdd(insertion as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.status(addStatus) }
    }

    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.status(status)
        }
    }
}

enum KeychainError: LocalizedError {
    case invalidKey
    case invalidData
    case status(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            "Enter a valid OpenAI API key beginning with sk-."
        case .invalidData:
            "The API key could not be read from Keychain."
        case .status(let status):
            SecCopyErrorMessageString(status, nil) as String?
                ?? "Keychain returned error \(status)."
        }
    }
}

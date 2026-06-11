import Foundation
import Security

enum KeychainStore {
    static let service = "com.arogya.loopforge"
    static let legacyService = "PromptVideoBuilder"

    static func value(for account: String, service: String = service) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func set(_ value: String, for account: String, service: String = service) {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if value.isEmpty {
            SecItemDelete(baseQuery as CFDictionary)
            return
        }

        let data = Data(value.utf8)
        let attributes: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var insert = baseQuery
            insert[kSecValueData as String] = data
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    static func migrateLegacyValueIfNeeded(for account: String) {
        guard value(for: account).isEmpty else { return }
        let legacyValue = value(for: account, service: legacyService)
        guard !legacyValue.isEmpty else { return }
        set(legacyValue, for: account)
    }

    static func removeValue(for account: String, service: String = service) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

import Foundation
import os
import Security

/// Stores the Mac login password securely in the system Keychain.
class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    private let service = "com.raghav.ProximityUnlock"
    private let account = "macLoginPassword"

    func savePassword(_ password: String) {
        guard let data = password.data(using: .utf8) else { return }

        // Delete any existing entry first.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            Log.unlock.error("Keychain savePassword failed with OSStatus \(status, privacy: .public)")
        }
    }

    func getPassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status != errSecSuccess && status != errSecItemNotFound {
            Log.unlock.error("Keychain getPassword failed with OSStatus \(status, privacy: .public)")
        }
        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8)
        else { return nil }

        return password
    }

    func deletePassword() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            Log.unlock.error("Keychain deletePassword failed with OSStatus \(status, privacy: .public)")
        }
    }

    func hasPassword() -> Bool {
        getPassword() != nil
    }
}

import Foundation
import CryptoKit
import os
import Security

/// Stores the Mac login password securely in the system Keychain.
/// M8+: Password is AES-GCM encrypted using a key derived from the pairing shared secret.
/// Falls back to storing plaintext only when not yet paired (which the UI prevents via gating).
class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    private let service = "com.raghav.ProximityUnlock"
    private let legacyAccount = "macLoginPassword"        // pre-M8 plaintext account

    // MARK: - Public API

    /// Save the Mac login password. Encrypts with the pairing-derived key when paired.
    func savePassword(_ password: String) {
        guard let data = password.data(using: .utf8) else { return }

        if let encKey = derivePasswordEncryptionKey() {
            // Paired — encrypt and store via SecureKeyStore
            do {
                let sealedBox = try AES.GCM.seal(data, using: encKey)
                let combined = sealedBox.combined!
                try SecureKeyStore.shared.storeEncryptedPassword(combined)
                // Remove legacy plaintext entry if it exists
                deleteLegacyPassword()
                Log.unlock.info("Password saved (AES-GCM encrypted)")
            } catch {
                Log.unlock.error("Failed to encrypt password: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            // Not paired — store plaintext (SettingsView gates this section on pairing,
            // so this path is only reached during first-launch before pairing completes)
            savePlaintext(data)
            Log.unlock.info("Password saved (plaintext — not yet paired)")
        }
    }

    /// Retrieve and decrypt the Mac login password.
    func getPassword() -> String? {
        migrateIfNeeded()

        // Try encrypted path first
        if let encKey = derivePasswordEncryptionKey(),
           let combined = SecureKeyStore.shared.retrieveEncryptedPassword() {
            do {
                let sealedBox = try AES.GCM.SealedBox(combined: combined)
                let plaintext = try AES.GCM.open(sealedBox, using: encKey)
                return String(data: plaintext, encoding: .utf8)
            } catch {
                Log.unlock.error("Failed to decrypt password: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }

        // Fallback: legacy plaintext (should be empty after migration)
        return getLegacyPassword()
    }

    /// Delete the password (both encrypted and legacy entries).
    func deletePassword() {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: KeychainKey.macLoginPasswordEncrypted
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        deleteLegacyPassword()
    }

    func hasPassword() -> Bool {
        migrateIfNeeded()
        if SecureKeyStore.shared.retrieveEncryptedPassword() != nil { return true }
        return getLegacyPassword() != nil
    }

    // MARK: - Private

    /// Derive a 256-bit AES key from the long-term pairing shared key via HKDF.
    private func derivePasswordEncryptionKey() -> SymmetricKey? {
        guard let sharedKeyData = SecureKeyStore.shared.retrievePairedSharedKey() else { return nil }
        let inputKey = SymmetricKey(data: sharedKeyData)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: Data(),
            info: "ProximityUnlock-password-encryption".data(using: .utf8)!,
            outputByteCount: 32
        )
    }

    /// Migrate a pre-M8 plaintext password to the encrypted Keychain entry.
    private func migrateIfNeeded() {
        guard let plaintext = getLegacyPassword() else { return }  // nothing to migrate
        guard let encKey = derivePasswordEncryptionKey() else {
            // Not yet paired — delete plaintext to avoid storing it indefinitely
            Log.unlock.warning("Found legacy plaintext password but not paired — deleting it")
            deleteLegacyPassword()
            return
        }

        guard let data = plaintext.data(using: .utf8) else {
            deleteLegacyPassword()
            return
        }

        do {
            let sealedBox = try AES.GCM.seal(data, using: encKey)
            try SecureKeyStore.shared.storeEncryptedPassword(sealedBox.combined!)
            deleteLegacyPassword()
            Log.unlock.info("Migrated plaintext password to AES-GCM encrypted storage")
        } catch {
            Log.unlock.error("Password migration failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func savePlaintext(_ data: Data) {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: legacyAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: legacyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            Log.unlock.error("Keychain savePlaintext failed with OSStatus \(status, privacy: .public)")
        }
    }

    private func getLegacyPassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: legacyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8)
        else { return nil }
        return password
    }

    private func deleteLegacyPassword() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: legacyAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}

import Foundation
import CryptoKit
import os

/// Manages the Mac's long-term P-256 identity key used for pairing and message signing.
/// The key is stored as raw data in the Keychain (CryptoKit P256 on Mac, not Secure Enclave
/// since SE is only available on Apple Silicon with specific entitlements).
class IdentityKeyManager: IdentityKeyProviding {

    static let shared = IdentityKeyManager()

    private let keyStore = SecureKeyStore.shared
    private var signingKey: P256.Signing.PrivateKey?

    init() {}

    // MARK: - IdentityKeyProviding

    func loadOrGenerateIdentityKey() throws {
        if let stored = keyStore.retrieveIdentityKeyMaterial(account: KeychainKey.identitySigningKey) {
            Log.pairing.info("Loaded existing identity signing key")
            signingKey = try P256.Signing.PrivateKey(x963Representation: stored)
        } else {
            Log.pairing.info("Generating new identity signing key")
            let key = P256.Signing.PrivateKey()
            try keyStore.storeIdentityKeyMaterial(key.x963Representation, account: KeychainKey.identitySigningKey)
            signingKey = key
        }
    }

    func getIdentityPublicKey() throws -> Data {
        guard let key = signingKey else {
            try loadOrGenerateIdentityKey()
            guard let key = signingKey else {
                throw SecurityError.keyGenerationFailed
            }
            return key.publicKey.x963Representation
        }
        return key.publicKey.x963Representation
    }

    func sign(_ data: Data) throws -> Data {
        guard let key = signingKey else {
            throw SecurityError.keyGenerationFailed
        }
        let signature = try key.signature(for: SHA256.hash(data: data))
        return signature.derRepresentation
    }

    // MARK: - ECDH for Pairing

    /// Generate a fresh ephemeral key agreement key for one pairing session.
    /// Returns (ephemeralPrivate, ephemeralPublicKeyData)
    func generateEphemeralKeyPair() -> (P256.KeyAgreement.PrivateKey, Data) {
        let ephemeralKey = P256.KeyAgreement.PrivateKey()
        return (ephemeralKey, ephemeralKey.publicKey.x963Representation)
    }

    /// Perform ECDH with peer's ephemeral public key to get shared secret.
    func deriveSharedSecret(
        myEphemeral: P256.KeyAgreement.PrivateKey,
        peerEphemeralPublicKeyData: Data
    ) throws -> SharedSecret {
        let peerPublicKey = try P256.KeyAgreement.PublicKey(x963Representation: peerEphemeralPublicKeyData)
        return try myEphemeral.sharedSecretFromKeyAgreement(with: peerPublicKey)
    }
}

import Foundation
import CryptoKit

// MARK: - Security Errors

enum SecurityError: LocalizedError {
    case keyGenerationFailed
    case invalidPublicKey
    case sharedSecretFailed
    case signatureFailed
    case verificationFailed
    case unknownPeer
    case replayDetected
    case keychainError(String)
    case invalidSignature
    case networkError(String)
    case timeout
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate cryptographic keys"
        case .invalidPublicKey:
            return "Invalid public key"
        case .sharedSecretFailed:
            return "Failed to derive shared secret"
        case .signatureFailed:
            return "Failed to sign message"
        case .verificationFailed:
            return "Failed to verify signature"
        case .unknownPeer:
            return "Message from unknown peer"
        case .replayDetected:
            return "Replay attack detected (message counter out of order)"
        case .keychainError(let detail):
            return "Keychain error: \(detail)"
        case .invalidSignature:
            return "Invalid signature"
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .timeout:
            return "Operation timed out"
        case .userCancelled:
            return "User cancelled pairing"
        }
    }
}

// MARK: - Pairing State

enum PairingState {
    case unpaired
    case pairing(phase: PairingPhase)
    case paired(peerName: String)
}

enum PairingPhase {
    case waitingForPeer
    case exchangingKeys
    case displayingCode(code: String)
    case confirming
    case deriving
}

// MARK: - Key Material Identifiers

struct KeychainKey {
    /// Device identity signing key (permanent, reused across pairings)
    static let identitySigningKey = "identitySigningKey"
    /// Device identity public key (permanent, reused across pairings)
    static let identityPublicKey = "identityPublicKey"
    /// Paired peer's identity public key (deleted on unpair)
    static let pairedPeerIdentityPublicKey = "pairedPeerIdentityPublicKey"
    /// Long-term shared key derived from pairing (deleted on unpair)
    static let pairedSharedKey = "pairedSharedKey"
    /// Encrypted login password (Mac only, deleted on unpair)
    static let macLoginPasswordEncrypted = "macLoginPasswordEncrypted"
}

// MARK: - Secure Message Format

struct SecureMessage: Codable {
    let version: UInt8
    let command: String
    let counter: UInt64
    let timestamp: UInt64
    let payload: Data?
    let senderPublicKey: Data
    let signature: Data

    enum CodingKeys: String, CodingKey {
        case version, command, counter, timestamp, payload, senderPublicKey, signature
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(command, forKey: .command)
        try container.encode(counter, forKey: .counter)
        try container.encode(timestamp, forKey: .timestamp)
        if let payload {
            try container.encode(payload, forKey: .payload)
        }
        try container.encode(senderPublicKey, forKey: .senderPublicKey)
        try container.encode(signature, forKey: .signature)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(UInt8.self, forKey: .version)
        guard version == 1 else { throw SecurityError.networkError("Unsupported message version: \(version)") }
        self.version = version
        self.command = try container.decode(String.self, forKey: .command)
        self.counter = try container.decode(UInt64.self, forKey: .counter)
        self.timestamp = try container.decode(UInt64.self, forKey: .timestamp)
        self.payload = try container.decodeIfPresent(Data.self, forKey: .payload)
        self.senderPublicKey = try container.decode(Data.self, forKey: .senderPublicKey)
        self.signature = try container.decode(Data.self, forKey: .signature)
    }

    init(
        command: String,
        counter: UInt64,
        timestamp: UInt64 = UInt64(Date().timeIntervalSince1970),
        payload: Data? = nil,
        senderPublicKey: Data,
        signature: Data
    ) {
        self.version = 1
        self.command = command
        self.counter = counter
        self.timestamp = timestamp
        self.payload = payload
        self.senderPublicKey = senderPublicKey
        self.signature = signature
    }
}

// MARK: - Identity Key Provider Protocol

protocol IdentityKeyProviding {
    /// Load or generate the device's identity signing key
    func loadOrGenerateIdentityKey() throws
    /// Get the device's identity public key
    func getIdentityPublicKey() throws -> Data
    /// Sign data with the identity key
    func sign(_ data: Data) throws -> Data
}

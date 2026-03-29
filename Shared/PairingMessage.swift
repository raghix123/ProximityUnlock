import Foundation

// MARK: - Pairing Protocol Messages

struct PairingRequest: Codable {
    let type = "pairing_request"
    let ephemeralPublicKey: Data      // x963Representation of P256.KeyAgreement.PublicKey (65 bytes)
    let identityPublicKey: Data       // x963Representation of identity key (65 bytes)
    let displayName: String
}

struct PairingResponse: Codable {
    let type = "pairing_response"
    let ephemeralPublicKey: Data
    let identityPublicKey: Data
    let displayName: String
}

struct PairingConfirmation: Codable {
    let type = "pairing_confirmed"
    let identitySignature: Data       // ECDSA signature over confirmation data
}

struct PairingCancelled: Codable {
    let type = "pairing_cancelled"
    let reason: String
}

struct UnpairNotification: Codable {
    let type = "unpair_notification"
}

// MARK: - Pairing Message Wrapper

enum PairingMessageType: Codable {
    case request(PairingRequest)
    case response(PairingResponse)
    case confirmation(PairingConfirmation)
    case cancelled(PairingCancelled)
    case unpair(UnpairNotification)

    enum CodingKeys: String, CodingKey {
        case type
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .request(let msg):
            try msg.encode(to: encoder)
        case .response(let msg):
            try msg.encode(to: encoder)
        case .confirmation(let msg):
            try msg.encode(to: encoder)
        case .cancelled(let msg):
            try msg.encode(to: encoder)
        case .unpair(let msg):
            try msg.encode(to: encoder)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "pairing_request":
            let msg = try PairingRequest(from: decoder)
            self = .request(msg)
        case "pairing_response":
            let msg = try PairingResponse(from: decoder)
            self = .response(msg)
        case "pairing_confirmed":
            let msg = try PairingConfirmation(from: decoder)
            self = .confirmation(msg)
        case "pairing_cancelled":
            let msg = try PairingCancelled(from: decoder)
            self = .cancelled(msg)
        case "unpair_notification":
            let msg = try UnpairNotification(from: decoder)
            self = .unpair(msg)
        default:
            throw SecurityError.networkError("Unknown pairing message type: \(type)")
        }
    }
}

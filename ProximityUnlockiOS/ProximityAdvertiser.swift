import Foundation
import CoreBluetooth
import UIKit

/// Top-level state coordinator for the iOS app.
/// BLE is RSSI-only (advertisement beacon). All commands flow via MPC (MultipeerConnectivity).
@MainActor
class ProximityAdvertiser: ObservableObject {

    // MARK: - Published State

    @Published var bluetoothState: CBManagerState = .unknown
    @Published var isAdvertising: Bool = false
    @Published var isMPCConnected: Bool = false
    @Published var isPaired: Bool = false
    @Published var pendingUnlockRequest: Bool = false

    @Published var isEnabled: Bool = true {
        didSet {
            Log.ui.info("isEnabled changed to \(self.isEnabled, privacy: .public)")
            UserDefaults.standard.set(isEnabled, forKey: "isEnabled")
            if isEnabled {
                bleManager.startAdvertising()
                multipeerManager.startAdvertising()
            } else {
                bleManager.stopAdvertising()
                multipeerManager.stopAdvertising()
            }
        }
    }

    @Published var requiresConfirmation: Bool = true {
        didSet { confirmationManager.requiresConfirmation = requiresConfirmation }
    }

    // MARK: - Sub-managers

    let bleManager: BLEPeripheralManager
    let confirmationManager: UnlockConfirmationManager
    let multipeerManager = MultipeerManager()

    var pairingManager: PairingManager { multipeerManager.pairingManager }

    // MARK: - Init

    init() {
        bleManager = BLEPeripheralManager()
        confirmationManager = UnlockConfirmationManager()

        // Restore persisted settings
        if UserDefaults.standard.object(forKey: "isEnabled") != nil {
            isEnabled = UserDefaults.standard.bool(forKey: "isEnabled")
        }
        requiresConfirmation = confirmationManager.requiresConfirmation
        Log.ui.info("Init: isEnabled=\(self.isEnabled, privacy: .public), requiresConfirmation=\(self.requiresConfirmation, privacy: .public)")

        // Forward BLE state to published properties
        bleManager.$bluetoothState.assign(to: &$bluetoothState)
        bleManager.$isAdvertising.assign(to: &$isAdvertising)

        // Forward MPC state
        multipeerManager.$isConnected.assign(to: &$isMPCConnected)

        // Forward pairing state
        multipeerManager.pairingManager.$pairingState
            .map { state in
                if case .paired = state { return true }
                return false
            }
            .assign(to: &$isPaired)

        // Request notification permission on first launch
        confirmationManager.requestNotificationPermission()

        // Wire MPC commands → confirmation manager
        multipeerManager.onUnlockRequest = { [weak self] in
            Task { @MainActor [weak self] in self?.confirmationManager.receiveUnlockRequest() }
        }
        multipeerManager.onLockEvent = { [weak self] in
            Task { @MainActor [weak self] in self?.confirmationManager.receiveLockEvent() }
        }

        // Wire confirmation → send via MPC (MPC-only, no BLE fallback)
        confirmationManager.onConfirmationSent = { [weak self] approved in
            self?.multipeerManager.sendConfirmation(approved: approved)
        }

        // Forward pendingRequest to top-level published property
        confirmationManager.$pendingRequest.assign(to: &$pendingUnlockRequest)

        if isEnabled { multipeerManager.startAdvertising() }
    }

    // MARK: - Public API

    func approve() {
        Log.proximity.info("User approved unlock")
        confirmationManager.approve()
    }

    func deny() {
        Log.proximity.info("User denied unlock")
        confirmationManager.deny()
    }

    func lockMac() {
        Log.proximity.info("Sending lock command")
        multipeerManager.sendMessage("lock_command")
    }

    func unlockMac() {
        Log.proximity.info("Sending unlock command")
        multipeerManager.sendMessage("unlock_command")
    }

    var bluetoothStatusDescription: String {
        switch bluetoothState {
        case .poweredOn:     return isAdvertising ? (isMPCConnected ? "Connected to Mac" : "Advertising...") : "Stopped"
        case .poweredOff:    return "Bluetooth Off"
        case .unauthorized:  return "Permission Denied"
        case .unsupported:   return "BLE Not Supported"
        case .resetting:     return "Resetting..."
        case .unknown:       return "Initializing..."
        @unknown default:    return "Unknown"
        }
    }
}

import CoreBluetooth
import Foundation
import AppKit
import os

/// BLE service UUID shared with the iOS app.
/// M7+: Only the service UUID is needed for scanning/RSSI. No characteristics.
enum BLEConstants {
    static let serviceUUID = CBUUID(string: "5F0A4A6E-9DC4-4C57-9A8C-D8BF0B1B0FDE")
}

/// M7+: BLE is RSSI-only. The Mac scans for the iPhone's service UUID,
/// connects to poll RSSI for proximity sensing, and fires device found/lost events.
/// All commands (unlock_request, lock_event, confirmations) flow exclusively over MPC.
class BLECentralManager: NSObject, BLECentralManaging {

    private var central: CBCentralManagerProtocol!
    private var peripheral: CBPeripheral?
    private var rssiTimer: Timer?
    private var lostTimer: Timer?

    // MARK: - Callbacks

    let onRSSIUpdate:  (Int) -> Void
    let onDeviceFound: () -> Void
    let onDeviceLost:  () -> Void

    // MARK: - Init

    convenience init(
        onRSSIUpdate:  @escaping (Int) -> Void,
        onDeviceFound: @escaping () -> Void,
        onDeviceLost:  @escaping () -> Void
    ) {
        self.init(
            centralManager: nil,
            onRSSIUpdate: onRSSIUpdate,
            onDeviceFound: onDeviceFound,
            onDeviceLost: onDeviceLost
        )
    }

    init(
        centralManager: CBCentralManagerProtocol?,
        onRSSIUpdate:  @escaping (Int) -> Void,
        onDeviceFound: @escaping () -> Void,
        onDeviceLost:  @escaping () -> Void
    ) {
        self.onRSSIUpdate  = onRSSIUpdate
        self.onDeviceFound = onDeviceFound
        self.onDeviceLost  = onDeviceLost
        super.init()

        if let existing = centralManager {
            self.central = existing
        } else {
            self.central = CBCentralManager(delegate: self, queue: nil)
        }

        // When the Mac wakes from sleep, cancel stale connection and restart scanning.
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWakeFromSleep()
        }
    }

    // MARK: - Scanning / RSSI

    private func startScanning() {
        guard central.state == .poweredOn else { return }
        // allowDuplicates: true gives sub-second RSSI updates from advertisement packets.
        central.scanForPeripherals(
            withServices: [BLEConstants.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    private func startRSSIPolling() {
        rssiTimer?.invalidate()
        rssiTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.peripheral?.readRSSI()
        }
        peripheral?.readRSSI()
    }

    private func stopRSSIPolling() {
        rssiTimer?.invalidate()
        rssiTimer = nil
        lostTimer?.invalidate()
        lostTimer = nil
    }

    private func resetLostTimer() {
        lostTimer?.invalidate()
        lostTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            guard let self, let p = self.peripheral else { return }
            self.central.cancelPeripheralConnection(p)
        }
    }

    private func handleWakeFromSleep() {
        Log.ble.info("Handling wake from sleep")
        if let p = peripheral {
            central.cancelPeripheralConnection(p)
        } else {
            startScanning()
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLECentralManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Log.ble.info("Central manager state: \(String(describing: central.state.rawValue), privacy: .public)")
        if central.state == .poweredOn {
            startScanning()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let rssiValue = RSSI.intValue
        guard rssiValue < 0 else { return }

        if self.peripheral == nil {
            Log.ble.info("Discovered peripheral: \(peripheral.name ?? "unknown", privacy: .public) RSSI=\(rssiValue, privacy: .public)")
            self.peripheral = peripheral
            self.peripheral?.delegate = self
            self.central.stopScan()
            self.central.connect(peripheral, options: nil)
            onDeviceFound()
        }
        // Feed advertisement RSSI immediately for fast proximity updates.
        onRSSIUpdate(rssiValue)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Log.ble.info("Connected to peripheral: \(peripheral.name ?? "unknown", privacy: .public)")
        startRSSIPolling()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Log.ble.info("Disconnected from peripheral: \(peripheral.name ?? "unknown", privacy: .public), error: \(error?.localizedDescription ?? "none", privacy: .public)")
        stopRSSIPolling()
        self.peripheral = nil
        onDeviceLost()
        startScanning()
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Log.ble.error("Failed to connect: \(peripheral.name ?? "unknown", privacy: .public), error: \(error?.localizedDescription ?? "none", privacy: .public)")
        self.peripheral = nil
        startScanning()
    }
}

// MARK: - CBPeripheralDelegate

extension BLECentralManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let error {
            Log.ble.error("Failed to read RSSI: \(error.localizedDescription, privacy: .public)")
        }
        guard error == nil else { return }
        Log.ble.debug("RSSI: \(RSSI.intValue, privacy: .public)")
        resetLostTimer()
        onRSSIUpdate(RSSI.intValue)
    }
}

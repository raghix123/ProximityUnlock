import Foundation
@testable import ProximityUnlockMac

/// Mock BLE central manager for unit tests.
/// Records all commands written to it, and exposes helpers to simulate BLE events
/// by calling ProximityMonitor's internal callback methods directly.
class MockBLECentralManager: BLECentralManaging {

    // MARK: - Recording

    /// All commands written via writeCommand(_:), in order.
    private(set) var writtenCommands: [String] = []

    // MARK: - BLECentralManaging

    func writeCommand(_ command: String) {
        writtenCommands.append(command)
    }

    // MARK: - Helpers

    var lastCommand: String? { writtenCommands.last }

    func didWrite(_ command: String) -> Bool {
        writtenCommands.contains(command)
    }

    func reset() {
        writtenCommands.removeAll()
    }
}

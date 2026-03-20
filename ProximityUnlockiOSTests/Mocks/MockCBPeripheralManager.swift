import CoreBluetooth
import Foundation
@testable import ProximityUnlockiOS

/// Mock CBPeripheralManager for iOS unit tests.
/// Records all advertising and service operations without requiring real Bluetooth hardware.
class MockCBPeripheralManager: CBPeripheralManagerProtocol {

    // MARK: - Controllable State

    var state: CBManagerState = .poweredOn

    // MARK: - Recording

    private(set) var startAdvertisingCalled = false
    private(set) var stopAdvertisingCalled = false
    private(set) var removeAllServicesCalled = false
    private(set) var addedServices: [CBMutableService] = []
    private(set) var updatedValues: [(data: Data, characteristic: CBMutableCharacteristic)] = []
    private(set) var advertisementData: [String: Any]?

    // MARK: - CBPeripheralManagerProtocol

    func startAdvertising(_ advertisementData: [String: Any]?) {
        startAdvertisingCalled = true
        self.advertisementData = advertisementData
    }

    func stopAdvertising() {
        stopAdvertisingCalled = true
    }

    func add(_ service: CBMutableService) {
        addedServices.append(service)
    }

    func removeAllServices() {
        removeAllServicesCalled = true
        addedServices.removeAll()
    }

    func respond(to request: CBATTRequest, withResult result: CBATTError.Code) {
        // No-op in mock
    }

    @discardableResult
    func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [CBCentral]?) -> Bool {
        updatedValues.append((data: value, characteristic: characteristic))
        return true
    }

    // MARK: - Helpers

    var lastUpdatedValue: String? {
        guard let data = updatedValues.last?.data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func advertisedServiceUUIDs() -> [CBUUID]? {
        advertisementData?[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
    }

    func reset() {
        startAdvertisingCalled = false
        stopAdvertisingCalled = false
        removeAllServicesCalled = false
        addedServices.removeAll()
        updatedValues.removeAll()
        advertisementData = nil
    }
}

import XCTest
import CoreBluetooth
@testable import ProximityUnlockiOS

/// Tests for BLEPeripheralManager (RSSI beacon only, M7+).
/// BLE no longer handles commands — only advertises the service UUID for RSSI proximity sensing.
final class BLEPeripheralManagerTests: XCTestCase {

    private var bleManager: BLEPeripheralManager!
    private var mockPM: MockCBPeripheralManager!

    override func setUp() {
        mockPM = MockCBPeripheralManager()
        mockPM.state = .poweredOn
        bleManager = BLEPeripheralManager(peripheralManager: mockPM)
    }

    override func tearDown() {
        bleManager = nil
        mockPM = nil
    }

    // MARK: - Advertising

    func testStartsAdvertisingWhenPoweredOn() {
        bleManager.startAdvertising()
        XCTAssertTrue(mockPM.startAdvertisingCalled)
    }

    func testAdvertisesCorrectServiceUUID() {
        bleManager.startAdvertising()
        let uuids = mockPM.advertisedServiceUUIDs()
        XCTAssertEqual(uuids?.first, BLEConstants.serviceUUID)
    }

    func testDoesNotAdvertiseWhenBluetoothOff() {
        mockPM.state = .poweredOff
        bleManager.startAdvertising()
        XCTAssertFalse(mockPM.startAdvertisingCalled)
    }

    func testStopAdvertisingCallsRemoveAllServices() {
        bleManager.startAdvertising()
        bleManager.stopAdvertising()
        XCTAssertTrue(mockPM.stopAdvertisingCalled)
        XCTAssertTrue(mockPM.removeAllServicesCalled)
        XCTAssertFalse(bleManager.isAdvertising)
    }

    // MARK: - Service Structure (RSSI-only: no characteristics)

    func testServiceAddedWithCorrectUUID() {
        bleManager.startAdvertising()
        let service = mockPM.addedServices.first
        XCTAssertNotNil(service, "a CBMutableService should be added")
        XCTAssertEqual(service?.uuid, BLEConstants.serviceUUID)
    }

    func testServiceHasNoCharacteristics() {
        bleManager.startAdvertising()
        let service = mockPM.addedServices.first
        // BLE is RSSI-only — no characteristics needed
        let chars = service?.characteristics ?? []
        XCTAssertTrue(chars.isEmpty, "RSSI-only peripheral must have no characteristics")
    }

    // MARK: - State Changes

    func testPoweredOnStateTriggersAddServiceAndStartAdvertising() {
        mockPM.reset()
        mockPM.state = .poweredOn

        bleManager.startAdvertising()

        XCTAssertFalse(mockPM.addedServices.isEmpty, "addService must be called")
        XCTAssertTrue(mockPM.startAdvertisingCalled, "startAdvertising must be called")
        XCTAssertEqual(mockPM.addedServices.first?.uuid, BLEConstants.serviceUUID)
    }

    func testPoweredOffStateDoesNotTriggerAdvertising() {
        mockPM.reset()
        mockPM.state = .poweredOff

        bleManager.startAdvertising()

        XCTAssertTrue(mockPM.addedServices.isEmpty, "should not add service when not powered on")
        XCTAssertFalse(mockPM.startAdvertisingCalled, "should not start advertising when not powered on")
    }
}

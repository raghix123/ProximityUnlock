import Foundation
@testable import ProximityUnlockMac

/// Mock BLE central manager for unit tests.
/// M7+: BLE is RSSI-only — no command writing. The mock satisfies the BLECentralManaging
/// protocol (which is now empty). Command assertions use MockMultipeerManager instead.
class MockBLECentralManager: BLECentralManaging {}

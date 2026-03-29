import CoreBluetooth

/// BLE UUIDs shared between the iOS and Mac apps.
/// M7+: BLE is RSSI-only. Only the service UUID is needed for advertisement/discovery.
enum BLEConstants {
    /// Primary service UUID the iPhone advertises and the Mac scans for.
    /// The Mac connects to this service to read RSSI for proximity sensing.
    static let serviceUUID = CBUUID(string: "5F0A4A6E-9DC4-4C57-9A8C-D8BF0B1B0FDE")
}

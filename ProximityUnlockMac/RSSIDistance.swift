import Foundation

enum RSSIDistance {
    // iPhone BLE TX power at 1 m; indoor path-loss exponent 2.5
    private static let txPower: Double = -59
    private static let n: Double = 2.5

    static func meters(from rssi: Int) -> Double {
        pow(10.0, (txPower - Double(rssi)) / (10 * n))
    }

    /// Returns all three units: "-65 dBm  ·  ~5 ft  ·  ~1.5 m"
    static func label(rssi: Int) -> String {
        let m = meters(from: rssi)
        let ft = m * 3.281
        return String(format: "%d dBm  ·  ~%.0f ft  ·  ~%.1f m", rssi, ft, m)
    }
}

import Foundation

enum RSSIDistance {
    // Measured RSSI of an iPhone advertising at 1 m; typical for BLE hardware per Bluetooth SIG guidance.
    private static let txPower: Double = -59
    // Indoor path-loss exponent: free space is 2.0; typical indoor walls/furniture push it toward 2.5–3.5.
    private static let pathLossExponent: Double = 2.5

    static func meters(from rssi: Int) -> Double {
        pow(10.0, (txPower - Double(rssi)) / (10 * pathLossExponent))
    }

    /// Returns all three units: "-65 dBm  ·  ~5 ft  ·  ~1.5 m"
    static func label(rssi: Int) -> String {
        let m = meters(from: rssi)
        let ft = m * 3.281
        return String(format: "%d dBm  ·  ~%.0f ft  ·  ~%.1f m", rssi, ft, m)
    }
}

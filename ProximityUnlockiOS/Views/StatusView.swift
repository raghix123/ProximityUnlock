import CoreBluetooth
import SwiftUI

struct StatusView: View {
    @EnvironmentObject var advertiser: ProximityAdvertiser
    @State private var pulsing = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(indicatorColor.opacity(0.15))
                    .frame(width: 110, height: 110)
                    .scaleEffect(pulsing ? 1.25 : 1.0)
                    .animation(
                        advertiser.isAdvertising
                            ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                            : .default,
                        value: pulsing
                    )

                Image(systemName: indicatorIcon)
                    .font(.system(size: 44))
                    .foregroundStyle(indicatorColor)
            }
            .onAppear { pulsing = advertiser.isAdvertising }
            .onChange(of: advertiser.isAdvertising) { advertising in
                pulsing = advertising
            }

            VStack(spacing: 4) {
                Text(advertiser.bluetoothStatusDescription)
                    .font(.title3.weight(.semibold))
                if advertiser.isMPCConnected {
                    Label(
                        advertiser.isPaired ? "Mac connected & paired" : "Mac connected (unpaired)",
                        systemImage: advertiser.isPaired ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.subheadline)
                    .foregroundStyle(advertiser.isPaired ? .green : .orange)

                    Label("Connected via Wi-Fi", systemImage: "wifi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var indicatorColor: Color {
        switch advertiser.bluetoothState {
        case .poweredOn:
            return advertiser.isMPCConnected ? (advertiser.isPaired ? .green : .orange) : .blue
        case .poweredOff, .unauthorized:
            return .red
        default:
            return .secondary
        }
    }

    private var indicatorIcon: String {
        switch advertiser.bluetoothState {
        case .poweredOn:
            return advertiser.isMPCConnected ? "iphone.and.arrow.forward" : "iphone.radiowaves.left.and.right"
        case .poweredOff:
            return "iphone.slash"
        case .unauthorized:
            return "lock.iphone"
        default:
            return "iphone"
        }
    }
}

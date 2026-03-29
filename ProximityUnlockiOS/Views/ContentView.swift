import SwiftUI

struct ContentView: View {
    @EnvironmentObject var advertiser: ProximityAdvertiser

    var body: some View {
        NavigationStack {
            List {
                // MARK: Status hero
                Section {
                    StatusView()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                // MARK: Pairing section
                if !advertiser.isPaired {
                    Section {
                        if case .pairing(let phase) = advertiser.pairingManager.pairingState {
                            PairingInProgressView(phase: phase)
                        } else {
                            Label("Not paired with any Mac", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Pairing starts automatically when your Mac is nearby. Open the Mac app to begin.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Pairing")
                    }
                }

                // MARK: Pending unlock request (inline, no modal)
                if advertiser.pendingUnlockRequest {
                    Section {
                        Button {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            advertiser.approve()
                        } label: {
                            Label("Unlock Mac", systemImage: "lock.open.fill")
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.white)
                                .fontWeight(.semibold)
                                .padding(.vertical, 2)
                        }
                        .listRowBackground(Color.green)

                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            advertiser.deny()
                        } label: {
                            Label("Deny", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 2)
                        }
                    } header: {
                        Label("Mac Unlock Request", systemImage: "iphone.and.arrow.forward")
                            .foregroundStyle(.orange)
                    }
                }

                // MARK: Manual Lock / Unlock (only when paired + connected)
                if advertiser.isMPCConnected && advertiser.isPaired {
                    Section {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            advertiser.unlockMac()
                        } label: {
                            Label("Unlock Mac", systemImage: "lock.open.fill")
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.white)
                                .fontWeight(.semibold)
                                .padding(.vertical, 2)
                        }
                        .listRowBackground(Color.green)

                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            advertiser.lockMac()
                        } label: {
                            Label("Lock Mac", systemImage: "lock.fill")
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.white)
                                .fontWeight(.semibold)
                                .padding(.vertical, 2)
                        }
                        .listRowBackground(Color.orange)
                    } header: {
                        HStack {
                            Text("Mac Controls")
                            Spacer()
                            Text("(via Wi-Fi)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: Controls
                Section("Advertising") {
                    Toggle("Enable ProximityUnlock", isOn: $advertiser.isEnabled)
                    Toggle("Require confirmation to unlock", isOn: $advertiser.requiresConfirmation)
                        .onChange(of: advertiser.requiresConfirmation) { _, new in
                            advertiser.confirmationManager.requiresConfirmation = new
                        }
                    if !advertiser.requiresConfirmation {
                        Picker("Auto-approve if authenticated within", selection: Binding(
                            get: { advertiser.confirmationManager.recencyWindowSeconds },
                            set: { advertiser.confirmationManager.recencyWindowSeconds = $0 }
                        )) {
                            Text("30 seconds").tag(30.0)
                            Text("1 minute").tag(60.0)
                            Text("2 minutes").tag(120.0)
                            Text("5 minutes").tag(300.0)
                            Text("Always prompt").tag(0.0)
                        }
                        .pickerStyle(.menu)
                        Text("FaceID/passcode required on every unlock when \"Always prompt\" is selected.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Paired device
                if advertiser.isPaired,
                   let peerName = SecureKeyStore.shared.getPairedPeerDisplayName() {
                    Section("Paired Device") {
                        LabeledContent("Device", value: peerName)
                        Button("Unpair", role: .destructive) {
                            advertiser.pairingManager.unpair()
                        }
                    }
                }

                // MARK: Bluetooth
                Section("Bluetooth") {
                    LabeledContent("Status") {
                        Text(advertiser.bluetoothStatusDescription)
                            .foregroundStyle(advertiser.bluetoothState == .poweredOn ? .green : .red)
                    }
                    if advertiser.bluetoothState == .unauthorized {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }

                // MARK: How it works
                Section("How It Works") {
                    Label("Keep this app open or running in the background.", systemImage: "1.circle.fill")
                    Label("Make sure Bluetooth and Wi-Fi are enabled on both devices.", systemImage: "2.circle.fill")
                    Label("Walk near your Mac — it detects you via Bluetooth RSSI and unlocks via Wi-Fi.", systemImage: "3.circle.fill")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .navigationTitle("ProximityUnlock")
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

// MARK: - Pairing In-Progress Subview

private struct PairingInProgressView: View {
    @EnvironmentObject var advertiser: ProximityAdvertiser
    let phase: PairingPhase

    var body: some View {
        switch phase {
        case .waitingForPeer, .exchangingKeys:
            HStack(spacing: 12) {
                ProgressView()
                Text("Exchanging keys with Mac…")
                    .foregroundStyle(.secondary)
            }
        case .displayingCode(let code):
            PairingCodeConfirmView(code: code, pairingManager: advertiser.pairingManager)
        case .confirming, .deriving:
            HStack(spacing: 12) {
                ProgressView()
                Text("Confirming pairing…")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Pairing Code Confirm View

private struct PairingCodeConfirmView: View {
    let code: String
    let pairingManager: PairingManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Confirm pairing code", systemImage: "lock.shield")
                .font(.headline)
            Text("Compare this code with your Mac and tap Confirm if they match.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formatCode(code))
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.vertical, 4)
            HStack(spacing: 12) {
                Button("Confirm") {
                    pairingManager.confirmCode()
                }
                .buttonStyle(.borderedProminent)
                Button("Cancel", role: .destructive) {
                    pairingManager.cancelPairing()
                }
            }
        }
    }

    private func formatCode(_ code: String) -> String {
        let clean = code.filter { $0.isNumber }
        guard clean.count == 6 else { return code }
        return String(clean.prefix(3)) + " " + String(clean.suffix(3))
    }
}

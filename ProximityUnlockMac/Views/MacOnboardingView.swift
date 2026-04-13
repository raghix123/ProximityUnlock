import SwiftUI
import AppKit

struct MacOnboardingView: View {
    @ObservedObject var monitor: ProximityMonitor
    let onComplete: () -> Void
    @State private var currentStep = 0

    private var pairingManager: PairingManager? {
        (monitor.multipeerManager as? MultipeerManager)?.pairingManager
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome to ProximityUnlock")
                    .font(.title.bold())
                Text("Set up proximity-based Mac unlock")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()

            // Content area
            VStack(alignment: .leading, spacing: 16) {
                if currentStep == 0 {
                    Step0Welcome()
                } else if currentStep == 1 {
                    Step1Accessibility()
                } else if currentStep == 2 {
                    Step2Pairing(pairingManager: pairingManager)
                } else if currentStep == 3 {
                    Step3Password(pairingManager: pairingManager)
                } else {
                    Step4Done()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            Divider()

            // Footer
            HStack(spacing: 12) {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                }
                Spacer()
                if currentStep < 4 {
                    Button("Skip") { onComplete() }
                        .foregroundStyle(.secondary)
                    Button(currentStep < 4 ? "Next" : "Get Started") {
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") { onComplete() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 500, height: 520)
    }
}

// MARK: - Step 0: Welcome

private struct Step0Welcome: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "lock.iphone")
                    .font(.system(size: 32))
                    .foregroundStyle(.blue)
                    .frame(width: 48, height: 48)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart Proximity Detection")
                        .font(.headline)
                    Text("Your Mac unlocks automatically when your iPhone gets close.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(
                    icon: "iphone.radiowaves.left.and.right",
                    color: .blue,
                    title: "Bluetooth Sensing",
                    description: "Low-energy Bluetooth detects proximity"
                )
                FeatureRow(
                    icon: "faceid",
                    color: .green,
                    title: "Biometric Protection",
                    description: "Face ID approves each unlock"
                )
                FeatureRow(
                    icon: "wifi",
                    color: .purple,
                    title: "Secure & Private",
                    description: "Everything stays on your local network"
                )
            }
        }
    }
}

// MARK: - Step 1: Accessibility Permissions

private struct Step1Accessibility: View {
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var checkTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Grant Accessibility Permission")
                .font(.headline)
            Text("Required to monitor lock state and unlock your Mac:")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                VStack {
                    if accessibilityGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "lock.shield.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                }
                .frame(width: 36, height: 36)
                .background(accessibilityGranted ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Accessibility")
                        .font(.subheadline.weight(.semibold))
                    if accessibilityGranted {
                        Text("Granted")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("Required for automatic unlock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if !accessibilityGranted {
                    Button(action: requestAccessibility) {
                        Text("Enable")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            Text("macOS will show an authentication dialog. Tap 'OK' and enter your password to grant access.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task {
            checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                accessibilityGranted = AXIsProcessTrusted()
            }
        }
        .onDisappear {
            checkTimer?.invalidate()
        }
    }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}

// MARK: - Step 2: Live Pairing

private struct Step2Pairing: View {
    let pairingManager: PairingManager?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pair Your iPhone")
                .font(.headline)
            Text("Bring your iPhone close to this Mac:")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let pm = pairingManager {
                LivePairingView(pairingManager: pm)
            } else {
                Text("Pairing manager unavailable")
                    .foregroundStyle(.red)
            }

            Spacer()

            Text("A 6-digit code will appear on both screens. Verify they match and confirm on both devices.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct LivePairingView: View {
    @ObservedObject var pairingManager: PairingManager

    var body: some View {
        switch pairingManager.pairingState {
        case .unpaired:
            HStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.8)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Searching for iPhone")
                        .font(.subheadline.weight(.semibold))
                    Text("Make sure ProximityUnlock is installed on your iPhone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

        case .pairing(let phase):
            switch phase {
            case .waitingForPeer, .exchangingKeys:
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Connecting…")
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            case .displayingCode(let code):
                VStack(alignment: .leading, spacing: 12) {
                    Label("Verify the code matches your iPhone", systemImage: "lock.shield")
                        .font(.subheadline.weight(.semibold))

                    Text(formatCode(code))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .tracking(4)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color(.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    HStack(spacing: 12) {
                        Button("Confirm") { pairingManager.confirmCode() }
                            .buttonStyle(.borderedProminent)
                        Button("Cancel", role: .destructive) { pairingManager.cancelPairing() }
                    }
                }

            case .confirming, .deriving:
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Completing pairing…")
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

        case .paired(let peerName):
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paired with \(peerName)")
                        .font(.subheadline.weight(.semibold))
                    Text("Ready to proceed to the next step")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }

        if let error = pairingManager.pairingError {
            Label(error, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
                .padding(12)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func formatCode(_ code: String) -> String {
        let clean = code.filter { $0.isNumber }
        guard clean.count == 6 else { return code }
        return String(clean.prefix(3)) + " " + String(clean.suffix(3))
    }
}

// MARK: - Step 3: Password

private struct Step3Password: View {
    let pairingManager: PairingManager?
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var passwordMismatch = false
    @State private var showPasswordEntry = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Login Password (Optional)")
                .font(.headline)

            if pairingManager?.isPaired == true {
                Text("Save your Mac login password for automatic unlock:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if showPasswordEntry {
                    VStack(spacing: 12) {
                        SecureField("Mac password", text: $password)
                            .textFieldStyle(.roundedBorder)
                        SecureField("Confirm password", text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)

                        if passwordMismatch {
                            Label("Passwords do not match", systemImage: "xmark.circle")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }

                        HStack(spacing: 12) {
                            Button("Save") { savePassword() }
                                .buttonStyle(.borderedProminent)
                            Button("Cancel") {
                                password = ""
                                confirmPassword = ""
                                passwordMismatch = false
                                showPasswordEntry = false
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Button(action: { showPasswordEntry = true }) {
                        HStack {
                            Image(systemName: "lock.fill")
                            Text("Save Password")
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Text("Your password is stored securely in the system Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("Pair your iPhone first", systemImage: "lock.iphone")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("You can add a password later in Settings after pairing is complete.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func savePassword() {
        guard password == confirmPassword else {
            passwordMismatch = true
            return
        }
        KeychainHelper.shared.savePassword(password)
        password = ""
        confirmPassword = ""
        passwordMismatch = false
        showPasswordEntry = false
    }
}

// MARK: - Step 4: Complete

private struct Step4Done: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.green)
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text("You're all set!")
                        .font(.headline)
                    Text("ProximityUnlock is ready")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                ChecklistItem(title: "Walk away", description: "Mac locks when iPhone moves away")
                ChecklistItem(title: "Walk back", description: "iPhone prompts to unlock")
                ChecklistItem(title: "Approve", description: "Mac unlocks after Face ID")
            }

            Spacer()

            Text("Adjust sensitivity and settings from the menu bar icon anytime.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Shared Components

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ChecklistItem: View {
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

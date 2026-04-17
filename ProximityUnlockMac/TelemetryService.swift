import Foundation
import TelemetryClient

/// Thin wrapper around TelemetryDeck. All signals are anonymous — no device names,
/// no passwords, no hardware identifiers. Users can opt out in Settings → About.
@MainActor
enum TelemetryService {

    private static let appID = "14838AA9-45A6-4C7D-8EF0-FA51897AACDE"

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "telemetryEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "telemetryEnabled") }
    }

    static func start() {
        var config = TelemetryManagerConfiguration(appID: appID)
        config.analyticsDisabled = !isEnabled
        TelemetryManager.initialize(with: config)
    }

    static func signal(_ name: String, parameters: [String: String] = [:]) {
        guard isEnabled else { return }
        TelemetryManager.send(name, with: parameters)
    }

    // MARK: - Named events

    static func appLaunched() {
        signal("app.launched")
    }

    static func proximityLocked() {
        signal("proximity.locked")
    }

    static func proximityUnlocked() {
        signal("proximity.unlocked")
    }

    static func deviceSelected() {
        signal("device.selected")
    }

    static func settingToggled(_ key: String, value: Bool) {
        signal("setting.toggled", parameters: ["key": key, "value": value ? "true" : "false"])
    }

    static func updateCheckTriggered(manual: Bool) {
        signal("update.check", parameters: ["manual": manual ? "true" : "false"])
    }

    static func onboardingCompleted() {
        signal("onboarding.completed")
    }

    static func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        // Inform TelemetryDeck of the opt-out so it stops queuing signals.
        var config = TelemetryManagerConfiguration(appID: appID)
        config.analyticsDisabled = !enabled
        TelemetryManager.initialize(with: config)
    }
}

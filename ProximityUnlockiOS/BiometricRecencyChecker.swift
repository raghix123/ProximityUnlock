import Foundation
import LocalAuthentication

/// Protocol for biometric recency checking — injectable for testing.
protocol BiometricChecking {
    func checkRecency(withinSeconds seconds: TimeInterval, completion: @escaping (Bool) -> Void)
}

/// Checks if the device owner authenticated within a configurable window using LAContext.
/// Uses `touchIDAuthenticationAllowableReuseDuration` so any recent device unlock
/// (FaceID, TouchID, or passcode) counts — no visible prompt within the reuse window.
/// Falls back to an explicit prompt if the window has expired.
class BiometricRecencyChecker: BiometricChecking {

    func checkRecency(withinSeconds seconds: TimeInterval, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        // If user authenticated within `seconds`, evaluatePolicy succeeds silently.
        context.touchIDAuthenticationAllowableReuseDuration = min(
            seconds,
            LATouchIDAuthenticationMaximumAllowableReuseDuration  // 300s cap
        )

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode configured — cannot safely auto-approve.
            Log.unlock.warning("Biometric check unavailable: \(error?.localizedDescription ?? "no passcode", privacy: .public)")
            completion(false)
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Verify your identity to unlock your Mac"
        ) { success, evaluateError in
            if let err = evaluateError {
                Log.unlock.info("Biometric recency check result: \(success, privacy: .public), error: \(err.localizedDescription, privacy: .public)")
            } else {
                Log.unlock.info("Biometric recency check result: \(success, privacy: .public) (silent reuse)")
            }
            DispatchQueue.main.async { completion(success) }
        }
    }
}

import Foundation
@testable import ProximityUnlockiOS

/// Test double for BiometricChecking — synchronously returns a pre-configured result.
class MockBiometricChecker: BiometricChecking {

    /// Result that will be returned on the next `checkRecency` call.
    var shouldPass: Bool = true

    /// Number of times `checkRecency` has been called.
    private(set) var callCount: Int = 0

    /// Last `withinSeconds` value passed to `checkRecency`.
    private(set) var lastWindowSeconds: TimeInterval?

    func checkRecency(withinSeconds seconds: TimeInterval, completion: @escaping (Bool) -> Void) {
        callCount += 1
        lastWindowSeconds = seconds
        completion(shouldPass)
    }
}

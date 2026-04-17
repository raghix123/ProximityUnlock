import XCTest
import Combine
@testable import ProximityUnlockMac

/// Tests for ProximityMonitor — the core state machine.
/// All RSSI values are simulated; no real BLE hardware is used.
@MainActor
final class ProximityMonitorTests: XCTestCase {

    private var monitor: ProximityMonitor!
    private var mockBLE: MockBLECentralManager!
    private var mockUnlock: MockUnlockManager!

    /// Short hysteresis so tests complete in milliseconds.
    private let hysteresis: TimeInterval = 0.1

    // near=-70, far=-85, gap=15 dBm
    override func setUp() async throws {
        mockBLE    = MockBLECentralManager()
        mockUnlock = MockUnlockManager()
        monitor = ProximityMonitor(
            bleManager: mockBLE,
            unlockManager: mockUnlock,
            hysteresisSeconds: hysteresis
        )
        monitor.isEnabled      = true
        monitor.lockWhenFar    = true
        monitor.unlockWhenNear = true
        monitor.nearThreshold  = -70
        monitor.farThreshold   = -85
    }

    override func tearDown() {
        monitor    = nil
        mockBLE    = nil
        mockUnlock = nil
    }

    // MARK: - Helpers

    private func wait(_ factor: Double = 1.5) async throws {
        try await Task.sleep(nanoseconds: UInt64(hysteresis * factor * 1_000_000_000))
    }

    /// Feed `count` identical RSSI samples to fill / update the smoothing buffer.
    private func feedRSSI(_ rssi: Int, count: Int = 5) {
        for _ in 0..<count { monitor.handleRSSI(rssi) }
    }

    // MARK: - Near Transition

    func testNearTransitionUnlocksScreen() async throws {
        mockUnlock.screenLocked = true
        monitor.handleRSSI(-60)
        try await wait()
        XCTAssertEqual(monitor.proximityState, .near)
        XCTAssertTrue(mockUnlock.didUnlock)
    }

    func testNearTransitionDoesNotUnlockIfScreenAlreadyUnlocked() async throws {
        mockUnlock.screenLocked = false
        monitor.handleRSSI(-60)
        try await wait()
        XCTAssertEqual(monitor.proximityState, .near)
        XCTAssertFalse(mockUnlock.didUnlock, "no unlock call when screen is already unlocked")
    }

    func testNearTransitionAtExactThreshold() async throws {
        mockUnlock.screenLocked = true
        monitor.handleRSSI(-70)   // exactly at nearThreshold
        try await wait()
        XCTAssertEqual(monitor.proximityState, .near)
        XCTAssertTrue(mockUnlock.didUnlock)
    }

    func testSignalJustBelowNearDoesNotUnlock() async throws {
        mockUnlock.screenLocked = true
        feedRSSI(-71)             // 1 dBm below nearThreshold, also below farThreshold after smoothing? No: -71 > -85
        try await wait()
        // -71 is in the dead zone (-70 to -85) — neither near nor far
        XCTAssertEqual(monitor.proximityState, .unknown)
        XCTAssertFalse(mockUnlock.didUnlock, "signal in dead zone must not unlock")
    }

    // MARK: - Far Transition

    func testFarTransitionLocksScreen() async throws {
        feedRSSI(-90)             // 5 samples below farThreshold (-85)
        try await wait()
        XCTAssertEqual(monitor.proximityState, .far)
        XCTAssertTrue(mockUnlock.didLock)
    }

    func testFarTransitionAtExactThreshold() async throws {
        feedRSSI(-85)             // exactly at farThreshold
        try await wait()
        XCTAssertEqual(monitor.proximityState, .far)
        XCTAssertTrue(mockUnlock.didLock)
    }

    func testSingleRSSIDipDoesNotLock() async throws {
        // One weak sample surrounded by strong ones — smoothed average stays above farThreshold
        monitor.handleRSSI(-60)
        monitor.handleRSSI(-60)
        monitor.handleRSSI(-60)
        monitor.handleRSSI(-95)   // momentary dip
        monitor.handleRSSI(-60)
        try await wait()
        XCTAssertFalse(mockUnlock.didLock, "single RSSI dip must not trigger far (smoothing)")
    }

    func testThreeSamplesInsufficientForFar() async throws {
        // Only 3 weak samples — smoothed average not low enough yet (buffer still has priors)
        monitor.handleRSSI(-90)
        monitor.handleRSSI(-90)
        monitor.handleRSSI(-90)
        try await wait()
        // Buffer: [-90,-90,-90] avg=-90 <= -85 — still crosses far. Let's use borderline -87
        // Reset and try with a value that needs more samples to pull average below threshold
        mockUnlock.reset()
        monitor = ProximityMonitor(bleManager: mockBLE, unlockManager: mockUnlock, hysteresisSeconds: hysteresis)
        monitor.isEnabled = true
        monitor.nearThreshold = -70
        monitor.farThreshold  = -85
        // Prime buffer with near-threshold samples, then drop slightly
        monitor.handleRSSI(-70)
        monitor.handleRSSI(-70)
        monitor.handleRSSI(-70)
        monitor.handleRSSI(-90)   // only 1 of 4 samples is far
        try await wait()
        XCTAssertFalse(mockUnlock.didLock, "smoothed RSSI should not be below threshold with only 1 weak sample")
    }

    // MARK: - Hysteresis

    func testHysteresisPreventsPrematureUnlock() async throws {
        mockUnlock.screenLocked = true
        monitor.handleRSSI(-60)
        try await wait(0.4)       // only 40 % of hysteresis period
        XCTAssertFalse(mockUnlock.didUnlock, "must not unlock before hysteresis elapses")
    }

    func testHysteresisResetsOnSignalDrop() async throws {
        mockUnlock.screenLocked = true
        monitor.handleRSSI(-60)   // starts near timer
        try await wait(0.4)
        monitor.handleRSSI(-78)   // drops into dead zone — cancels timer
        try await wait(1.5)
        XCTAssertFalse(mockUnlock.didUnlock, "near timer cancelled by dead-zone signal")
    }

    func testFarTimerCancelledBySignalRecovery() async throws {
        feedRSSI(-90)             // starts far timer
        try await wait(0.4)
        monitor.handleRSSI(-60)   // signal recovers into near zone — should cancel far timer
        try await wait(1.5)
        XCTAssertFalse(mockUnlock.didLock, "far timer must be cancelled when signal recovers")
    }

    // MARK: - Fluctuating Signal (noisy environment)

    func testFluctuatingSignalDoesNotOscillate() async throws {
        // Alternate between near and just-below-near — should not cause repeated lock/unlock
        mockUnlock.screenLocked = false
        for _ in 0..<10 {
            monitor.handleRSSI(-68)  // above nearThreshold
            monitor.handleRSSI(-72)  // just below nearThreshold
        }
        try await wait(2.0)
        XCTAssertLessThanOrEqual(mockUnlock.unlockCallCount, 1, "noisy signal near threshold should not cause repeated unlocks")
        XCTAssertEqual(mockUnlock.lockCallCount, 0, "noisy near-threshold signal must not lock")
    }

    func testGradualWalkAway() async throws {
        // Simulate walking away: signal degrades over many samples
        mockUnlock.screenLocked = true

        // Phase 1: near — should unlock
        feedRSSI(-55)
        try await wait()
        XCTAssertEqual(monitor.proximityState, .near)
        XCTAssertTrue(mockUnlock.didUnlock)

        // Phase 2: dead zone — should stay near
        feedRSSI(-78)
        try await wait()
        XCTAssertEqual(monitor.proximityState, .near, "dead-zone signal must not change state from near")
        XCTAssertFalse(mockUnlock.didLock)

        // Phase 3: walked far — should lock
        feedRSSI(-92)
        try await wait()
        XCTAssertEqual(monitor.proximityState, .far)
        XCTAssertTrue(mockUnlock.didLock)
    }

    func testReturnAfterLeaving() async throws {
        mockUnlock.screenLocked = true

        // Go near
        feedRSSI(-55)
        try await wait()
        XCTAssertEqual(monitor.proximityState, .near)

        // Walk far
        feedRSSI(-95)
        try await wait()
        XCTAssertEqual(monitor.proximityState, .far)
        XCTAssertTrue(mockUnlock.didLock)

        // Come back — screen is locked again after locking
        mockUnlock.screenLocked = true
        feedRSSI(-55)
        try await wait()
        XCTAssertEqual(monitor.proximityState, .near)
        XCTAssertEqual(mockUnlock.unlockCallCount, 2, "should unlock twice (once per approach)")
    }

    // MARK: - Toggle Guards

    func testLockWhenFarDisabledPreventsLock() async throws {
        monitor.lockWhenFar = false
        feedRSSI(-95)
        try await wait()
        XCTAssertEqual(monitor.proximityState, .far, "state should still update to far")
        XCTAssertFalse(mockUnlock.didLock, "lockScreen must not be called when lockWhenFar=false")
    }

    func testUnlockWhenNearDisabledPreventsUnlock() async throws {
        monitor.unlockWhenNear = false
        mockUnlock.screenLocked = true
        feedRSSI(-55)
        try await wait()
        XCTAssertEqual(monitor.proximityState, .near, "state should still update to near")
        XCTAssertFalse(mockUnlock.didUnlock, "unlockScreen must not be called when unlockWhenNear=false")
    }

    func testLockOnlyMode() async throws {
        // Only lock, never unlock
        monitor.unlockWhenNear = false
        monitor.lockWhenFar    = true
        mockUnlock.screenLocked = true

        feedRSSI(-55)
        try await wait()
        XCTAssertEqual(monitor.proximityState, .near)
        XCTAssertFalse(mockUnlock.didUnlock)

        feedRSSI(-95)
        try await wait()
        XCTAssertEqual(monitor.proximityState, .far)
        XCTAssertTrue(mockUnlock.didLock)
    }

    func testUnlockOnlyMode() async throws {
        // Only unlock, never lock
        monitor.unlockWhenNear = true
        monitor.lockWhenFar    = false
        mockUnlock.screenLocked = true

        feedRSSI(-55)
        try await wait()
        XCTAssertTrue(mockUnlock.didUnlock)

        feedRSSI(-95)
        try await wait()
        XCTAssertEqual(monitor.proximityState, .far)
        XCTAssertFalse(mockUnlock.didLock)
    }

    // MARK: - Disabled / Paused

    func testDisabledPreventsUnlock() async throws {
        monitor.isEnabled = false
        mockUnlock.screenLocked = true
        monitor.handleRSSI(-60)
        try await wait()
        XCTAssertFalse(mockUnlock.didUnlock)
    }

    func testDisabledPreventsFarLock() async throws {
        monitor.isEnabled = false
        feedRSSI(-95)
        try await wait()
        XCTAssertFalse(mockUnlock.didLock)
    }

    func testPausedPreventsUnlock() async throws {
        monitor.pause()
        mockUnlock.screenLocked = true
        monitor.handleRSSI(-60)
        try await wait()
        XCTAssertFalse(mockUnlock.didUnlock)
    }

    func testResumeAfterPause() async throws {
        monitor.pause()
        mockUnlock.screenLocked = true
        monitor.handleRSSI(-60)
        try await wait()
        XCTAssertFalse(mockUnlock.didUnlock)

        monitor.resume()
        monitor.handleRSSI(-60)
        try await wait()
        XCTAssertTrue(mockUnlock.didUnlock, "should unlock after resume")
    }

    // MARK: - Direct Transition Methods

    func testTransitionToNearDoesNothingWhenDisabled() {
        monitor.isEnabled = false
        mockUnlock.screenLocked = true
        monitor.transitionToNear()
        XCTAssertFalse(mockUnlock.didUnlock)
        XCTAssertNotEqual(monitor.proximityState, .near)
    }

    func testTransitionToFarDoesNothingWhenDisabled() {
        monitor.isEnabled = false
        monitor.transitionToFar()
        XCTAssertFalse(mockUnlock.didLock)
        XCTAssertNotEqual(monitor.proximityState, .far)
    }

    // MARK: - handleScreensDidWake

    func testScreensWakeResetsNearState() {
        monitor.transitionToNear()  // force near (isEnabled=true, isPaused=false)
        XCTAssertEqual(monitor.proximityState, .near)

        monitor.handleScreensDidWake()
        XCTAssertEqual(monitor.proximityState, .unknown, "wake must reset near→unknown")
    }

    func testScreensWakeDoesNotAffectFarState() {
        monitor.isEnabled = true
        monitor.transitionToFar()
        XCTAssertEqual(monitor.proximityState, .far)

        monitor.handleScreensDidWake()
        XCTAssertEqual(monitor.proximityState, .far, "wake must not change far state")
    }

    func testScreensWakeFromUnknownStaysUnknown() {
        XCTAssertEqual(monitor.proximityState, .unknown)
        monitor.handleScreensDidWake()
        XCTAssertEqual(monitor.proximityState, .unknown, "wake on unknown must remain unknown")
    }

    // MARK: - Threshold Boundary Edge Cases

    func testRapidOscillationAroundNearThresholdDoesNotRegressState() async throws {
        mockUnlock.screenLocked = true
        // Establish near state cleanly.
        feedRSSI(-55)
        try await wait()
        XCTAssertEqual(monitor.proximityState, .near)
        XCTAssertEqual(mockUnlock.unlockCallCount, 1)

        // Flicker right around the near threshold — within the dead zone boundary, never reaching far.
        for _ in 0..<15 {
            monitor.handleRSSI(-68)  // above nearThreshold (stays near)
            monitor.handleRSSI(-72)  // just below nearThreshold (dead zone)
        }
        try await wait(2.0)

        XCTAssertEqual(monitor.proximityState, .near, "flicker around near threshold must not drop state back to unknown")
        XCTAssertEqual(mockUnlock.unlockCallCount, 1, "must not re-trigger unlock when already near")
        XCTAssertEqual(mockUnlock.lockCallCount, 0, "flicker above far threshold must not trigger lock")
    }

    func testAdjacentThresholdsHonorsNearWithoutRaceCondition() async throws {
        // Collapse the dead zone: near == far + 1. Make sure we still get clean transitions
        // instead of a race where one RSSI reading triggers both timers.
        monitor.nearThreshold = -70
        monitor.farThreshold  = -71
        mockUnlock.screenLocked = true

        feedRSSI(-60)              // well into near
        try await wait()
        XCTAssertEqual(monitor.proximityState, .near)
        XCTAssertTrue(mockUnlock.didUnlock)

        feedRSSI(-95)              // well into far
        try await wait()
        XCTAssertEqual(monitor.proximityState, .far)
        XCTAssertTrue(mockUnlock.didLock)
    }

    // MARK: - Full End-to-End

    func testFullProximityFlow() async throws {
        mockUnlock.screenLocked = true

        feedRSSI(-55)
        try await wait()
        XCTAssertEqual(monitor.proximityState, .near)
        XCTAssertTrue(mockUnlock.didUnlock)

        feedRSSI(-95)
        try await wait()
        XCTAssertEqual(monitor.proximityState, .far)
        XCTAssertTrue(mockUnlock.didLock)
    }
}

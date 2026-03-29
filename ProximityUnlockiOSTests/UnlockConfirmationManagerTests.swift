import XCTest
@testable import ProximityUnlockiOS

/// Tests for UnlockConfirmationManager — the confirmation handshake and notification logic.
/// M8+: Biometric recency checking integrated. Tests use MockBiometricChecker for deterministic results.
@MainActor
final class UnlockConfirmationManagerTests: XCTestCase {

    private var confirmManager: UnlockConfirmationManager!
    private var mockNC: MockNotificationCenter!
    private var mockBiometric: MockBiometricChecker!
    private var confirmationsSent: [Bool] = []

    override func setUp() async throws {
        mockNC = MockNotificationCenter()
        mockBiometric = MockBiometricChecker()
        confirmManager = UnlockConfirmationManager(notificationCenter: mockNC, biometricChecker: mockBiometric)
        confirmManager.requiresConfirmation = true
        confirmManager.recencyWindowSeconds = 120
        // Track confirmations sent via MPC
        confirmManager.onConfirmationSent = { [weak self] approved in
            self?.confirmationsSent.append(approved)
        }
    }

    override func tearDown() {
        confirmManager = nil
        mockNC = nil
        mockBiometric = nil
        confirmationsSent = []
    }

    // MARK: - Auto-Approve With Biometric Recency Check

    func testAutoApproveWhenBiometricPasses() {
        confirmManager.requiresConfirmation = false
        mockBiometric.shouldPass = true

        confirmManager.receiveUnlockRequest()

        XCTAssertFalse(confirmManager.pendingRequest, "pendingRequest must not be set when biometric passes")
        XCTAssertFalse(mockNC.notificationFired, "no notification should be fired when biometric passes")
        XCTAssertEqual(confirmationsSent, [true], "biometric-pass must send 'approved' via MPC")
        XCTAssertEqual(mockBiometric.callCount, 1)
        XCTAssertEqual(mockBiometric.lastWindowSeconds, 120)
    }

    func testAutoApproveUsesConfiguredRecencyWindow() {
        confirmManager.requiresConfirmation = false
        confirmManager.recencyWindowSeconds = 60
        mockBiometric.shouldPass = true

        confirmManager.receiveUnlockRequest()

        XCTAssertEqual(mockBiometric.lastWindowSeconds, 60, "recencyWindowSeconds must be passed to biometric checker")
    }

    func testBiometricFailFallsBackToManualUI() {
        confirmManager.requiresConfirmation = false
        mockBiometric.shouldPass = false

        confirmManager.receiveUnlockRequest()

        XCTAssertTrue(confirmManager.pendingRequest, "pendingRequest must be set when biometric fails")
        XCTAssertTrue(mockNC.notificationFired, "notification must be fired on biometric failure")
        XCTAssertTrue(confirmationsSent.isEmpty, "no confirmation must be sent automatically when biometric fails")
    }

    func testBiometricNotCalledWhenRequiresConfirmationIsTrue() {
        confirmManager.requiresConfirmation = true

        confirmManager.receiveUnlockRequest()

        XCTAssertEqual(mockBiometric.callCount, 0, "biometric checker must not be called in manual confirmation mode")
        XCTAssertTrue(confirmManager.pendingRequest)
    }

    // MARK: - Confirmation Required Sets Pending Request

    func testConfirmationRequiredSetsPendingRequest() {
        confirmManager.requiresConfirmation = true
        confirmManager.receiveUnlockRequest()

        XCTAssertTrue(confirmManager.pendingRequest)
        XCTAssertTrue(mockNC.notificationFired)
    }

    // MARK: - Notification Firing

    func testNotificationFiredWhenConfirmationRequired() {
        confirmManager.requiresConfirmation = true
        confirmManager.receiveUnlockRequest()

        XCTAssertTrue(mockNC.notificationFired)
        XCTAssertTrue(confirmManager.pendingRequest)
        XCTAssertEqual(mockNC.lastRequest?.identifier, "com.raghav.ProximityUnlock.unlockRequest")
    }

    // MARK: - Approve / Deny

    func testApproveClears() {
        confirmManager.receiveUnlockRequest()
        XCTAssertTrue(confirmManager.pendingRequest)

        confirmManager.approve()
        XCTAssertFalse(confirmManager.pendingRequest)
    }

    func testDenyClears() {
        confirmManager.receiveUnlockRequest()
        XCTAssertTrue(confirmManager.pendingRequest)

        confirmManager.deny()
        XCTAssertFalse(confirmManager.pendingRequest)
    }

    func testApproveSendsConfirmationViaMPC() {
        confirmManager.receiveUnlockRequest()
        confirmManager.approve()

        XCTAssertEqual(confirmationsSent, [true], "approve must fire onConfirmationSent(true)")
    }

    func testDenySendsConfirmationViaMPC() {
        confirmManager.receiveUnlockRequest()
        confirmManager.deny()

        XCTAssertEqual(confirmationsSent, [false], "deny must fire onConfirmationSent(false)")
    }

    func testApproveCancelsNotification() {
        confirmManager.receiveUnlockRequest()
        confirmManager.approve()

        XCTAssertTrue(
            mockNC.removedPendingIdentifiers.contains("com.raghav.ProximityUnlock.unlockRequest")
        )
    }

    func testDenyCancelsNotification() {
        confirmManager.receiveUnlockRequest()
        confirmManager.deny()

        XCTAssertTrue(
            mockNC.removedPendingIdentifiers.contains("com.raghav.ProximityUnlock.unlockRequest")
        )
    }

    // MARK: - Lock Event

    func testLockEventClearsPendingRequest() {
        confirmManager.receiveUnlockRequest()
        XCTAssertTrue(confirmManager.pendingRequest)

        confirmManager.receiveLockEvent()
        XCTAssertFalse(confirmManager.pendingRequest)
    }

    func testLockEventCancelsNotification() {
        confirmManager.receiveUnlockRequest()
        confirmManager.receiveLockEvent()

        XCTAssertTrue(
            mockNC.removedPendingIdentifiers.contains("com.raghav.ProximityUnlock.unlockRequest")
        )
    }

    // MARK: - Notification Permission

    func testRequestNotificationPermission() {
        confirmManager.requestNotificationPermission()
        XCTAssertTrue(mockNC.authorizationRequested)
        XCTAssertFalse(mockNC.categoriesSet.isEmpty, "notification categories must be registered")
    }
}

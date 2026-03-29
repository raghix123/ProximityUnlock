import XCTest
@testable import ProximityUnlockiOS

/// Tests for UnlockConfirmationManager — the confirmation handshake and notification logic.
/// M7+: No BLE dependency. Commands arrive via MPC; manager is tested by calling
/// receiveUnlockRequest() / receiveLockEvent() directly.
@MainActor
final class UnlockConfirmationManagerTests: XCTestCase {

    private var confirmManager: UnlockConfirmationManager!
    private var mockNC: MockNotificationCenter!
    private var confirmationsSent: [Bool] = []

    override func setUp() async throws {
        mockNC = MockNotificationCenter()
        confirmManager = UnlockConfirmationManager(notificationCenter: mockNC)
        confirmManager.requiresConfirmation = true
        // Track confirmations sent via MPC
        confirmManager.onConfirmationSent = { [weak self] approved in
            self?.confirmationsSent.append(approved)
        }
    }

    override func tearDown() {
        confirmManager = nil
        mockNC = nil
        confirmationsSent = []
    }

    // MARK: - Auto-Approve (No Confirmation Required)

    func testAutoApproveWhenConfirmationDisabled() {
        confirmManager.requiresConfirmation = false
        confirmManager.receiveUnlockRequest()

        XCTAssertFalse(confirmManager.pendingRequest, "pendingRequest must not be set when auto-approving")
        XCTAssertFalse(mockNC.notificationFired, "no notification should be fired when auto-approving")
        XCTAssertEqual(confirmationsSent, [true], "auto-approve must send 'approved' confirmation via MPC")
    }

    func testConfirmationRequiredSetssPendingRequest() {
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

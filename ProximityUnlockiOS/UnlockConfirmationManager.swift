import Foundation
import UserNotifications

/// Handles incoming unlock requests from the Mac and dispatches confirmations.
/// Supports in-app UI (via `pendingRequest`) and iOS notifications (background-safe).
/// M7+: Confirmations are sent exclusively via MPC — no BLE dependency.
@MainActor
class UnlockConfirmationManager: ObservableObject {

    @Published var pendingRequest: Bool = false
    @Published var requiresConfirmation: Bool = true {
        didSet { UserDefaults.standard.set(requiresConfirmation, forKey: "requiresConfirmation") }
    }

    private let notificationCenter: any NotificationCentering

    /// Called when a confirmation is sent so the caller can forward it via MPC.
    var onConfirmationSent: ((Bool) -> Void)?
    private let confirmNotificationId = "com.raghav.ProximityUnlock.unlockRequest"
    private var requestTimeoutTimer: Timer?

    // MARK: - Init

    /// Production init — uses real UNUserNotificationCenter.
    convenience init() {
        self.init(notificationCenter: UNUserNotificationCenter.current())
    }

    /// Testable init — accepts injectable notification center.
    init(notificationCenter: any NotificationCentering) {
        self.notificationCenter = notificationCenter
        requiresConfirmation = UserDefaults.standard.object(forKey: "requiresConfirmation").map {
            _ in UserDefaults.standard.bool(forKey: "requiresConfirmation")
        } ?? true
    }

    // MARK: - Request Handling

    /// Handles an unlock request arriving via MPC.
    func receiveUnlockRequest() {
        Log.unlock.info("Received unlock request (requiresConfirmation=\(self.requiresConfirmation, privacy: .public))")
        if !requiresConfirmation {
            approve()
            return
        }
        pendingRequest = true
        scheduleUnlockNotification()

        requestTimeoutTimer?.invalidate()
        requestTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                Log.unlock.info("Unlock request timed out on iOS side")
                self?.pendingRequest = false
                self?.cancelNotification()
            }
        }
    }

    /// Handles a lock event arriving via MPC.
    func receiveLockEvent() {
        Log.unlock.info("Received lock event")
        requestTimeoutTimer?.invalidate()
        requestTimeoutTimer = nil
        pendingRequest = false
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [confirmNotificationId])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [confirmNotificationId])
    }

    // MARK: - Confirmation Actions

    func approve() {
        Log.unlock.info("Confirmation approved")
        requestTimeoutTimer?.invalidate()
        requestTimeoutTimer = nil
        onConfirmationSent?(true)
        pendingRequest = false
        cancelNotification()
    }

    func deny() {
        Log.unlock.info("Confirmation denied")
        requestTimeoutTimer?.invalidate()
        requestTimeoutTimer = nil
        onConfirmationSent?(false)
        pendingRequest = false
        cancelNotification()
    }

    // MARK: - Notifications

    func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
            Log.unlock.info("Notification permission: \(granted ? "granted" : "denied", privacy: .public)")
        }
        registerNotificationActions()
    }

    private func registerNotificationActions() {
        let approveAction = UNNotificationAction(
            identifier: "APPROVE_UNLOCK",
            title: "Unlock Mac",
            options: [.authenticationRequired]
        )
        let denyAction = UNNotificationAction(
            identifier: "DENY_UNLOCK",
            title: "Deny",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: "UNLOCK_REQUEST",
            actions: [approveAction, denyAction],
            intentIdentifiers: [],
            options: []
        )
        notificationCenter.setNotificationCategories([category])
    }

    private func scheduleUnlockNotification() {
        Log.unlock.info("Scheduling unlock notification")
        let content = UNMutableNotificationContent()
        content.title = "Mac Unlock Request"
        content.body = "Your Mac is requesting to unlock the screen. Allow?"
        content.categoryIdentifier = "UNLOCK_REQUEST"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: confirmNotificationId,
            content: content,
            trigger: nil
        )
        notificationCenter.add(request, withCompletionHandler: nil)
    }

    private func cancelNotification() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [confirmNotificationId])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [confirmNotificationId])
    }
}

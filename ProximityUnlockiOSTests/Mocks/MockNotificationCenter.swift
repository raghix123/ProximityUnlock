import Foundation
import UserNotifications
@testable import ProximityUnlockiOS

/// Mock notification center for iOS unit tests.
/// Captures notification requests without displaying anything to the user.
class MockNotificationCenter: NotificationCentering {

    // MARK: - Recording

    private(set) var authorizationRequested = false
    private(set) var categoriesSet: Set<UNNotificationCategory> = []
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedPendingIdentifiers: [String] = []
    private(set) var removedDeliveredIdentifiers: [String] = []

    // MARK: - NotificationCentering

    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void) {
        authorizationRequested = true
        completionHandler(true, nil)
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        categoriesSet = categories
    }

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?) {
        addedRequests.append(request)
        completionHandler?(nil)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedPendingIdentifiers.append(contentsOf: identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removedDeliveredIdentifiers.append(contentsOf: identifiers)
    }

    // MARK: - Helpers

    var lastRequest: UNNotificationRequest? { addedRequests.last }
    var notificationFired: Bool { !addedRequests.isEmpty }

    func reset() {
        authorizationRequested = false
        categoriesSet = []
        addedRequests.removeAll()
        removedPendingIdentifiers.removeAll()
        removedDeliveredIdentifiers.removeAll()
    }
}

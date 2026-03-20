import CoreBluetooth
import Foundation

// MARK: - CBPeripheralManager Wrapper Protocol

/// Protocol wrapper around CBPeripheralManager to allow mocking in tests.
protocol CBPeripheralManagerProtocol: AnyObject {
    var state: CBManagerState { get }
    func startAdvertising(_ advertisementData: [String: Any]?)
    func stopAdvertising()
    func add(_ service: CBMutableService)
    func removeAllServices()
    func respond(to request: CBATTRequest, withResult result: CBATTError.Code)
    @discardableResult
    func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [CBCentral]?) -> Bool
}

extension CBPeripheralManager: CBPeripheralManagerProtocol {}

// MARK: - Notification Center Protocol

/// Protocol wrapper around UNUserNotificationCenter to allow mocking in tests.
protocol NotificationCentering: AnyObject {
    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void)
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?)
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
}

import UserNotifications
extension UNUserNotificationCenter: NotificationCentering {}

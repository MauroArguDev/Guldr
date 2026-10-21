//
//  NotificationService.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation
import UserNotifications

/// What iOS allows for Guldr's notifications.
enum NotificationPermission: Equatable, Sendable {
    /// Never asked: the pre-prompt can offer it.
    case notDetermined
    /// Turned off in the Settings app; only the user can turn it back on there.
    case denied
    case allowed
}

/// The app's only door to UserNotifications, so budget alerts can be tested with a fake.
protocol NotificationService: AnyObject {
    func permission() async -> NotificationPermission
    /// Shows the system dialog the first time; returns whether notifications are allowed.
    func requestPermission() async -> Bool
    /// Delivers now. A second request with the same identifier replaces the first.
    func deliver(identifier: String, title: String, body: String) async
    /// After "Delete all data", so no alert about deleted budgets stays in Notification Center.
    func removeAllDelivered()
    /// Called when the user taps a budget alert.
    var onOpen: (() -> Void)? { get set }
}

/// `UNUserNotificationCenter`, and its delegate: alerts show as a banner even while Guldr is open
/// (author's call, 2026-10-21), and a tap opens Budget. Created when the app starts, so a tap that
/// launches the app reaches the delegate.
final class UserNotificationService: NSObject, NotificationService, UNUserNotificationCenterDelegate {

    var onOpen: (() -> Void)?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func permission() async -> NotificationPermission {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized, .provisional, .ephemeral: .allowed
        @unknown default: .denied
        }
    }

    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func deliver(identifier: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "budget"
        // No trigger: delivered right away, since a save just crossed the threshold.
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func removeAllDelivered() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        await MainActor.run { onOpen?() }
    }
}

#if DEBUG
/// Records deliveries instead of showing them, for previews and tests.
final class FakeNotificationService: NotificationService {

    struct Delivery: Equatable {
        let identifier: String
        let title: String
        let body: String
    }

    var currentPermission: NotificationPermission = .allowed
    /// What the system dialog answers.
    var grantsPermission = true
    private(set) var delivered: [Delivery] = []
    private(set) var requestCount = 0
    private(set) var removedAll = false
    var onOpen: (() -> Void)?

    func permission() async -> NotificationPermission {
        currentPermission
    }

    func requestPermission() async -> Bool {
        requestCount += 1
        currentPermission = grantsPermission ? .allowed : .denied
        return grantsPermission
    }

    func deliver(identifier: String, title: String, body: String) async {
        delivered.append(Delivery(identifier: identifier, title: title, body: body))
    }

    func removeAllDelivered() {
        removedAll = true
        delivered = []
    }
}
#endif

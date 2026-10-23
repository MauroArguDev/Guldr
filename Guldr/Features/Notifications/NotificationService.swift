//
//  NotificationService.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation
import GuldrCore
import Observation
import UserNotifications

/// What iOS allows for Guldr's notifications.
enum NotificationPermission: Equatable, Sendable {
    /// Never asked: the pre-prompt can offer it.
    case notDetermined
    /// Turned off in the Settings app; only the user can turn it back on there.
    case denied
    case allowed
}

/// One of Guldr's notifications: its text and the screen it opens.
struct NotificationContent: Equatable {
    let identifier: String
    let title: String
    let body: String
    /// Where a tap goes: Budget for an alert, the add sheet for the daily reminder.
    let link: DeepLink
    /// The day a reminder is for, which its "No spending today" action marks (ADR 012).
    var day: LocalDay?
}

/// The app's only door to UserNotifications, so budget alerts and the daily reminder can be tested with
/// a fake.
protocol NotificationService: AnyObject {
    func permission() async -> NotificationPermission
    /// Shows the system dialog the first time; returns whether notifications are allowed.
    func requestPermission() async -> Bool
    /// Delivers now. A second request with the same identifier replaces the first.
    func deliver(_ content: NotificationContent) async
    /// Delivers once at a wall-clock time (year, month, day, hour, minute), wherever the iPhone is then.
    /// A second request with the same identifier replaces the first.
    func schedule(_ content: NotificationContent, at components: DateComponents) async
    /// The identifiers of the requests still waiting to be delivered that start with `prefix`.
    func pendingIdentifiers(withPrefix prefix: String) async -> [String]
    func removePending(_ identifiers: [String])
    /// After "Delete all data", so no alert about deleted budgets stays in Notification Center.
    func removeAllDelivered()
}

/// What the user did with a notification.
enum NotificationAction: Equatable {
    /// A tap, or "Add expense": show the screen the notification names.
    case open(DeepLink)
    /// The reminder's "No spending today".
    case markNoSpending(LocalDay)
}

/// A notification the user acted on. Distinct every time, so opening two reminders in a row routes twice.
struct OpenedNotification: Equatable {
    let id = UUID()
    let action: NotificationAction
}

/// The last notification the user acted on, for `RootView` to handle. It lives in the service, created
/// with the app, so a tap that launches Guldr is kept until the app's views exist to read it.
@Observable
final class NotificationInbox {

    private(set) var lastOpened: OpenedNotification?

    func record(_ action: NotificationAction) {
        lastOpened = OpenedNotification(action: action)
    }
}

/// `UNUserNotificationCenter`, and its delegate: notifications show as a banner even while Guldr is open
/// (author's call, 2026-10-21), and a tap opens the screen the notification names. Created when the app
/// starts, so a tap that launches the app reaches the delegate.
final class UserNotificationService: NSObject, NotificationService, UNUserNotificationCenterDelegate {

    let inbox = NotificationInbox()

    override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([Self.reminderCategory])
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

    func deliver(_ content: NotificationContent) async {
        // No trigger: delivered right away, since a save just crossed the threshold.
        let request = UNNotificationRequest(identifier: content.identifier, content: Self.content(for: content),
                                            trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func schedule(_ content: NotificationContent, at components: DateComponents) async {
        // One-off on purpose: a repeating trigger can't skip a day that is already logged.
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: content.identifier, content: Self.content(for: content),
                                            trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func pendingIdentifiers(withPrefix prefix: String) async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
    }

    func removePending(_ identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeAllDelivered() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    // MARK: - Routing

    /// The reminder's category: "Add expense" opens the app on the add sheet; "No spending today" marks
    /// the reminder's day (ADR 012).
    static let reminderCategoryID = "reminder"
    static let addActionID = "add"
    static let noSpendingActionID = "noSpending"

    /// What an action on a notification asks for: its own link for a tap, the add sheet for "Add
    /// expense", the reminder's day for "No spending today". `nil` for a dismissal or unknown content.
    static func action(for actionIdentifier: String, userInfo: [AnyHashable: Any]) -> NotificationAction? {
        switch actionIdentifier {
        case addActionID:
            return .open(.add)
        case noSpendingActionID:
            return (userInfo[dayKey] as? Int).flatMap(LocalDay.init(rawValue:)).map(NotificationAction.markNoSpending)
        case UNNotificationDefaultActionIdentifier:
            return (userInfo[linkKey] as? String).flatMap(DeepLink.init(rawValue:)).map(NotificationAction.open)
        default:
            return nil
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Both methods stay on the main actor, the app's default. iOS calls the delegate from a background
    // thread and, for an async method, runs the completion handler where the method ends; UIKit requires
    // it on the main thread and crashes otherwise ("Call must be made on main thread"). An async method
    // isolated to the main actor can satisfy these nonisolated requirements: Swift hops to the main actor
    // first, so the method and the completion both run there.

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        if let action = Self.action(for: response.actionIdentifier,
                                    userInfo: response.notification.request.content.userInfo) {
            inbox.record(action)
        }
    }

    // MARK: - Private

    private static let linkKey = "link"
    private static let dayKey = "day"

    private static var reminderCategory: UNNotificationCategory {
        let add = UNNotificationAction(identifier: addActionID,
                                       title: String(localized: "Add expense",
                                                     comment: "The daily reminder's action that opens the add sheet."),
                                       options: [.foreground])
        // Foreground too (ADR 012): a background action could run without the app's scene, outside the
        // main context the screens read. Opening also shows the streak go up.
        let noSpending = UNNotificationAction(identifier: noSpendingActionID,
                                              title: String(localized: "No spending today",
                                                            comment: "The daily reminder's action that marks the day."),
                                              options: [.foreground])
        return UNNotificationCategory(identifier: reminderCategoryID, actions: [add, noSpending], intentIdentifiers: [])
    }

    private static func content(for content: NotificationContent) -> UNMutableNotificationContent {
        let notification = UNMutableNotificationContent()
        notification.title = content.title
        notification.body = content.body
        notification.sound = .default
        var userInfo: [String: Any] = [linkKey: content.link.rawValue]
        if let day = content.day { userInfo[dayKey] = day.rawValue }
        notification.userInfo = userInfo
        if content.link == .add {
            notification.categoryIdentifier = reminderCategoryID
            notification.threadIdentifier = "reminder"
        } else {
            notification.threadIdentifier = "budget"
        }
        return notification
    }
}

#if DEBUG
/// Records notifications instead of showing them, for previews and tests.
final class FakeNotificationService: NotificationService {

    var currentPermission: NotificationPermission = .allowed
    /// What the system dialog answers.
    var grantsPermission = true
    private(set) var delivered: [NotificationContent] = []
    /// Scheduled requests still pending, by identifier.
    private(set) var scheduled: [String: (content: NotificationContent, components: DateComponents)] = [:]
    private(set) var requestCount = 0
    private(set) var removedAll = false

    func permission() async -> NotificationPermission {
        currentPermission
    }

    func requestPermission() async -> Bool {
        requestCount += 1
        currentPermission = grantsPermission ? .allowed : .denied
        return grantsPermission
    }

    func deliver(_ content: NotificationContent) async {
        delivered.append(content)
    }

    func schedule(_ content: NotificationContent, at components: DateComponents) async {
        scheduled[content.identifier] = (content, components)
    }

    func pendingIdentifiers(withPrefix prefix: String) async -> [String] {
        scheduled.keys.filter { $0.hasPrefix(prefix) }
    }

    func removePending(_ identifiers: [String]) {
        identifiers.forEach { scheduled[$0] = nil }
    }

    func removeAllDelivered() {
        removedAll = true
        delivered = []
    }
}
#endif

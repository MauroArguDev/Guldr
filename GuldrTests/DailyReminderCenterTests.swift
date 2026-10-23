//
//  DailyReminderCenterTests.swift
//  GuldrTests
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import GuldrCore
import SwiftData
import Testing
import UserNotifications
@testable import Guldr

// The app's aliases are internal to the app module; the test module needs its own (ARCHITECTURE.md › Data).
private typealias Transaction = GuldrCore.Transaction

/// The daily reminder end to end with a fake notification service: an in-memory store, UTC and noon on
/// Oct 16, 2026, so today's 20:00 reminder is still ahead.
struct DailyReminderCenterTests {

    @Test func schedulesTheNextWeekFromToday() async throws {
        try await withFixture(enabled: true) { fixture in
            await fixture.center.reschedule()
            #expect(fixture.pendingDays == ["2026-10-16", "2026-10-17", "2026-10-18", "2026-10-19", "2026-10-20",
                                            "2026-10-21", "2026-10-22"])
            let reminder = try #require(fixture.service.scheduled["reminder-2026-10-16"])
            #expect(reminder.components.hour == 20)
            #expect(reminder.components.minute == 0)
            #expect(reminder.content.title == "Guldr")
            #expect(reminder.content.body == "Anything to log today? It takes a few seconds.")
            #expect(reminder.content.link == .add)
        }
    }

    @Test func aTransactionDatedTodayRemovesTodaysReminder() async throws {
        try await withFixture(enabled: true) { fixture in
            await fixture.center.reschedule()
            try fixture.add(on: "2026-10-16T08:30:00Z")
            await fixture.center.reschedule()
            #expect(fixture.pendingDays.first == "2026-10-17")
            #expect(fixture.pendingDays.count == 7)
        }
    }

    @Test func backfillingAnotherDayKeepsTodaysReminder() async throws {
        try await withFixture(enabled: true) { fixture in
            try fixture.add(on: "2026-10-15T21:00:00Z")
            try fixture.add(on: "2026-10-17T00:00:00Z")
            await fixture.center.reschedule()
            #expect(fixture.pendingDays.first == "2026-10-16")
        }
    }

    @Test func changingTheTimeMovesEveryReminder() async throws {
        try await withFixture(enabled: true) { fixture in
            await fixture.center.reschedule()
            await fixture.center.setTime(try #require(ReminderTime(hour: 9, minute: 15)))
            // 09:15 today has passed at noon, so the week starts tomorrow.
            #expect(fixture.pendingDays.first == "2026-10-17")
            #expect(fixture.service.scheduled.count == 7)
            #expect(fixture.service.scheduled.values.allSatisfy { $0.components.hour == 9 && $0.components.minute == 15 })
            #expect(fixture.settings.dailyReminderTime == ReminderTime(hour: 9, minute: 15))
        }
    }

    @Test func turningOffRemovesThePendingReminders() async throws {
        try await withFixture(enabled: true) { fixture in
            await fixture.center.reschedule()
            await fixture.center.setEnabled(false)
            #expect(fixture.service.scheduled.isEmpty)
            #expect(!fixture.settings.dailyReminderEnabled)
        }
    }

    @Test func nothingIsScheduledWhileNotificationsAreOff() async throws {
        try await withFixture(enabled: true) { fixture in
            fixture.service.currentPermission = .denied
            await fixture.center.reschedule()
            #expect(fixture.service.scheduled.isEmpty)
            #expect(!fixture.center.isOn)
        }
    }

    @Test func turningOnAsksIOSOnlyOnce() async throws {
        try await withFixture(enabled: false) { fixture in
            fixture.service.currentPermission = .notDetermined
            #expect(await fixture.center.setEnabled(true))
            #expect(fixture.service.requestCount == 1)
            #expect(fixture.settings.dailyReminderEnabled)
            #expect(fixture.service.scheduled.count == 7)

            await fixture.center.setEnabled(false)
            #expect(await fixture.center.setEnabled(true))
            #expect(fixture.service.requestCount == 1)
        }
    }

    @Test func aRefusedPermissionLeavesItOff() async throws {
        try await withFixture(enabled: false) { fixture in
            fixture.service.currentPermission = .notDetermined
            fixture.service.grantsPermission = false
            #expect(!(await fixture.center.setEnabled(true)))
            #expect(!fixture.settings.dailyReminderEnabled)
            #expect(fixture.service.scheduled.isEmpty)
        }
    }

    @Test func offeredOnceAfterTheFirstTransaction() async throws {
        try await withFixture(enabled: false) { fixture in
            fixture.service.currentPermission = .notDetermined
            await fixture.center.offerIfNeeded()
            #expect(!fixture.center.isOfferingReminder)

            try fixture.add(on: "2026-10-16T08:30:00Z")
            await fixture.center.offerIfNeeded()
            #expect(fixture.center.isOfferingReminder)
            #expect(fixture.settings.hasOfferedDailyReminder)

            fixture.center.isOfferingReminder = false
            await fixture.center.offerIfNeeded()
            #expect(!fixture.center.isOfferingReminder)
        }
    }

    @Test func notOfferedWhenNotificationsAreTurnedOff() async throws {
        try await withFixture(enabled: false) { fixture in
            fixture.service.currentPermission = .denied
            try fixture.add(on: "2026-10-16T08:30:00Z")
            await fixture.center.offerIfNeeded()
            #expect(!fixture.center.isOfferingReminder)
            // It can still be offered once iOS allows notifications again.
            #expect(!fixture.settings.hasOfferedDailyReminder)
        }
    }

    @Test func acceptingTheOfferWhenAlreadyAllowedSkipsTheSystemDialog() async throws {
        try await withFixture(enabled: false) { fixture in
            try fixture.add(on: "2026-10-15T08:30:00Z")
            await fixture.center.offerIfNeeded()
            await fixture.center.acceptOffer()
            #expect(fixture.service.requestCount == 0)
            #expect(fixture.center.isOn)
            #expect(fixture.pendingDays.first == "2026-10-16")
        }
    }

    @Test func aResetClearsThePendingReminders() async throws {
        try await withFixture(enabled: true) { fixture in
            await fixture.center.reschedule()
            fixture.settings.reset()
            await fixture.center.settingsDidReset()
            #expect(fixture.service.scheduled.isEmpty)
            #expect(!fixture.center.isEnabled)
            #expect(fixture.center.time == .default)
        }
    }

    // MARK: - Helpers

    private func withFixture(enabled: Bool, _ body: (Fixture) async throws -> Void) async throws {
        let suiteName = "GuldrTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        try settings.completeOnboarding(currencyCode: "USD")
        settings.setDailyReminderEnabled(enabled)
        try await body(try Fixture(settings: settings))
    }
}

/// Where a tapped notification goes, and the inbox that hands it to `RootView`.
struct NotificationRoutingTests {

    @Test func aTapOpensTheNotificationsOwnLink() {
        let link = UserNotificationService.link(forAction: UNNotificationDefaultActionIdentifier,
                                                userInfo: ["link": "budget"])
        #expect(link == .budget)
    }

    @Test func addExpenseOpensTheAddSheet() {
        #expect(UserNotificationService.link(forAction: UserNotificationService.addActionID, userInfo: [:]) == .add)
    }

    @Test func dismissalsAndUnknownLinksGoNowhere() {
        #expect(UserNotificationService.link(forAction: UNNotificationDismissActionIdentifier,
                                             userInfo: ["link": "add"]) == nil)
        #expect(UserNotificationService.link(forAction: UNNotificationDefaultActionIdentifier,
                                             userInfo: ["link": "settings"]) == nil)
    }

    @Test func openingTheSameLinkTwiceRoutesTwice() throws {
        let inbox = NotificationInbox()
        inbox.open(.add)
        let first = try #require(inbox.lastOpened)
        inbox.open(.add)
        #expect(inbox.lastOpened != first)
        #expect(inbox.lastOpened?.link == .add)
    }
}

// MARK: - Fixture

private struct Fixture {

    let settings: AppSettings
    let service = FakeNotificationService()
    let container: ModelContainer
    let center: DailyReminderCenter

    init(settings: AppSettings) throws {
        self.settings = settings
        container = try PersistenceController(mode: .inMemory).container
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-16T12:00:00Z"))
        center = DailyReminderCenter(container: container, settings: settings, service: service,
                                     timeZone: TimeZone(identifier: "UTC")!, now: { now })
    }

    /// The days with a pending reminder, in order.
    var pendingDays: [String] {
        service.scheduled.keys.sorted().map { $0.replacingOccurrences(of: "reminder-", with: "") }
    }

    func add(on date: String) throws {
        let date = try #require(ISO8601DateFormatter().date(from: date))
        container.mainContext.insert(Transaction(amount: try Money(minorUnits: 1_250, currencyCode: "USD"),
                                                 kind: .expense, date: date))
        try container.mainContext.save()
    }
}

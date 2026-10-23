//
//  StreakCenterTests.swift
//  GuldrTests
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import GuldrCore
import SwiftData
import Testing
@testable import Guldr

// The app's aliases are internal to the app module; the test module needs its own (ARCHITECTURE.md › Data).
private typealias Transaction = GuldrCore.Transaction

/// The streak for the app's screens, against an in-memory store, UTC and noon on Friday, Oct 16, 2026.
struct StreakCenterTests {

    private let today = LocalDay(year: 2026, month: 10, day: 16)!

    @Test func startImportsTheHistoryOnce() throws {
        let fixture = try Fixture()
        try fixture.addTransaction(dated: "2026-10-15T20:00:00Z", created: "2026-10-16T08:00:00Z")
        try fixture.addTransaction(dated: "2026-10-01T20:00:00Z", created: "2026-10-16T08:00:00Z")
        fixture.center.start()
        #expect(fixture.center.streak.current == 1)
        #expect(fixture.settings.hasImportedStreakHistory)

        // A second start doesn't import a transaction added since.
        try fixture.addTransaction(dated: "2026-10-14T20:00:00Z", created: "2026-10-14T20:00:00Z")
        fixture.center.start()
        #expect(fixture.center.streak.current == 1)
    }

    @Test func noSpendingIsOfferedForTodayAndAnOpenYesterday() throws {
        let fixture = try Fixture()
        fixture.center.refresh()
        #expect(fixture.center.canMarkNoSpending(today))
        #expect(fixture.center.canMarkNoSpending(today.adding(days: -1)))
        #expect(!fixture.center.canMarkNoSpending(today.adding(days: -2)))
        #expect(!fixture.center.canMarkNoSpending(today.adding(days: 1)))

        try fixture.center.markNoSpending(today)
        #expect(fixture.center.streak.isTodayLogged)
        #expect(!fixture.center.canMarkNoSpending(today))
        #expect(fixture.center.streak.state(of: today) == .noSpending)
    }

    @Test func anOldNotificationChangesNothing() throws {
        let fixture = try Fixture()
        try fixture.center.markNoSpending(today.adding(days: -3))
        #expect(try fixture.context.fetchCount(FetchDescriptor<LoggedDay>()) == 0)
    }

    @Test func aMilestoneIsCelebratedOncePerRun() throws {
        let fixture = try Fixture()
        try fixture.log(-2, -1)
        fixture.center.refresh()
        #expect(fixture.center.celebration == nil)

        try fixture.center.markNoSpending(today)
        #expect(fixture.center.celebration == 3)
        fixture.center.celebrationDidEnd()
        fixture.center.refresh()
        #expect(fixture.center.celebration == nil)

        // A relaunch reads the same run and stays quiet.
        let relaunched = StreakCenter(container: fixture.container, settings: fixture.settings,
                                      timeZone: fixture.timeZone, now: { fixture.now })
        relaunched.refresh()
        #expect(relaunched.celebration == nil)
    }

    @Test func aHiddenStreakNeverCelebrates() throws {
        let fixture = try Fixture()
        try fixture.log(-2, -1)
        fixture.center.setShown(false)
        #expect(fixture.settings.hidesStreak)
        try fixture.center.markNoSpending(today)
        #expect(fixture.center.celebration == nil)
        #expect(fixture.center.streak.current == 3)
    }

    @Test func aResetStartsOver() throws {
        let fixture = try Fixture()
        try fixture.log(-2, -1, 0)
        fixture.center.setShown(false)
        try DataReset.eraseAll(in: fixture.context)
        fixture.settings.reset()
        fixture.center.settingsDidReset()
        #expect(fixture.center.streak.current == 0)
        #expect(fixture.center.isShown)
        #expect(fixture.settings.hasImportedStreakHistory)
    }

    @Test func aNewTransactionLogsTodayButAnEditDoesNot() throws {
        let fixture = try Fixture()
        let model = try AddTransactionViewModel(context: fixture.context, currencyCode: "USD",
                                                notifier: DataChangeNotifier {}, timeZone: fixture.timeZone)
        model.pressDigit(5)
        model.select(try #require(model.categories.first))
        model.date = .now
        try model.save()
        #expect(try fixture.context.fetchCount(FetchDescriptor<LoggedDay>()) == 1)

        try DataReset.eraseAll(in: fixture.context)
        let transaction = Transaction(amount: try Money(minorUnits: 500, currencyCode: "USD"), kind: .expense)
        fixture.context.insert(transaction)
        try fixture.context.save()
        let editor = try AddTransactionViewModel(editing: transaction.persistentModelID, context: fixture.context,
                                                 notifier: DataChangeNotifier {}, timeZone: fixture.timeZone)
        editor.select(try #require(editor.categories.first))
        editor.pressDigit(1)
        try editor.save()
        #expect(try fixture.context.fetchCount(FetchDescriptor<LoggedDay>()) == 0)
    }
}

// MARK: - Fixture

/// A class, so its defaults suite is removed when the test ends.
private final class Fixture {

    let container: ModelContainer
    let settings: AppSettings
    let center: StreakCenter
    let timeZone = TimeZone(identifier: "UTC")!
    let now: Date
    private let suiteName = "GuldrTests.\(UUID().uuidString)"

    init() throws {
        container = try PersistenceController(mode: .inMemory).container
        settings = AppSettings(defaults: try #require(UserDefaults(suiteName: suiteName)))
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-16T12:00:00Z"))
        self.now = now
        center = StreakCenter(container: container, settings: settings, timeZone: timeZone, now: { now })
    }

    deinit {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    var context: ModelContext { container.mainContext }

    /// Logged days as offsets from today.
    func log(_ offsets: Int...) throws {
        let today = LocalDay(containing: now, timeZone: timeZone)
        for offset in offsets {
            context.insert(LoggedDay(day: today.adding(days: offset), source: .transaction))
        }
        try context.save()
    }

    func addTransaction(dated: String, created: String) throws {
        let transaction = Transaction(amount: try Money(minorUnits: 900, currencyCode: "USD"), kind: .expense,
                                      date: try #require(ISO8601DateFormatter().date(from: dated)))
        transaction.createdAt = try #require(ISO8601DateFormatter().date(from: created))
        context.insert(transaction)
        try context.save()
    }
}

//
//  LoggedDaysTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import SwiftData
import Testing
@testable import GuldrCore

/// Recording and importing logged days in Mexico City, at 10:00 on Friday, October 23, 2026.
struct LoggedDaysTests {

    private let mexico = TimeZone(identifier: "America/Mexico_City")!
    private let today = LocalDay(year: 2026, month: 10, day: 23)!

    @Test func aNewTransactionLogsItsDayOnce() throws {
        let context = try makeInMemoryContext()
        let now = try date("2026-10-23T10:00:00-06:00")
        #expect(try LoggedDays.recordTransaction(dated: now, now: now, timeZone: mexico, in: context))
        #expect(!(try LoggedDays.recordTransaction(dated: now, now: now, timeZone: mexico, in: context)))
        try context.save()
        #expect(try LoggedDays.all(in: context) == [today: .transaction])
    }

    @Test func yesterdayCanBeRepairedButOlderDaysCannot() throws {
        let context = try makeInMemoryContext()
        let now = try date("2026-10-23T10:00:00-06:00")
        #expect(try LoggedDays.recordTransaction(dated: try date("2026-10-22T21:00:00-06:00"), now: now,
                                                 timeZone: mexico, in: context))
        #expect(!(try LoggedDays.recordTransaction(dated: try date("2026-10-21T21:00:00-06:00"), now: now,
                                                   timeZone: mexico, in: context)))
        #expect(!(try LoggedDays.markNoSpending(today.adding(days: 1), now: now, timeZone: mexico, in: context)))
        try context.save()
        #expect(try LoggedDays.all(in: context).keys.map(\.rawValue) == [20_261_022])
    }

    @Test func noSpendingIsRecordedAndATransactionWinsTheSameDay() throws {
        let context = try makeInMemoryContext()
        let now = try date("2026-10-23T10:00:00-06:00")
        #expect(try LoggedDays.markNoSpending(today, now: now, timeZone: mexico, in: context))
        #expect(!(try LoggedDays.recordTransaction(dated: now, now: now, timeZone: mexico, in: context)))
        context.insert(LoggedDay(day: today, source: .transaction))
        try context.save()
        #expect(try LoggedDays.all(in: context) == [today: .transaction])
    }

    @Test func theStreakReadsTheStore() throws {
        let context = try makeInMemoryContext()
        for offset in -3 ... -1 {
            context.insert(LoggedDay(day: today.adding(days: offset), source: .transaction))
        }
        try context.save()
        let streak = try LoggedDays.streak(in: context, now: try date("2026-10-23T10:00:00-06:00"), timeZone: mexico)
        #expect(streak.current == 3)
        #expect(!streak.isTodayLogged)
    }

    @Test func historyImportsOnlyDaysLoggedInTime() throws {
        let context = try makeInMemoryContext()
        // Logged the same day, logged the next morning, and backfilled three days later.
        try insert(dated: "2026-10-20T13:00:00-06:00", created: "2026-10-20T13:05:00-06:00", in: context)
        try insert(dated: "2026-10-21T20:00:00-06:00", created: "2026-10-22T08:00:00-06:00", in: context)
        try insert(dated: "2026-10-15T09:00:00-06:00", created: "2026-10-18T09:00:00-06:00", in: context)
        try insert(dated: "2026-10-20T19:00:00-06:00", created: "2026-10-20T19:00:00-06:00", in: context)

        #expect(try LoggedDays.importHistory(in: context, timeZone: mexico) == 2)
        #expect(Set(try LoggedDays.all(in: context).keys.map(\.rawValue)) == [20_261_020, 20_261_021])
        #expect(try LoggedDays.importHistory(in: context, timeZone: mexico) == 0)
    }

    // MARK: - Helpers

    private func date(_ text: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: text))
    }

    private func insert(dated: String, created: String, in context: ModelContext) throws {
        let transaction = Transaction(amount: try usd(1_000), kind: .expense, date: try date(dated))
        transaction.createdAt = try date(created)
        context.insert(transaction)
        try context.save()
    }
}

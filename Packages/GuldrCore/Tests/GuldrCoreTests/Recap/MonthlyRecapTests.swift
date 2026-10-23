//
//  MonthlyRecapTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import SwiftData
import Testing
@testable import GuldrCore

/// September 2026 in review, as of noon on October 3 in Mexico City (UTC−6).
struct MonthlyRecapTests {

    private let mexico = TimeZone(identifier: "America/Mexico_City")!
    private let september = YearMonth(year: 2026, month: 9)!

    @Test func anEmptyMonthHasNothingToShow() throws {
        let fixture = try Fixture()
        let recap = fixture.recap(september)
        #expect(recap.isEmpty)
        #expect(recap.daysInMonth == 30)
        #expect(recap.savingsRate == nil)
        #expect(recap.topCategory == nil)
        #expect(!recap.isComplete)
    }

    @Test func aFullMonthShowsEverythingButNoAmount() throws {
        let fixture = try Fixture()
        fixture.log(1...30)
        try fixture.add(500_000, .income, "salary", on: "2026-09-01T10:00:00-06:00")
        try fixture.add(150_000, .expense, "housing", on: "2026-09-02T10:00:00-06:00")
        try fixture.add(50_000, .expense, "food", on: "2026-09-10T10:00:00-06:00")
        try fixture.budget(40_000, "food")
        try fixture.budget(200_000, "housing")
        let earnedAt = try #require(ISO8601DateFormatter().date(from: "2026-09-20T12:00:00-06:00"))
        let recap = fixture.recap(september, earned: [
            EarnedTier(id: .saver, tier: .gold, earnedAt: earnedAt),
            EarnedTier(id: .unbroken, tier: .silver, earnedAt: earnedAt),
            EarnedTier(id: .bookkeeper, tier: .bronze, earnedAt: try #require(ISO8601DateFormatter().date(from: "2026-10-01T12:00:00Z")))
        ])
        #expect(!recap.isEmpty)
        #expect(recap.daysLogged == 30)
        #expect(recap.isComplete)
        #expect(recap.bestStreak == 30)
        #expect(recap.savingsRate == 60)
        #expect(recap.budgetsSet == 2)
        #expect(recap.budgetsKept == 1)
        #expect(recap.topCategory?.share == 75)
        #expect(recap.topCategory?.categoryID == (try fixture.category("housing")).id)
        #expect(recap.achievementsEarned.map(\.id) == [.unbroken, .saver])
    }

    @Test func anIncompleteMonthStillCountsItsDays() throws {
        let fixture = try Fixture()
        fixture.log(Array(1...5) + Array(10...20))
        let recap = fixture.recap(september)
        #expect(recap.daysLogged == 16)
        #expect(!recap.isComplete)
        #expect(recap.bestStreak == 11)
        #expect(recap.budgetsSet == 0)
    }

    @Test func theCurrentMonthIsNeverComplete() throws {
        let fixture = try Fixture()
        fixture.log(1...30)
        let october = YearMonth(year: 2026, month: 10)!
        fixture.logOctober(1...3)
        let recap = fixture.recap(october)
        #expect(!recap.isComplete)
        #expect(recap.daysLogged == 3)
    }

    @Test func theDeviceTimeZoneDecidesTheMonth() throws {
        let fixture = try Fixture()
        // 22:00 on September 30 in Mexico City is already October in UTC.
        try fixture.add(10_000, .income, "salary", on: "2026-09-30T22:00:00-06:00")
        #expect(fixture.recap(september).savingsRate == 100)
        #expect(fixture.recap(YearMonth(year: 2026, month: 10)!).savingsRate == nil)
    }

    @Test func otherCurrenciesAreLeftOut() throws {
        let fixture = try Fixture()
        try fixture.add(10_000, .income, "salary", on: "2026-09-05T10:00:00-06:00", currency: "EUR")
        #expect(fixture.recap(september).savingsRate == nil)
    }
}

// MARK: - Fixture

private final class Fixture {

    let context: ModelContext
    let timeZone = TimeZone(identifier: "America/Mexico_City")!
    let now: Date
    private var days: [LocalDay: LoggedDaySource] = [:]

    init() throws {
        context = ModelContext(try PersistenceController(mode: .inMemory).container)
        now = try #require(ISO8601DateFormatter().date(from: "2026-10-03T12:00:00-06:00"))
    }

    func recap(_ month: YearMonth, earned: [EarnedTier] = []) -> MonthlyRecap {
        MonthlyRecap(month: month, transactions: (try? context.fetch(FetchDescriptor<Transaction>())) ?? [],
                     budgets: (try? context.fetch(FetchDescriptor<Budget>())) ?? [], loggedDays: days,
                     earned: earned, currencyCode: "USD", now: now, timeZone: timeZone)
    }

    func log(_ septemberDays: some Sequence<Int>) {
        for day in septemberDays { days[LocalDay(year: 2026, month: 9, day: day)!] = .transaction }
    }

    func logOctober(_ octoberDays: some Sequence<Int>) {
        for day in octoberDays { days[LocalDay(year: 2026, month: 10, day: day)!] = .transaction }
    }

    func category(_ systemKey: String) throws -> Category {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.systemKey == systemKey })
        return try #require(try context.fetch(descriptor).first)
    }

    func add(_ cents: Int64, _ kind: TransactionKind, _ systemKey: String, on date: String,
             currency: String = "USD") throws {
        context.insert(Transaction(amount: try Money(minorUnits: cents, currencyCode: currency), kind: kind,
                                   date: try #require(ISO8601DateFormatter().date(from: date)),
                                   category: try category(systemKey)))
        try context.save()
    }

    func budget(_ cents: Int64, _ systemKey: String) throws {
        context.insert(Budget(month: YearMonth(year: 2026, month: 9)!, limit: try usd(cents),
                              category: try category(systemKey)))
        try context.save()
    }
}

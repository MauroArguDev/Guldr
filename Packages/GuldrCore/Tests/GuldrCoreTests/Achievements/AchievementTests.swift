//
//  AchievementTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import SwiftData
import Testing
@testable import GuldrCore

/// The catalog, tiers and progress.
struct AchievementCatalogTests {

    @Test func everyAchievementHasOneEntryWithAscendingTiers() {
        #expect(AchievementCatalog.all.map(\.id) == AchievementID.allCases)
        #expect(Set(AchievementCatalog.all.map(\.family)) == Set(AchievementFamily.allCases))
        for achievement in AchievementCatalog.all {
            #expect(achievement.thresholds.count == 3, "\(achievement.id)")
            #expect(achievement.thresholds == achievement.thresholds.sorted(), "\(achievement.id)")
            #expect(AchievementCatalog.achievement(achievement.id) == achievement)
        }
    }

    @Test func tiersFollowTheThresholds() {
        let unbroken = AchievementCatalog.achievement(.unbroken)
        #expect(unbroken.tier(for: 6) == nil)
        #expect(unbroken.tier(for: 7) == .bronze)
        #expect(unbroken.tier(for: 99) == .silver)
        #expect(unbroken.tier(for: 365) == .gold)
        #expect(unbroken.nextTier(after: nil) == .bronze)
        #expect(unbroken.nextTier(after: .gold) == nil)
    }

    @Test func progressKeepsAStoredTierAboveTheData() throws {
        let earnedAt = try #require(ISO8601DateFormatter().date(from: "2026-09-01T12:00:00Z"))
        let progress = AchievementEvaluator.progress(values: [.unbroken: 3, .daysLogged: 40],
                                                     earned: [EarnedTier(id: .unbroken, tier: .silver, earnedAt: earnedAt)])
        let unbroken = try #require(progress.first { $0.id == .unbroken })
        #expect(unbroken.tier == .silver)
        #expect(unbroken.earnedAt == earnedAt)
        #expect(unbroken.nextTier == .gold)
        #expect(unbroken.fractionToNext == 0.03)

        // Reached by the data, not stored yet.
        let days = try #require(progress.first { $0.id == .daysLogged })
        #expect(days.tier == .bronze)
        #expect(days.earnedAt == nil)
        #expect(progress.count == AchievementCatalog.all.count)
    }

    @Test func onlyNewTiersAreEarnedOncePerAchievement() throws {
        let date = Date.now
        let stored = [EarnedTier(id: .unbroken, tier: .silver, earnedAt: date),
                      EarnedTier(id: .unbroken, tier: .bronze, earnedAt: date),
                      EarnedTier(id: .daysLogged, tier: .gold, earnedAt: date)]
        let new = AchievementEvaluator.newlyEarned(values: [.unbroken: 120, .daysLogged: 400, .completeMonth: 3],
                                                   earned: stored, at: date)
        #expect(new.map(\.id) == [.unbroken, .completeMonth])
        #expect(new.map(\.tier) == [.gold, .silver])
        #expect(AchievementEvaluator.newlyEarned(values: [.unbroken: 30], earned: stored, at: date).isEmpty)
    }
}

/// The evaluator over an in-memory store, in UTC, as of noon on Friday, October 16, 2026.
struct AchievementEvaluatorTests {

    @Test func aMonthIsCompleteAtNinetyPercentOfItsDays() throws {
        let fixture = try Fixture()
        let september = YearMonth(year: 2026, month: 9)!
        // Days 3–6 (or 4–6) are missed before any freeze is earned: 26 days covered aren't enough, 27 are.
        #expect(!fixture.isComplete(september, logging: [1, 2] + Array(7...30)))
        #expect(fixture.isComplete(september, logging: [1, 2, 3] + Array(7...30)))
        // A freeze covers a day: 7 days earn it, day 8 is frozen, 19 more make 26 logged + 1 frozen.
        #expect(fixture.isComplete(september, logging: Array(1...7) + Array(9...27)))
        // The current month is never complete.
        #expect(!fixture.isComplete(YearMonth(year: 2026, month: 10)!, logging: Array(1...16)))
    }

    @Test func aSavedMonthWithFewLoggedDaysEarnsNothing() throws {
        let fixture = try Fixture()
        try fixture.income(500_000, on: "2026-09-02")
        fixture.logMonth(2026, 9, days: Array(1...10))
        let values = fixture.values()
        #expect(values[.saver] == 0)
        #expect(values[.inTheBlack] == 0)
        #expect(values[.completeMonth] == 0)
        #expect(values[.daysLogged] == 10)
    }

    @Test func savingsCountInCompleteMonthsOfTheActiveCurrency() throws {
        let fixture = try Fixture()
        try fixture.income(500_000, on: "2026-09-02")
        try fixture.expense(350_000, "food", on: "2026-09-10")
        try fixture.income(900_000, on: "2026-09-03", currency: "EUR")
        fixture.logMonth(2026, 9, days: Array(1...30))
        let values = fixture.values()
        #expect(values[.saver] == 30)
        #expect(values[.completeMonth] == 1)
        #expect(values[.bookkeeper] == 3)
    }

    @Test func budgetsCountMonthsWithinEveryLimitAndTheirLongestRun() throws {
        let fixture = try Fixture()
        for month in 6...9 {
            try fixture.budget(40_000, "food", month: month)
            fixture.logMonth(2026, month, days: Array(1...28))
        }
        try fixture.expense(30_000, "food", on: "2026-06-10")
        try fixture.expense(50_000, "food", on: "2026-07-10")   // over in July
        try fixture.expense(30_000, "food", on: "2026-08-10")
        try fixture.expense(40_000, "food", on: "2026-09-10")   // exactly the limit is within
        let values = fixture.values()
        #expect(values[.withinBudget] == 3)
        #expect(values[.steadyHand] == 2)
    }

    @Test func aMonthWithoutBudgetsIsNotWithinBudget() throws {
        let fixture = try Fixture()
        fixture.logMonth(2026, 9, days: Array(1...30))
        #expect(fixture.values()[.withinBudget] == 0)
    }

    @Test func monthsInTheBlackMustBeConsecutiveAndComplete() throws {
        let fixture = try Fixture()
        for month in 5...9 {
            try fixture.income(100_000, on: String(format: "2026-%02d-05", month))
            try fixture.expense(60_000, "food", on: String(format: "2026-%02d-06", month))
        }
        // May, June, August and September complete; July isn't.
        for month in [5, 6, 8, 9] { fixture.logMonth(2026, month, days: Array(1...28)) }
        fixture.logMonth(2026, 7, days: Array(1...10))
        let values = fixture.values()
        #expect(values[.inTheBlack] == 2)
        #expect(values[.completeMonth] == 4)
        #expect(values[.saver] == 40)
    }

    @Test func consistencyReadsTheStreak() throws {
        let fixture = try Fixture()
        fixture.logMonth(2026, 10, days: Array(1...16))
        let values = fixture.values()
        #expect(values[.unbroken] == 16)
        #expect(values[.daysLogged] == 16)
    }

    @Test func fiveThousandTransactionsAreFast() throws {
        let fixture = try Fixture()
        let food = try fixture.category("food")
        let start = try #require(ISO8601DateFormatter().date(from: "2024-10-16T12:00:00Z"))
        for index in 0..<5_000 {
            fixture.context.insert(Transaction(amount: try usd(Int64(100 + index % 900)), kind: index % 10 == 0 ? .income : .expense,
                                               date: start.addingTimeInterval(Double(index) * 12_600), category: food))
        }
        try fixture.context.save()
        for offset in 0..<730 where offset % 13 != 0 {
            fixture.days[LocalDay(year: 2024, month: 10, day: 16)!.adding(days: offset)] = .transaction
        }
        let transactions = try fixture.context.fetch(FetchDescriptor<Transaction>())
        let clock = ContinuousClock()
        let elapsed = clock.measure { _ = fixture.values(transactions: transactions) }
        print("[performance] AchievementEvaluator (5,000 transactions, 2 years): \(elapsed)")
        #expect(elapsed < .milliseconds(500))
    }
}

// MARK: - Fixture

private final class Fixture {

    let context: ModelContext
    let timeZone = TimeZone(identifier: "UTC")!
    let now: Date
    var days: [LocalDay: LoggedDaySource] = [:]

    init() throws {
        context = ModelContext(try PersistenceController(mode: .inMemory).container)
        now = try #require(ISO8601DateFormatter().date(from: "2026-10-16T12:00:00Z"))
    }

    func values(transactions: [Transaction]? = nil) -> [AchievementID: Int] {
        let input = AchievementEvaluator.Input(
            transactions: transactions ?? (try? context.fetch(FetchDescriptor<Transaction>())) ?? [],
            budgets: (try? context.fetch(FetchDescriptor<Budget>())) ?? [], loggedDays: days, currencyCode: "USD")
        return AchievementEvaluator.values(for: input, now: now, timeZone: timeZone)
    }

    func isComplete(_ month: YearMonth, logging dayNumbers: [Int]) -> Bool {
        days = [:]
        logMonth(month.year, month.month, days: dayNumbers)
        let streak = LoggingStreak(loggedDays: days, today: LocalDay(containing: now, timeZone: timeZone))
        return AchievementEvaluator.isComplete(month, streak: streak, timeZone: timeZone)
    }

    func logMonth(_ year: Int, _ month: Int, days dayNumbers: [Int]) {
        for day in dayNumbers {
            if let localDay = LocalDay(year: year, month: month, day: day) { days[localDay] = .transaction }
        }
    }

    func category(_ systemKey: String) throws -> Category {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.systemKey == systemKey })
        return try #require(try context.fetch(descriptor).first)
    }

    func budget(_ cents: Int64, _ systemKey: String, month: Int) throws {
        context.insert(Budget(month: YearMonth(year: 2026, month: month)!, limit: try usd(cents),
                              category: try category(systemKey)))
        try context.save()
    }

    func income(_ cents: Int64, on day: String, currency: String = "USD") throws {
        context.insert(Transaction(amount: try Money(minorUnits: cents, currencyCode: currency), kind: .income,
                                   date: try date(day), category: try category("salary")))
        try context.save()
    }

    func expense(_ cents: Int64, _ systemKey: String, on day: String) throws {
        context.insert(Transaction(amount: try usd(cents), kind: .expense, date: try date(day),
                                   category: try category(systemKey)))
        try context.save()
    }

    private func date(_ day: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: day + "T12:00:00Z"))
    }
}

/// Recording earned tiers in the store.
struct EarnedAchievementsTests {

    @Test func recordingStoresNewTiersOnceAndKeepsThem() throws {
        let context = ModelContext(try PersistenceController(mode: .inMemory).container)
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-16T12:00:00Z"))
        let utc = try #require(TimeZone(identifier: "UTC"))
        for offset in -6...0 {
            context.insert(LoggedDay(day: LocalDay(year: 2026, month: 10, day: 16)!.adding(days: offset), source: .transaction))
        }
        try context.save()

        let first = try EarnedAchievements.record(in: context, currencyCode: "USD", now: now, timeZone: utc)
        #expect(first == [EarnedTier(id: .unbroken, tier: .bronze, earnedAt: now)])
        #expect(try EarnedAchievements.record(in: context, currencyCode: "USD", now: now, timeZone: utc).isEmpty)

        // Deleting the days doesn't take the medal back.
        for day in try context.fetch(FetchDescriptor<LoggedDay>()) { context.delete(day) }
        try context.save()
        let values = try EarnedAchievements.values(in: context, currencyCode: "USD", now: now, timeZone: utc)
        let progress = AchievementEvaluator.progress(values: values, earned: try EarnedAchievements.all(in: context))
        #expect(progress.first { $0.id == .unbroken }?.tier == .bronze)
    }

    @Test func anUnknownRecordIsIgnored() throws {
        let context = ModelContext(try PersistenceController(mode: .inMemory).container)
        let future = EarnedAchievement(EarnedTier(id: .saver, tier: .gold, earnedAt: .now))
        future.achievementID = "fromANewerVersion"
        context.insert(future)
        try context.save()
        #expect(try EarnedAchievements.all(in: context).isEmpty)
    }
}

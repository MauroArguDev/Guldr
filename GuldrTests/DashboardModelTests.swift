//
//  DashboardModelTests.swift
//  GuldrTests
//
//  Created by Mauricio Argumedo on 16/10/26.
//

import Foundation
import GuldrCore
import SwiftData
import Testing
@testable import Guldr

// The app's aliases are internal to the app module; the test module needs its own (ARCHITECTURE.md › Data).
private typealias Category = GuldrCore.Category
private typealias Transaction = GuldrCore.Transaction
private typealias Budget = GuldrCore.Budget

/// The Dashboard's mapping against an in-memory store with the default categories. UTC, US English and
/// a fixed "now" (Oct 16, 2026, noon: 15 days left in the month) keep months and texts stable.
struct DashboardModelTests {

    // MARK: - Balance

    @Test func balanceIsAllTimeAndTheRestIsTheMonth() throws {
        let fixture = try Fixture()
        try fixture.add(500_000, "salary", "2026-09-25T09:00:00Z")      // last month
        try fixture.add(300_000, "salary", "2026-10-01T09:00:00Z")
        try fixture.add(4_280, "food", "2026-10-15T09:41:00Z")
        try fixture.add(75_000, "housing", "2026-10-02T09:00:00Z")
        let model = fixture.model()

        let balance = try #require(model.balance)
        #expect(balance.total.minorUnits == 500_000 + 300_000 - 4_280 - 75_000)
        #expect(balance.income.minorUnits == 300_000)
        #expect(balance.expenses.minorUnits == 79_280)
        #expect(abs((balance.savingsRate ?? 0) - 220_720.0 / 300_000) < 0.000_1)
        #expect(model.month == YearMonth(year: 2026, month: 10))
    }

    @Test func otherCurrenciesAreLeftOut() throws {
        let fixture = try Fixture()
        try fixture.add(1_000, "food", "2026-10-15T09:00:00Z")
        try fixture.add(9_999, "food", "2026-10-15T10:00:00Z", currency: "EUR")
        let model = fixture.model()
        #expect(model.balance?.total.minorUnits == -1_000)
        #expect(model.balance?.expenses.minorUnits == 1_000)
    }

    @Test func savingsRateIsMissingWithoutIncomeAndZeroWhenOverspent() throws {
        let fixture = try Fixture()
        try fixture.add(4_280, "food", "2026-10-15T09:41:00Z")
        let model = fixture.model()
        #expect(model.balance?.savingsRate == nil)

        try fixture.add(1_000, "salary", "2026-10-01T09:00:00Z")
        fixture.refresh(model)
        #expect(model.balance?.savingsRate == 0)
    }

    @Test func theStartingBalanceOnlyMovesTheTotal() throws {
        let fixture = try Fixture()
        try fixture.add(300_000, "salary", "2026-10-01T09:00:00Z")
        try fixture.add(4_280, "food", "2026-10-15T09:41:00Z")
        let model = fixture.model(openingBalance: 100_000)
        let balance = try #require(model.balance)
        #expect(balance.total.minorUnits == 100_000 + 300_000 - 4_280)
        #expect(balance.income.minorUnits == 300_000)
        #expect(balance.expenses.minorUnits == 4_280)
        #expect(abs((balance.savingsRate ?? 0) - 295_720.0 / 300_000) < 0.000_1)
    }

    @Test func emptyStoreShowsTheCardAtZero() throws {
        let fixture = try Fixture()
        let model = fixture.model()
        #expect(model.balance?.total.isZero == true)
        #expect(model.balance?.savingsRate == nil)
        #expect(!model.hasTransactions)
        #expect(model.recent.isEmpty)
        #expect(model.budget == nil)
    }

    // MARK: - Budget

    @Test func budgetIsHiddenWithoutBudgetsThisMonth() throws {
        let fixture = try Fixture()
        try fixture.add(4_280, "food", "2026-10-15T09:41:00Z")
        try fixture.addBudget(40_000, "food", month: YearMonth(year: 2026, month: 9)!)
        #expect(fixture.model().budget == nil)
    }

    @Test func budgetWithinShowsDaysLeft() throws {
        let fixture = try Fixture()
        try fixture.add(10_000, "food", "2026-10-15T09:00:00Z")
        try fixture.addBudget(40_000, "food")
        try fixture.addBudget(20_000, "transport")

        let budget = try #require(fixture.model().budget)
        #expect(budget.title == "October budget")
        #expect(budget.detail == "$100.00 of $600.00 · 15 days left")
        #expect(abs(budget.usage - 1.0 / 6) < 0.000_1)
    }

    @Test func lastDayUsesTheSingular() throws {
        let fixture = try Fixture(now: "2026-10-30T12:00:00Z")
        try fixture.addBudget(40_000, "food")
        #expect(fixture.model().budget?.detail == "$0.00 of $400.00 · 1 day left")
    }

    @Test func overBudgetCountsCategories() throws {
        let fixture = try Fixture()
        try fixture.add(50_000, "food", "2026-10-15T09:00:00Z")
        try fixture.addBudget(40_000, "food")
        try fixture.addBudget(20_000, "transport")
        let model = fixture.model()
        #expect(model.budget?.detail == "$500.00 of $600.00 · 1 category over budget")
        #expect((model.budget?.usage ?? 0) < 1)

        try fixture.add(30_000, "transport", "2026-10-15T10:00:00Z")
        fixture.refresh(model)
        #expect(model.budget?.detail == "$800.00 of $600.00 · 2 categories over budget")
        #expect((model.budget?.usage ?? 0) > 1)
    }

    // MARK: - Recent

    @Test func recentShowsTheNewestFive() throws {
        let fixture = try Fixture()
        for day in 1...7 {
            try fixture.add(Int64(day) * 100, "food", String(format: "2026-10-%02dT09:00:00Z", day), title: "Day \(day)")
        }
        let model = fixture.model()
        #expect(model.recent.map(\.title) == ["Day 7", "Day 6", "Day 5", "Day 4", "Day 3"])
        #expect(model.hasTransactions)
    }

    @Test func recentRowsFallBackToTheCategory() throws {
        let fixture = try Fixture()
        try fixture.add(4_280, "food", "2026-10-16T09:41:00Z")
        try fixture.add(500_000, "salary", "2026-09-25T09:00:00Z", title: "Salary")
        let cash = Transaction(amount: try Money(minorUnits: 500, currencyCode: "USD"), kind: .expense,
                               title: "Cash", date: try fixture.date("2026-10-15T09:00:00Z"))
        fixture.context.insert(cash)
        try fixture.context.save()

        let rows = fixture.model().recent
        #expect(rows.map(\.title) == ["Food", "Cash", "Salary"])
        #expect(rows.map(\.meta) == ["Food · Today", "Uncategorized · Yesterday", "Salary · Sep 25"])
        #expect(rows.map(\.symbol).last == "briefcase")
        #expect(rows[1].symbol == "questionmark")
        #expect(rows.map(\.kind) == [.expense, .expense, .income])
    }
}

// MARK: - Fixture

private struct Fixture {

    let context: ModelContext
    let timeZone = TimeZone(identifier: "UTC")!
    let locale = Locale(identifier: "en_US")
    let now: Date

    init(now iso: String = "2026-10-16T12:00:00Z") throws {
        context = ModelContext(try PersistenceController(mode: .inMemory).container)
        now = try #require(ISO8601DateFormatter().date(from: iso))
    }

    /// A model already fed with the store, as the view does on appear.
    func model(openingBalance: Int64 = 0) -> DashboardModel {
        let model = DashboardModel(locale: locale, timeZone: timeZone, now: { [now] in now })
        refresh(model, openingBalance: openingBalance)
        return model
    }

    /// What the view does when its queries' results change or after a save.
    func refresh(_ model: DashboardModel, openingBalance: Int64 = 0) {
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        var newest = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        newest.fetchLimit = DashboardModel.recentLimit
        model.update(transactions: transactions, budgets: (try? context.fetch(FetchDescriptor<Budget>())) ?? [],
                     recent: (try? context.fetch(newest)) ?? [], currencyCode: "USD", openingBalance: openingBalance)
    }

    func category(_ systemKey: String) throws -> Category {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.systemKey == systemKey })
        return try #require(try context.fetch(descriptor).first)
    }

    func date(_ iso: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: iso))
    }

    /// Inserts a transaction of the category's kind and saves.
    func add(_ cents: Int64, _ systemKey: String, _ iso: String, title: String = "", currency: String = "USD") throws {
        let category = try category(systemKey)
        context.insert(Transaction(amount: try Money(minorUnits: cents, currencyCode: currency), kind: category.kind,
                                   title: title, date: try date(iso), category: category))
        try context.save()
    }

    func addBudget(_ cents: Int64, _ systemKey: String, month: YearMonth = YearMonth(year: 2026, month: 10)!) throws {
        context.insert(Budget(month: month, limit: try Money(minorUnits: cents, currencyCode: "USD"),
                              category: try category(systemKey)))
        try context.save()
    }
}

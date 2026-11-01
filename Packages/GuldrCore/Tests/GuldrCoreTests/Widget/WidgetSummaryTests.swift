//
//  WidgetSummaryTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation
import SwiftData
import Testing
@testable import GuldrCore

/// The widgets' numbers: the Dashboard's month in the active currency and Recent's newest rows, in UTC
/// and US English on Oct 21, 2026, noon.
struct WidgetSummaryTests {

    private let utc = TimeZone(identifier: "UTC")!
    private let locale = Locale(identifier: "en_US")

    @Test func balanceAndMonthUseTheActiveCurrency() throws {
        let context = try seededContext()
        try add(500_000, "salary", "2026-10-01T09:00:00Z", in: context)
        try add(4_280, "food", "2026-10-21T08:00:00Z", in: context)
        try add(10_000, "food", "2026-09-30T20:00:00Z", in: context)
        try add(99_900, "food", "2026-10-20T09:00:00Z", currency: "EUR", in: context)

        let summary = try makeSummary(context)
        #expect(summary.balance.minorUnits == 500_000 - 4_280 - 10_000)
        #expect(summary.monthIncome.minorUnits == 500_000)
        #expect(summary.monthExpenses.minorUnits == 4_280)
        #expect(summary.monthLabel == "Oct")
        #expect(!summary.isEmpty)
    }

    @Test func theBalanceIncludesTheStartingBalance() throws {
        let context = try seededContext()
        try add(4_280, "food", "2026-10-21T08:00:00Z", in: context)
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let summary = try WidgetSummary(transactions: transactions, currencyCode: "USD", openingBalance: 100_000,
                                        now: try date("2026-10-21T12:00:00Z"), timeZone: utc,
                                        locale: locale) { _ in "" }
        #expect(summary.balance.minorUnits == 100_000 - 4_280)
        #expect(summary.monthExpenses.minorUnits == 4_280)
        #expect(summary.monthIncome.isZero)
    }

    @Test func recentShowsTheNewestThreeInAnyCurrency() throws {
        let context = try seededContext()
        try add(500_000, "salary", "2026-10-01T09:00:00Z", in: context)
        try add(3_500, "transport", "2026-10-19T09:00:00Z", title: "Gas", in: context)
        try add(99_900, "shopping", "2026-10-20T09:00:00Z", currency: "EUR", in: context)
        try add(4_280, "food", "2026-10-21T08:00:00Z", in: context)

        let recent = try makeSummary(context).recent
        #expect(recent.count == WidgetSummary.recentLimit)
        #expect(recent.map(\.title) == ["Category Food", "Category Shopping", "Gas"])
        #expect(recent.map(\.meta) == ["Today", "Yesterday", "Oct 19"])
        #expect(recent[1].amount.currencyCode == "EUR")
        #expect(recent.map(\.kind) == [.expense, .expense, .expense])
    }

    @Test func aTransactionWithoutACategoryIsNamedByTheCaller() throws {
        let context = try seededContext()
        context.insert(Transaction(amount: try usd(1_000), kind: .expense,
                                   date: try date("2026-10-21T08:00:00Z")))
        try context.save()
        #expect(try makeSummary(context).recent.first?.title == "No category")
    }

    @Test func anEmptyStoreShowsZeroAndNoRows() throws {
        let summary = try makeSummary(try seededContext())
        #expect(summary.balance.isZero)
        #expect(summary.monthExpenses.isZero)
        #expect(summary.isEmpty)
    }

    @Test func anInvalidCurrencyThrows() {
        #expect(throws: MoneyError.self) {
            try WidgetSummary(transactions: [], currencyCode: "XYZ", now: .now, categoryName: { _ in "" })
        }
    }

    @Test func theSampleHasTheMockupsNumbers() {
        let sample = WidgetSummary.sample
        #expect(sample.balance.minorUnits == 1_248_000)
        #expect(sample.monthExpenses.minorUnits == 175_950)
        #expect(sample.recent.count == WidgetSummary.recentLimit)
    }

    // MARK: - Helpers

    private func makeSummary(_ context: ModelContext) throws -> WidgetSummary {
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        return try WidgetSummary(transactions: transactions, currencyCode: "USD",
                                 now: try date("2026-10-21T12:00:00Z"), timeZone: utc, locale: locale) { category in
            category.map { "Category \($0.name)" } ?? "No category"
        }
    }

    private func seededContext() throws -> ModelContext {
        let context = try makeInMemoryContext()
        try CategorySeeder.seedDefaults(in: context)
        return context
    }

    private func add(_ cents: Int64, _ systemKey: String, _ iso: String, title: String = "",
                     currency: String = "USD", in context: ModelContext) throws {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.systemKey == systemKey })
        let category = try #require(try context.fetch(descriptor).first)
        context.insert(Transaction(amount: try Money(minorUnits: cents, currencyCode: currency), kind: category.kind,
                                   title: title, date: try date(iso), category: category))
        try context.save()
    }

    private func date(_ iso: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: iso))
    }
}

//
//  PreviewDataTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import SwiftData
import Testing
@testable import GuldrCore

/// The preview data must keep reproducing the mockups' numbers; screens are compared against them.
struct PreviewDataTests {

    private let timeZone = TimeZone(identifier: "America/Mexico_City")!

    private func transactions() throws -> [Transaction] {
        let controller = try PreviewData.makeController(timeZone: timeZone)
        return try ModelContext(controller.container).fetch(FetchDescriptor<Transaction>())
    }

    private func total(_ transactions: [Transaction], _ kind: TransactionKind, month: Int) -> Int64 {
        guard let yearMonth = YearMonth(year: 2026, month: month) else { return -1 }
        return transactions
            .filter { $0.kind == kind && yearMonth.contains($0.date, timeZone: timeZone) }
            .reduce(0) { $0 + $1.amountMinorUnits }
    }

    struct MonthTotals: Sendable, CustomTestStringConvertible {
        let month: Int
        let income: Int64
        let expenses: Int64
        var testDescription: String { "month \(month)" }
    }

    @Test(arguments: [
        MonthTotals(month: 4, income: 500_000, expenses: 231_000),
        MonthTotals(month: 5, income: 540_000, expenses: 214_000),
        MonthTotals(month: 6, income: 500_000, expenses: 248_000),
        MonthTotals(month: 7, income: 565_000, expenses: 198_000),
        MonthTotals(month: 8, income: 500_000, expenses: 220_500),
        MonthTotals(month: 9, income: 500_000, expenses: 175_950)
    ])
    func monthsMatchTheChartsMockup(expected: MonthTotals) throws {
        let all = try transactions()
        #expect(total(all, .income, month: expected.month) == expected.income)
        #expect(total(all, .expense, month: expected.month) == expected.expenses)
    }

    @Test func septemberCategoriesMatchTheChartsMockup() throws {
        guard let september = YearMonth(year: 2026, month: 9) else { return }
        let expenses = try transactions().filter { $0.kind == .expense && september.contains($0.date, timeZone: timeZone) }
        let byCategory = Dictionary(grouping: expenses) { $0.category?.systemKey ?? "none" }
            .mapValues { $0.reduce(0) { $0 + $1.amountMinorUnits } }
        #expect(byCategory == [
            "housing": 85_000, "food": 31_200, "shopping": 21_650, "transport": 14_500,
            "other_expense": 10_000, "entertainment": 9_600, "health": 4_000
        ])
    }

    @Test func septemberBudgetsMatchTheBudgetMockup() throws {
        let controller = try PreviewData.makeController(timeZone: timeZone)
        let budgets = try ModelContext(controller.container).fetch(FetchDescriptor<Budget>())
        #expect(budgets.allSatisfy { $0.yearMonth == 202_609 })
        #expect(budgets.reduce(0) { $0 + $1.limitMinorUnits } == 203_000)
        let entertainment = try #require(budgets.first { $0.category?.systemKey == "entertainment" })
        #expect(entertainment.limitMinorUnits == 8_000)
    }

    @Test func everyTransactionHasACategoryAndTheCurrency() throws {
        let all = try transactions()
        #expect(all.allSatisfy { $0.category != nil && $0.currencyCode == PreviewData.currencyCode })
    }

    @Test func referenceDateIsTheMockupsNow() {
        let formatter = DayLabelFormatter(locale: Locale(identifier: "en_US"), timeZone: timeZone)
        let now = PreviewData.referenceDate(in: timeZone)
        #expect(YearMonth(containing: now, timeZone: timeZone).rawValue == 202_609)
        #expect(formatter.label(for: now, relativeTo: now) == "Today")
    }

    // MARK: - Ending at another month (Debug's -demoData)

    /// Moved to end on Feb 10, 2027 at 8:00: a short month, early in the day and early in the month.
    @Test func movedDataEndsInTheCurrentMonthWithTheSameTotals() throws {
        let now = try #require(YearMonth.calendar(timeZone).date(from: DateComponents(year: 2027, month: 2, day: 10,
                                                                                      hour: 8)))
        let controller = try PersistenceController(mode: .inMemory)
        let context = ModelContext(controller.container)
        try PreviewData.populate(context, endingAt: now, timeZone: timeZone)
        let all = try context.fetch(FetchDescriptor<Transaction>())

        #expect(all.allSatisfy { $0.date < now })
        func totals(_ year: Int, _ month: Int) -> (Int64, Int64) {
            guard let yearMonth = YearMonth(year: year, month: month) else { return (-1, -1) }
            let inMonth = all.filter { yearMonth.contains($0.date, timeZone: timeZone) }
            return (inMonth.filter { $0.kind == .income }.reduce(0) { $0 + $1.amountMinorUnits },
                    inMonth.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountMinorUnits })
        }
        // September becomes February, August becomes January, April becomes September 2026.
        #expect(totals(2027, 2) == (500_000, 175_950))
        #expect(totals(2027, 1) == (500_000, 220_500))
        #expect(totals(2026, 9) == (500_000, 231_000))

        let budgets = try context.fetch(FetchDescriptor<Budget>())
        #expect(budgets.allSatisfy { $0.yearMonth == 202_702 })
        let days = try context.fetch(FetchDescriptor<LoggedDay>())
        #expect(days.map(\.dayKey).max() == LocalDay(containing: now, timeZone: timeZone).rawValue)
    }

    // MARK: - Flavors (-demoData in each App Store localization)

    @Test func flavorFollowsTheLocale() {
        #expect(PreviewData.Flavor.matching(Locale(identifier: "en_US")) == .mockups)
        let mexico = PreviewData.Flavor.matching(Locale(identifier: "es_MX"))
        #expect(mexico.currencyCode == "MXN" && mexico.amountScale == 10 && mexico.titles == .mexicanSpanish)
        let spain = PreviewData.Flavor.matching(Locale(identifier: "es_ES"))
        #expect(spain.currencyCode == "EUR" && spain.amountScale == 1 && spain.titles == .spainSpanish)
        // Titles follow the language, the currency the region.
        #expect(PreviewData.Flavor.matching(Locale(identifier: "en_MX")).titles == .english)
        #expect(PreviewData.Flavor.matching(Locale(identifier: "es_US")).currencyCode == "USD")
    }

    @Test(arguments: ["es_MX", "es_ES"])
    func spanishDataTranslatesEveryTitleAndScalesEveryAmount(localeID: String) throws {
        let flavor = PreviewData.Flavor.matching(Locale(identifier: localeID))
        let now = try #require(YearMonth.calendar(timeZone).date(from: DateComponents(year: 2027, month: 2, day: 10,
                                                                                      hour: 8)))
        let english = try populated(endingAt: now, flavor: .mockups)
        let spanish = try populated(endingAt: now, flavor: flavor)

        #expect(Set(english.transactions.map(\.title)).isDisjoint(with: spanish.transactions.map(\.title)))
        #expect(spanish.transactions.allSatisfy { $0.currencyCode == flavor.currencyCode })
        #expect(spanish.budgets.allSatisfy { $0.currencyCode == flavor.currencyCode })
        #expect(sum(spanish.transactions.map(\.amountMinorUnits))
                == sum(english.transactions.map(\.amountMinorUnits)) * flavor.amountScale)
        #expect(sum(spanish.budgets.map(\.limitMinorUnits)) == 203_000 * flavor.amountScale)
    }

    private func populated(endingAt now: Date,
                           flavor: PreviewData.Flavor) throws -> (transactions: [Transaction], budgets: [Budget]) {
        let controller = try PersistenceController(mode: .inMemory)
        let context = ModelContext(controller.container)
        try PreviewData.populate(context, endingAt: now, timeZone: timeZone, flavor: flavor)
        return (try context.fetch(FetchDescriptor<Transaction>()), try context.fetch(FetchDescriptor<Budget>()))
    }

    private func sum(_ values: [Int64]) -> Int64 {
        values.reduce(0, +)
    }
}

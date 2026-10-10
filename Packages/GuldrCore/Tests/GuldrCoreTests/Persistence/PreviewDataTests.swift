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
}

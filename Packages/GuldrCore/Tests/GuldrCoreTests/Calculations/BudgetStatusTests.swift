//
//  BudgetStatusTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import SwiftData
import Testing
@testable import GuldrCore

struct BudgetStatusTests {

    private let utc = TimeZone(identifier: "UTC")!
    private let september = YearMonth(year: 2026, month: 9)!

    private func date(_ iso: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: iso))
    }

    private func category(_ name: String) -> Category {
        Category(name: name, symbolName: "circle", color: .gold, kind: .expense)
    }

    private func expense(_ cents: Int64, _ category: Category?, _ iso: String, currency: String = "USD") throws -> Transaction {
        Transaction(amount: try Money(minorUnits: cents, currencyCode: currency), kind: .expense,
                    date: try date(iso), category: category)
    }

    private func budget(_ cents: Int64, _ category: Category?, month: YearMonth? = nil, currency: String = "USD") throws -> Budget {
        Budget(month: month ?? september, limit: try Money(minorUnits: cents, currencyCode: currency), category: category)
    }

    @Test func reproducesTheBudgetMockup() throws {
        let controller = try PreviewData.makeController(timeZone: utc)
        let context = ModelContext(controller.container)
        let status = try BudgetStatus(
            budgets: try context.fetch(FetchDescriptor<Budget>()),
            transactions: try context.fetch(FetchDescriptor<Transaction>()),
            month: september, currencyCode: "USD", now: PreviewData.referenceDate(in: utc), timeZone: utc
        )
        let categories = try context.fetch(FetchDescriptor<Category>())
        let keys = status.lines.map { line in categories.first { $0.id == line.categoryID }?.systemKey }

        #expect(keys == ["entertainment", "food", "transport", "housing", "health"])  // by usage
        #expect(status.totalSpent.minorUnits == 144_300)      // "$1,443.00 of $2,030.00"
        #expect(status.totalLimit.minorUnits == 203_000)
        #expect(status.totalRemaining.minorUnits == 58_700)   // "$587 available"
        #expect(abs(status.overallUsage - 0.7108) < 0.0001)   // "71% used"
        #expect(status.daysLeft == 2)                         // "2 days left"
        #expect(status.overBudgetCount == 1)                  // "1 category over budget"
        let entertainment = try #require(status.lines.first)
        #expect(entertainment.isOver)
        #expect(entertainment.overAmount.minorUnits == 1_600) // "over its limit by $16.00"
        #expect(entertainment.remaining.isZero)
    }

    @Test func noBudgetsIsEmpty() throws {
        let status = try BudgetStatus(budgets: [], transactions: [], month: september, currencyCode: "USD",
                                      now: try date("2026-09-10T12:00:00Z"), timeZone: utc)
        #expect(status.lines.isEmpty)
        #expect(status.totalLimit.isZero && status.totalSpent.isZero)
        #expect(status.overallUsage == 0)
    }

    @Test func onlyThisMonthsExpensesInTheCategoryCount() throws {
        let food = category("Food")
        let other = category("Shopping")
        let transactions = [
            try expense(1_000, food, "2026-09-05T12:00:00Z"),
            try expense(2_000, food, "2026-08-31T23:59:59Z"),      // previous month
            try expense(4_000, food, "2026-10-01T00:00:00Z"),      // next month
            try expense(8_000, other, "2026-09-05T12:00:00Z"),     // no budget
            try expense(16_000, nil, "2026-09-05T12:00:00Z"),      // no category
            try expense(32_000, food, "2026-09-05T12:00:00Z", currency: "EUR"),
            Transaction(amount: try Money(minorUnits: 64_000, currencyCode: "USD"), kind: .income,
                        date: try date("2026-09-05T12:00:00Z"), category: food)
        ]
        let status = try BudgetStatus(budgets: [try budget(10_000, food)], transactions: transactions,
                                      month: september, currencyCode: "USD", now: try date("2026-09-10T12:00:00Z"), timeZone: utc)
        #expect(status.lines.map(\.spent.minorUnits) == [1_000])
        #expect(status.totalSpent.minorUnits == 1_000)
    }

    @Test func otherMonthsCurrenciesArchivedAndOrphanBudgetsAreSkipped() throws {
        let food = category("Food")
        let archived = category("Old")
        archived.isArchived = true
        let budgets = [
            try budget(10_000, food),
            try budget(10_000, food, month: september.next),
            try budget(10_000, category("Travel"), currency: "EUR"),
            try budget(10_000, archived),
            try budget(10_000, nil)
        ]
        let status = try BudgetStatus(budgets: budgets, transactions: [], month: september, currencyCode: "USD",
                                      now: try date("2026-09-10T12:00:00Z"), timeZone: utc)
        #expect(status.lines.map(\.categoryID) == [food.id])
    }

    @Test func duplicateBudgetsCountOnceWhateverTheOrder() throws {
        let food = category("Food")
        let first = try budget(10_000, food)
        let second = try budget(20_000, food)
        let expected = min(first.id.uuidString, second.id.uuidString) == first.id.uuidString ? first.id : second.id
        for order in [[first, second], [second, first]] {
            let status = try BudgetStatus(budgets: order, transactions: [], month: september, currencyCode: "USD",
                                          now: try date("2026-09-10T12:00:00Z"), timeZone: utc)
            #expect(status.lines.map(\.budgetID) == [expected])
        }
    }

    @Test func usageHandlesZeroAndExactLimits() throws {
        let exact = BudgetStatus.Line(budgetID: UUID(), categoryID: UUID(), spent: try usd(5_000), limit: try usd(5_000))
        #expect(exact.usage == 1 && !exact.isOver && exact.remaining.isZero && exact.overAmount.isZero)
        let zeroLimit = BudgetStatus.Line(budgetID: UUID(), categoryID: UUID(), spent: try usd(1), limit: try usd(0))
        #expect(zeroLimit.usage == 1 && zeroLimit.isOver)
        let unused = BudgetStatus.Line(budgetID: UUID(), categoryID: UUID(), spent: try usd(0), limit: try usd(0))
        #expect(unused.usage == 0 && !unused.isOver)
    }

    @Test(arguments: [
        ("2026-09-28T09:41:00Z", 2), ("2026-09-30T23:59:00Z", 0), ("2026-09-01T00:00:00Z", 29),
        ("2026-08-15T12:00:00Z", 30), ("2026-10-02T12:00:00Z", 0)
    ])
    func daysLeftExcludesToday(now: String, expected: Int) throws {
        let status = try BudgetStatus(budgets: [], transactions: [], month: september, currencyCode: "USD",
                                      now: try date(now), timeZone: utc)
        #expect(status.daysLeft == expected)
    }
}

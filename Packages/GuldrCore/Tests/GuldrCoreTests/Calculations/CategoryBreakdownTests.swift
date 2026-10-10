//
//  CategoryBreakdownTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import SwiftData
import Testing
@testable import GuldrCore

struct CategoryBreakdownTests {

    private let utc = TimeZone(identifier: "UTC")!
    private let september = YearMonth(year: 2026, month: 9)!

    private func expense(_ cents: Int64, _ category: Category?, day: Int = 10, currency: String = "USD",
                         kind: TransactionKind = .expense) throws -> Transaction {
        let date = try #require(YearMonth.calendar(utc).date(from: DateComponents(year: 2026, month: 9, day: day, hour: 12)))
        return Transaction(amount: try Money(minorUnits: cents, currencyCode: currency), kind: kind, date: date, category: category)
    }

    private func category(_ name: String, key: String? = nil) -> Category {
        Category(name: name, symbolName: "circle", color: .gold, kind: .expense, systemKey: key)
    }

    @Test func reproducesTheChartsMockup() throws {
        let controller = try PreviewData.makeController(timeZone: utc)
        let context = ModelContext(controller.container)
        let categories = try context.fetch(FetchDescriptor<Category>())
        let breakdown = try CategoryBreakdown(transactions: try context.fetch(FetchDescriptor<Transaction>()),
                                              month: september, currencyCode: "USD", timeZone: utc)

        let keys = breakdown.slices.map { slice -> String in
            guard case .category(let id) = slice.kind else { return "other" }
            return categories.first { $0.id == id }?.systemKey ?? "?"
        }
        // Seven categories fit: six named plus "Other", which goes last instead of in value order.
        #expect(keys == ["housing", "food", "shopping", "transport", "entertainment", "health", "other"])
        #expect(breakdown.slices.map(\.total.minorUnits) == [85_000, 31_200, 21_650, 14_500, 9_600, 4_000, 10_000])
        #expect(breakdown.total.minorUnits == 175_950)                       // "$1,760" in the donut center
        #expect(breakdown.slices.map(\.percentage).reduce(0, +) == 100)
    }

    @Test func emptyPeriodHasNoSlices() throws {
        let breakdown = try CategoryBreakdown(transactions: [], month: september, currencyCode: "USD", timeZone: utc)
        #expect(breakdown.slices.isEmpty)
        #expect(breakdown.total.isZero)
    }

    @Test func singleTransactionIsOneFullSlice() throws {
        let food = category("Food")
        let breakdown = try CategoryBreakdown(transactions: [try expense(4_280, food)], month: september,
                                              currencyCode: "USD", timeZone: utc)
        #expect(breakdown.slices.map(\.kind) == [.category(food.id)])
        #expect(breakdown.slices.map(\.percentage) == [100])
    }

    @Test func smallCategoriesSeededOtherAndUncategorizedShareOneSlice() throws {
        let seededOther = category("Other", key: "other_expense")
        let named = (1...8).map { category("C\($0)") }
        var transactions = try named.enumerated().map { index, category in
            try expense(Int64(10_000 - index * 1_000), category)     // C1 10,000 … C8 3,000
        }
        transactions.append(try expense(500, seededOther))
        transactions.append(try expense(250, nil))

        let breakdown = try CategoryBreakdown(transactions: transactions, month: september, currencyCode: "USD", timeZone: utc)

        #expect(breakdown.slices.count == 7)
        #expect(breakdown.slices.prefix(6).map(\.kind) == named.prefix(6).map { .category($0.id) })
        let last = try #require(breakdown.slices.last)
        #expect(last.total.minorUnits == 4_000 + 3_000 + 500 + 250)
        guard case .other(let ids) = last.kind else {
            Issue.record("The last slice must be Other")
            return
        }
        #expect(Set(ids) == Set([named[6].id, named[7].id, seededOther.id]))
    }

    @Test func onlyExpensesInThePeriodAndCurrencyCount() throws {
        let food = category("Food")
        let transactions = [
            try expense(1_000, food),
            try expense(2_000, food, currency: "EUR"),
            try expense(4_000, food, kind: .income)
        ]
        let october = try CategoryBreakdown(transactions: transactions, month: september.next, currencyCode: "USD", timeZone: utc)
        #expect(october.slices.isEmpty)
        let septemberBreakdown = try CategoryBreakdown(transactions: transactions, month: september, currencyCode: "USD", timeZone: utc)
        #expect(septemberBreakdown.total.minorUnits == 1_000)
    }

    @Test func archivedCategoriesKeepTheirHistory() throws {
        let archived = category("Old")
        archived.isArchived = true
        let breakdown = try CategoryBreakdown(transactions: [try expense(1_000, archived)], month: september,
                                              currencyCode: "USD", timeZone: utc)
        #expect(breakdown.slices.map(\.kind) == [.category(archived.id)])
    }

    @Test func percentagesAlwaysAddUpTo100() {
        #expect(CategoryBreakdown.wholePercentages([1, 1, 1]) == [34, 33, 33])
        #expect(CategoryBreakdown.wholePercentages([2, 1]) == [67, 33])
        #expect(CategoryBreakdown.wholePercentages([0, 0]) == [0, 0])
        #expect(CategoryBreakdown.wholePercentages([999, 1]) == [100, 0])
        for values in [[7, 7, 7, 7, 7, 7], [123, 456, 789], [1, 2, 3, 4, 5, 6, 7]] as [[Int64]] {
            #expect(CategoryBreakdown.wholePercentages(values).reduce(0, +) == 100)
        }
    }
}

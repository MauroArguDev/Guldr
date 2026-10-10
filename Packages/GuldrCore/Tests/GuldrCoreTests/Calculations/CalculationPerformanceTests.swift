//
//  CalculationPerformanceTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import SwiftData
import Testing
@testable import GuldrCore

/// A heavy personal year: 5,000 transactions across 12 months and every default category, in a real
/// (in-memory) store. Each screen's calculations must stay far below what a user would notice, with
/// room for CI machines that are several times slower than a developer Mac.
@Suite(.serialized)
struct CalculationPerformanceTests {

    static let transactionCount = 5_000
    /// Per calculation. Measured locally at a few milliseconds; the margin absorbs slow CI runners.
    static let budget = Duration.milliseconds(250)

    private let utc = TimeZone(identifier: "UTC")!
    private let september = YearMonth(year: 2026, month: 9)!

    private struct GeneratedYear {
        let context: ModelContext
        let transactions: [Transaction]
        let budgets: [Budget]
    }

    private func makeYear() throws -> GeneratedYear {
        let controller = try PersistenceController(mode: .inMemory)
        let context = ModelContext(controller.container)
        let categories = try context.fetch(FetchDescriptor<Category>())
        let start = september.adding(months: -11).dateInterval(in: utc).start
        let span = september.dateInterval(in: utc).end.timeIntervalSince(start)

        var generator = SeededGenerator(seed: 2026)
        for index in 0..<Self.transactionCount {
            let category = categories[index % categories.count]
            let date = start.addingTimeInterval(Double.random(in: 0..<span, using: &generator))
            let cents = Int64.random(in: 100...(category.kind == .income ? 500_000 : 30_000), using: &generator)
            context.insert(Transaction(amount: try usd(cents), kind: category.kind, title: "Item \(index)",
                                       note: index.isMultiple(of: 7) ? "Café con leche" : "", date: date, category: category))
        }
        for category in categories where category.kind == .expense {
            context.insert(Budget(month: september, limit: try usd(50_000), category: category))
        }
        try context.save()
        return GeneratedYear(context: context, transactions: try context.fetch(FetchDescriptor<Transaction>()),
                             budgets: try context.fetch(FetchDescriptor<Budget>()))
    }

    private func measure(_ name: String, _ work: () throws -> Void) rethrows -> Duration {
        let clock = ContinuousClock()
        let elapsed = try clock.measure(work)
        print("[performance] \(name): \(elapsed)")
        #expect(elapsed < Self.budget, "\(name) took \(elapsed) for \(Self.transactionCount) transactions")
        return elapsed
    }

    @Test func everyCalculationStaysWithinBudget() throws {
        let year = try makeYear()
        #expect(year.transactions.count == Self.transactionCount)
        let now = september.dateInterval(in: utc).start.addingTimeInterval(27 * 86_400)

        _ = try measure("fetch all") { _ = try year.context.fetch(FetchDescriptor<Transaction>()) }
        _ = try measure("MonthSummary") {
            _ = try MonthSummary(transactions: year.transactions, month: september, currencyCode: "USD", timeZone: utc)
        }
        _ = try measure("BudgetStatus") {
            _ = try BudgetStatus(budgets: year.budgets, transactions: year.transactions, month: september,
                                 currencyCode: "USD", now: now, timeZone: utc)
        }
        _ = try measure("CategoryBreakdown (1Y)") {
            let period = DateInterval(start: september.adding(months: -11).dateInterval(in: utc).start,
                                      end: september.dateInterval(in: utc).end)
            _ = try CategoryBreakdown(transactions: year.transactions, period: period, currencyCode: "USD")
        }
        _ = try measure("CashFlowSeries (1Y)") {
            _ = try CashFlowSeries(transactions: year.transactions, period: .oneYear, endingWith: september,
                                   currencyCode: "USD", timeZone: utc)
        }
        _ = measure("TransactionQuery search + group") {
            let matches = TransactionQuery(kind: .expense, searchText: "cafe").apply(to: year.transactions)
            _ = TransactionQuery.groupedByDay(matches, timeZone: utc)
        }
        _ = measure("TransactionQuery all + group") {
            _ = TransactionQuery.groupedByDay(TransactionQuery().apply(to: year.transactions), timeZone: utc)
        }
    }
}

/// Deterministic random numbers, so the generated year is the same on every run (SplitMix64).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

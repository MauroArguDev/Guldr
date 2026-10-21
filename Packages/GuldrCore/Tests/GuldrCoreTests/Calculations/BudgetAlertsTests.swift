//
//  BudgetAlertsTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation
import SwiftData
import Testing
@testable import GuldrCore

/// 80 % and 100 % per category, once each per month, in UTC on October 2026.
struct BudgetAlertsTests {

    private let utc = TimeZone(identifier: "UTC")!
    private let october = YearMonth(year: 2026, month: 10)!

    @Test func eightyPercentIsMetExactly() throws {
        let fixture = try Fixture()
        try fixture.budget(40_000, "food", october)
        try fixture.spend(31_999, "food", "2026-10-05T09:00:00Z")
        var ledger = BudgetAlertLedger()
        #expect(ledger.dueAlerts(for: try fixture.status(october)).isEmpty)

        try fixture.spend(1, "food", "2026-10-06T09:00:00Z")
        let alerts = ledger.dueAlerts(for: try fixture.status(october))
        #expect(alerts.map(\.threshold) == [.nearing])
        #expect(alerts.first?.spent.minorUnits == 32_000)
        #expect(alerts.first?.limit.minorUnits == 40_000)
    }

    @Test func eachThresholdIsSentOnce() throws {
        let fixture = try Fixture()
        try fixture.budget(40_000, "food", october)
        try fixture.spend(33_000, "food", "2026-10-05T09:00:00Z")
        var ledger = BudgetAlertLedger()
        #expect(ledger.dueAlerts(for: try fixture.status(october)).map(\.threshold) == [.nearing])
        #expect(ledger.dueAlerts(for: try fixture.status(october)).isEmpty)

        try fixture.spend(7_000, "food", "2026-10-06T09:00:00Z")
        #expect(ledger.dueAlerts(for: try fixture.status(october)).map(\.threshold) == [.reached])
        try fixture.spend(5_000, "food", "2026-10-07T09:00:00Z")
        #expect(ledger.dueAlerts(for: try fixture.status(october)).isEmpty)
    }

    @Test func jumpingPastBothSendsOnlyTheHigher() throws {
        let fixture = try Fixture()
        try fixture.budget(10_000, "transport", october)
        try fixture.spend(12_000, "transport", "2026-10-05T09:00:00Z")
        var ledger = BudgetAlertLedger()
        #expect(ledger.dueAlerts(for: try fixture.status(october)).map(\.threshold) == [.reached])
        #expect(ledger.keys.count == 2)
    }

    @Test func droppingBackAndRisingAgainDoesntRepeat() throws {
        let fixture = try Fixture()
        try fixture.budget(10_000, "food", october)
        let lunch = try fixture.spend(8_500, "food", "2026-10-05T09:00:00Z")
        var ledger = BudgetAlertLedger()
        #expect(ledger.dueAlerts(for: try fixture.status(october)).count == 1)

        fixture.context.delete(lunch)
        try fixture.context.save()
        #expect(ledger.dueAlerts(for: try fixture.status(october)).isEmpty)
        try fixture.spend(8_200, "food", "2026-10-08T09:00:00Z")
        #expect(ledger.dueAlerts(for: try fixture.status(october)).isEmpty)
    }

    @Test func aNewMonthStartsFresh() throws {
        let fixture = try Fixture()
        let november = october.next
        try fixture.budget(10_000, "food", october)
        try fixture.budget(10_000, "food", november)
        try fixture.spend(9_000, "food", "2026-10-05T09:00:00Z")
        try fixture.spend(9_000, "food", "2026-11-03T09:00:00Z")
        var ledger = BudgetAlertLedger()
        #expect(ledger.dueAlerts(for: try fixture.status(october)).count == 1)

        let alerts = ledger.dueAlerts(for: try fixture.status(november))
        #expect(alerts.map(\.month) == [november])
        // October's keys are gone, so the ledger never grows past one month.
        #expect(ledger.keys.allSatisfy { $0.hasPrefix("202611:") })
    }

    @Test func everyCategoryAlertsOnItsOwn() throws {
        let fixture = try Fixture()
        try fixture.budget(10_000, "food", october)
        try fixture.budget(10_000, "transport", october)
        try fixture.budget(10_000, "health", october)
        try fixture.spend(10_500, "food", "2026-10-05T09:00:00Z")
        try fixture.spend(8_000, "transport", "2026-10-05T09:00:00Z")
        try fixture.spend(1_000, "health", "2026-10-05T09:00:00Z")
        var ledger = BudgetAlertLedger()
        let alerts = ledger.dueAlerts(for: try fixture.status(october))
        // Highest usage first, as BudgetStatus orders its lines.
        #expect(alerts.map(\.threshold) == [.reached, .nearing])
        #expect(alerts.map(\.categoryID) == [try fixture.category("food").id, try fixture.category("transport").id])
    }

    @Test func storedKeysRoundTrip() throws {
        let fixture = try Fixture()
        try fixture.budget(10_000, "food", october)
        try fixture.spend(9_000, "food", "2026-10-05T09:00:00Z")
        var ledger = BudgetAlertLedger()
        _ = ledger.dueAlerts(for: try fixture.status(october))

        var restored = BudgetAlertLedger(keys: ledger.keys.sorted())
        #expect(restored == ledger)
        #expect(restored.dueAlerts(for: try fixture.status(october)).isEmpty)
    }
}

// MARK: - Fixture

private struct Fixture {

    let context: ModelContext
    let utc = TimeZone(identifier: "UTC")!

    init() throws {
        context = try makeInMemoryContext()
        try CategorySeeder.seedDefaults(in: context)
    }

    func category(_ systemKey: String) throws -> Category {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.systemKey == systemKey })
        return try #require(try context.fetch(descriptor).first)
    }

    func budget(_ cents: Int64, _ systemKey: String, _ month: YearMonth) throws {
        context.insert(Budget(month: month, limit: try usd(cents), category: try category(systemKey)))
        try context.save()
    }

    @discardableResult
    func spend(_ cents: Int64, _ systemKey: String, _ iso: String) throws -> Transaction {
        let date = try #require(ISO8601DateFormatter().date(from: iso))
        let transaction = Transaction(amount: try usd(cents), kind: .expense, date: date, category: try category(systemKey))
        context.insert(transaction)
        try context.save()
        return transaction
    }

    func status(_ month: YearMonth) throws -> BudgetStatus {
        try BudgetStatus(budgets: try context.fetch(FetchDescriptor<Budget>()),
                         transactions: try context.fetch(FetchDescriptor<Transaction>()),
                         month: month, currencyCode: "USD", now: month.dateInterval(in: utc).start, timeZone: utc)
    }
}

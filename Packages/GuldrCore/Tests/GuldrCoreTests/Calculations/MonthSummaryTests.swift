//
//  MonthSummaryTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import SwiftData
import Testing
@testable import GuldrCore

struct MonthSummaryTests {

    private let utc = TimeZone(identifier: "UTC")!
    private let september = YearMonth(year: 2026, month: 9)!

    private func date(_ iso: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: iso))
    }

    private func transaction(_ cents: Int64, _ kind: TransactionKind, _ iso: String,
                             currency: String = "USD") throws -> Transaction {
        Transaction(amount: try Money(minorUnits: cents, currencyCode: currency), kind: kind, date: try date(iso))
    }

    @Test func emptyDataIsAllZero() throws {
        let summary = try MonthSummary(transactions: [], month: september, currencyCode: "USD", timeZone: utc)
        #expect(summary.balance.isZero && summary.income.isZero && summary.expenses.isZero)
        #expect(summary.savingsRate == 0)
        #expect(summary.balance.currencyCode == "USD")
    }

    @Test func reproducesTheDashboardMockup() throws {
        let controller = try PreviewData.makeController(timeZone: utc)
        let all = try ModelContext(controller.container).fetch(FetchDescriptor<Transaction>())
        let summary = try MonthSummary(transactions: all, month: september, currencyCode: "USD", timeZone: utc)

        #expect(summary.income.minorUnits == 500_000)
        #expect(summary.expenses.minorUnits == 175_950)
        #expect(summary.net.minorUnits == 324_050)
        #expect(abs(summary.savingsRate - 0.6481) < 0.0001)   // "Savings rate 64.8%"
        #expect(summary.balance.minorUnits == 1_817_550)      // all-time net of April–September
    }

    @Test func balanceIsAllTimeAndMonthTotalsAreNot() throws {
        let transactions = [
            try transaction(100_000, .income, "2026-08-25T09:00:00Z"),
            try transaction(30_000, .expense, "2026-08-26T09:00:00Z"),
            try transaction(50_000, .income, "2026-09-25T09:00:00Z"),
            try transaction(20_000, .expense, "2026-09-26T09:00:00Z"),
            try transaction(5_000, .expense, "2026-10-01T09:00:00Z")
        ]
        let summary = try MonthSummary(transactions: transactions, month: september, currencyCode: "USD", timeZone: utc)
        #expect(summary.balance.minorUnits == 95_000)
        #expect(summary.income.minorUnits == 50_000)
        #expect(summary.expenses.minorUnits == 20_000)
    }

    @Test func monthBoundariesFollowTheTimeZone() throws {
        // 03:00 UTC on Oct 1 is still Sept 30 in Mexico City.
        let lateNight = try transaction(1_000, .expense, "2026-10-01T03:00:00Z")
        let mexico = TimeZone(identifier: "America/Mexico_City")!
        #expect(try MonthSummary(transactions: [lateNight], month: september, currencyCode: "USD", timeZone: mexico)
            .expenses.minorUnits == 1_000)
        #expect(try MonthSummary(transactions: [lateNight], month: september, currencyCode: "USD", timeZone: utc)
            .expenses.isZero)
    }

    @Test func theFirstInstantOfNextMonthIsExcluded() throws {
        let midnight = try transaction(1_000, .expense, "2026-10-01T00:00:00Z")
        let lastSecond = try transaction(500, .expense, "2026-09-30T23:59:59Z")
        let summary = try MonthSummary(transactions: [midnight, lastSecond], month: september,
                                       currencyCode: "USD", timeZone: utc)
        #expect(summary.expenses.minorUnits == 500)
    }

    @Test func otherCurrenciesAreIgnored() throws {
        let transactions = [
            try transaction(50_000, .income, "2026-09-25T09:00:00Z"),
            try transaction(900_000, .income, "2026-09-25T09:00:00Z", currency: "MXN"),
            try transaction(70_000, .expense, "2026-09-26T09:00:00Z", currency: "EUR")
        ]
        let summary = try MonthSummary(transactions: transactions, month: september, currencyCode: "usd", timeZone: utc)
        #expect(summary.income.minorUnits == 50_000)
        #expect(summary.expenses.isZero)
        #expect(summary.balance.minorUnits == 50_000)
        #expect(summary.income.currencyCode == "USD")
    }

    @Test func savingsRateIsClampedAndZeroWithoutIncome() throws {
        let overspent = [
            try transaction(10_000, .income, "2026-09-02T09:00:00Z"),
            try transaction(25_000, .expense, "2026-09-03T09:00:00Z")
        ]
        let summary = try MonthSummary(transactions: overspent, month: september, currencyCode: "USD", timeZone: utc)
        #expect(summary.savingsRate == 0)
        #expect(summary.net.minorUnits == -15_000)

        let onlyExpenses = [try transaction(25_000, .expense, "2026-09-03T09:00:00Z")]
        #expect(try MonthSummary(transactions: onlyExpenses, month: september, currencyCode: "USD", timeZone: utc)
            .savingsRate == 0)

        let onlyIncome = [try transaction(25_000, .income, "2026-09-03T09:00:00Z")]
        #expect(try MonthSummary(transactions: onlyIncome, month: september, currencyCode: "USD", timeZone: utc)
            .savingsRate == 1)
    }

    @Test func anUnknownCurrencyIsATypedError() {
        #expect(throws: MoneyError.unknownCurrency("XYZ")) {
            try MonthSummary(transactions: [], month: september, currencyCode: "XYZ", timeZone: utc)
        }
    }

    @Test func overflowIsReportedNotWrapped() throws {
        let huge = [
            try transaction(.max, .income, "2026-09-01T09:00:00Z"),
            try transaction(1, .income, "2026-09-02T09:00:00Z")
        ]
        #expect(throws: MoneyError.overflow) {
            try MonthSummary(transactions: huge, month: september, currencyCode: "USD", timeZone: utc)
        }
    }
}

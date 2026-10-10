//
//  CashFlowSeriesTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import SwiftData
import Testing
@testable import GuldrCore

struct CashFlowSeriesTests {

    private let utc = TimeZone(identifier: "UTC")!
    private let september = YearMonth(year: 2026, month: 9)!
    private let enUS = Locale(identifier: "en_US")      // weeks start on Sunday
    private let esMX = Locale(identifier: "es_MX")      // weeks start on Sunday too
    private let esES = Locale(identifier: "es_ES")      // weeks start on Monday

    private func previewTransactions() throws -> [Transaction] {
        let controller = try PreviewData.makeController(timeZone: utc)
        return try ModelContext(controller.container).fetch(FetchDescriptor<Transaction>())
    }

    private func transaction(_ cents: Int64, _ kind: TransactionKind, _ iso: String, currency: String = "USD") throws -> Transaction {
        Transaction(amount: try Money(minorUnits: cents, currencyCode: currency), kind: kind,
                    date: try #require(ISO8601DateFormatter().date(from: iso)))
    }

    @Test func sixMonthsReproduceTheChartsMockup() throws {
        let series = try CashFlowSeries(transactions: try previewTransactions(), period: .sixMonths,
                                        endingWith: september, currencyCode: "USD", timeZone: utc, locale: enUS)
        #expect(series.granularity == .month)
        #expect(series.buckets.map(\.income.minorUnits) == [500_000, 540_000, 500_000, 565_000, 500_000, 500_000])
        #expect(series.buckets.map(\.expenses.minorUnits) == [231_000, 214_000, 248_000, 198_000, 220_500, 175_950])
        #expect(series.totalIncome.minorUnits == 3_105_000)    // "Income $31,050"
        #expect(series.totalExpenses.minorUnits == 1_287_450)  // "Expenses $12,875"
        #expect(series.net.minorUnits == 1_817_550)            // "Saved $18,176"
    }

    @Test func oneYearKeepsEmptyMonths() throws {
        let series = try CashFlowSeries(transactions: try previewTransactions(), period: .oneYear,
                                        endingWith: september, currencyCode: "USD", timeZone: utc, locale: enUS)
        #expect(series.buckets.count == 12)
        #expect(series.buckets.first?.interval.start == YearMonth(year: 2025, month: 10)?.dateInterval(in: utc).start)
        #expect(series.buckets.prefix(6).allSatisfy { $0.income.isZero && $0.expenses.isZero })
    }

    @Test func threeMonthsCrossTheYear() throws {
        let january = try #require(YearMonth(year: 2027, month: 1))
        let series = try CashFlowSeries(transactions: [], period: .threeMonths, endingWith: january,
                                        currencyCode: "USD", timeZone: utc, locale: enUS)
        #expect(series.buckets.map { YearMonth(containing: $0.interval.start, timeZone: utc).rawValue } == [202_611, 202_612, 202_701])
    }

    @Test func oneMonthSplitsIntoClippedWeeks() throws {
        // September 2026 starts on a Tuesday and ends on a Wednesday.
        let sundayWeeks = try CashFlowSeries(transactions: [], period: .oneMonth, endingWith: september,
                                             currencyCode: "USD", timeZone: utc, locale: enUS)
        let calendar = YearMonth.calendar(utc)
        let days = sundayWeeks.buckets.map { calendar.component(.day, from: $0.interval.start) }
        #expect(sundayWeeks.granularity == .week)
        #expect(days == [1, 6, 13, 20, 27])
        #expect(sundayWeeks.buckets.last?.interval.end == september.dateInterval(in: utc).end)

        let mondayWeeks = try CashFlowSeries(transactions: [], period: .oneMonth, endingWith: september,
                                             currencyCode: "USD", timeZone: utc, locale: esES)
        #expect(mondayWeeks.buckets.map { calendar.component(.day, from: $0.interval.start) } == [1, 7, 14, 21, 28])
    }

    @Test func weeksCoverTheMonthWithoutGapsOrOverlaps() throws {
        for locale in [enUS, esMX, esES] {
            for month in 1...12 {
                let yearMonth = try #require(YearMonth(year: 2026, month: month))
                let buckets = try CashFlowSeries(transactions: [], period: .oneMonth, endingWith: yearMonth,
                                                 currencyCode: "USD", timeZone: utc, locale: locale).buckets
                let interval = yearMonth.dateInterval(in: utc)
                #expect(buckets.first?.interval.start == interval.start)
                #expect(buckets.last?.interval.end == interval.end)
                #expect(zip(buckets, buckets.dropFirst()).allSatisfy { $0.interval.end == $1.interval.start })
                #expect((4...6).contains(buckets.count))
            }
        }
    }

    @Test func oneMonthReproducesSeptemberWeekByWeek() throws {
        let series = try CashFlowSeries(transactions: try previewTransactions(), period: .oneMonth,
                                        endingWith: september, currencyCode: "USD", timeZone: utc, locale: enUS)
        #expect(series.totalIncome.minorUnits == 500_000)
        #expect(series.totalExpenses.minorUnits == 175_950)
        #expect(series.buckets.map(\.income.minorUnits) == [0, 0, 0, 500_000, 0])   // salary on Sept 25
    }

    @Test func otherCurrenciesAndOutOfRangeDatesAreIgnored() throws {
        let transactions = [
            try transaction(1_000, .expense, "2026-09-10T12:00:00Z"),
            try transaction(2_000, .expense, "2026-09-10T12:00:00Z", currency: "EUR"),
            try transaction(4_000, .expense, "2026-06-30T23:59:59Z"),   // before 3M
            try transaction(8_000, .expense, "2026-10-01T00:00:00Z")    // after the end month
        ]
        let series = try CashFlowSeries(transactions: transactions, period: .threeMonths, endingWith: september,
                                        currencyCode: "USD", timeZone: utc, locale: enUS)
        #expect(series.totalExpenses.minorUnits == 1_000)
    }

    @Test func netCanBeNegative() throws {
        let series = try CashFlowSeries(transactions: [try transaction(1_000, .expense, "2026-09-10T12:00:00Z")],
                                        period: .oneMonth, endingWith: september, currencyCode: "USD", timeZone: utc, locale: enUS)
        #expect(series.net.minorUnits == -1_000)
    }
}

//
//  AnalyticsModel.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 20/10/26.
//

import Foundation
import GuldrCore
import Observation
import SwiftData

/// The Analytics screen's numbers for the selected period, turned into display values. Like the other
/// screen models, the view owns the `@Query` and calls `update`; the model never holds a context.
@Observable
final class AnalyticsModel {

    /// The period's totals, above the charts.
    struct Totals: Equatable {
        let income: Money
        let expenses: Money
        /// Income minus expenses: "Saved", negative when the period spent more than it earned.
        let net: Money
    }

    /// One bar pair: a month, or a week for 1M.
    struct Bar: Identifiable, Equatable {
        /// The start of the month or week.
        let id: Date
        /// The chart's x value. Labels can repeat ("J" for June and July), so the chart plots this instead.
        var key: String { id.ISO8601Format() }
        /// The axis label: "Apr" (3M, 6M), "A" (1Y, twelve bars), "Oct 5" (1M, weekly).
        let label: String
        /// "April 2026" or "Oct 5 – 11", for the selection callout and VoiceOver.
        let title: String
        let income: Money
        let expenses: Money
        /// The bucket that contains today, drawn with a stronger label as in the mockup.
        let isCurrent: Bool
    }

    /// One donut slice: a category, or "Other" with the smallest ones and expenses without a category.
    struct Slice: Identifiable, Equatable {
        let id: String
        let name: String
        let color: CategoryColor
        let total: Money
        /// Whole percent; all slices add up to 100.
        let percentage: Int
    }

    private(set) var period: CashFlowSeries.Period = .sixMonths
    /// `nil` before the first `update`, or if the active currency is not a valid code.
    private(set) var totals: Totals?
    private(set) var bars: [Bar] = []
    /// Whether the period has any income or expense in the active currency.
    private(set) var hasData = false
    /// Whether there is any transaction at all, so an empty period can be told apart from a new user.
    private(set) var hasTransactions = false
    /// The donut follows the selected period (author's call, 2026-10-20): "October", "May – Oct",
    /// "Nov 2025 – Oct 2026".
    private(set) var rangeTitle = ""
    /// Largest first, "Other" last. Empty when the period has no expenses.
    private(set) var slices: [Slice] = []
    /// The period's expenses, in the donut's center.
    private(set) var expenseTotal: Money?

    init(locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent,
         now: @escaping () -> Date = { .now }) {
        self.locale = locale
        self.timeZone = timeZone
        self.now = now
    }

    /// Recomputes the period ending with the current month from the latest transactions in the active
    /// currency. The view calls it when they, the period, the currency or a save change.
    /// `categories` names and colors the donut's slices, archived ones included: reports keep their history.
    func update(transactions: [Transaction], categories: [Category], period: CashFlowSeries.Period,
                currencyCode: String) {
        self.period = period
        hasTransactions = !transactions.isEmpty
        let today = now()
        let month = YearMonth(containing: today, timeZone: timeZone)
        guard let series = try? CashFlowSeries(transactions: transactions, period: period, endingWith: month,
                                               currencyCode: currencyCode, timeZone: timeZone, locale: locale) else {
            totals = nil
            bars = []
            hasData = false
            slices = []
            expenseTotal = nil
            return
        }
        totals = Totals(income: series.totalIncome, expenses: series.totalExpenses, net: series.net)
        hasData = !series.totalIncome.isZero || !series.totalExpenses.isZero
        bars = series.buckets.map { bucket in
            Bar(id: bucket.interval.start,
                label: label(for: bucket.interval, granularity: series.granularity),
                title: title(for: bucket.interval, granularity: series.granularity),
                income: bucket.income, expenses: bucket.expenses,
                isCurrent: today >= bucket.interval.start && today < bucket.interval.end)
        }

        let first = month.adding(months: 1 - period.months)
        let interval = DateInterval(start: first.dateInterval(in: timeZone).start, end: month.dateInterval(in: timeZone).end)
        rangeTitle = rangeTitle(from: first, to: month)
        guard let breakdown = try? CategoryBreakdown(transactions: transactions, period: interval,
                                                     currencyCode: currencyCode) else {
            slices = []
            expenseTotal = nil
            return
        }
        expenseTotal = breakdown.total
        let byID = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        slices = breakdown.slices.map { slice in
            switch slice.kind {
            case .category(let id):
                let category = byID[id]
                return Slice(id: slice.id, name: category?.displayName ?? String(localized: "Uncategorized", locale: locale),
                             color: category?.color ?? .graphite, total: slice.total, percentage: slice.percentage)
            case .other:
                return Slice(id: slice.id, name: String(localized: "Other", locale: locale), color: .graphite,
                             total: slice.total, percentage: slice.percentage)
            }
        }
    }

    // MARK: - Private

    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let timeZone: TimeZone
    @ObservationIgnored private let now: () -> Date

    private var dateStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, timeZone: timeZone)
    }

    private func rangeTitle(from first: YearMonth, to last: YearMonth) -> String {
        let start = first.dateInterval(in: timeZone).start
        guard first != last else {
            var style = dateStyle.month(.wide)
            style.capitalizationContext = .standalone
            return start.formatted(style)
        }
        let end = last.dateInterval(in: timeZone).start
        var style = Date.IntervalFormatStyle(locale: locale, timeZone: timeZone).month(.abbreviated)
        if first.year != last.year { style = style.year() }
        return (start..<end).formatted(style)
    }

    private func label(for interval: DateInterval, granularity: CashFlowSeries.Granularity) -> String {
        switch granularity {
        case .week:
            interval.start.formatted(dateStyle.month(.abbreviated).day())
        case .month:
            // Twelve abbreviated months don't fit side by side on an iPhone; one letter does.
            interval.start.formatted(dateStyle.month(period == .oneYear ? .narrow : .abbreviated))
        }
    }

    private func title(for interval: DateInterval, granularity: CashFlowSeries.Granularity) -> String {
        switch granularity {
        case .week:
            // The interval's end is the next week's start; the last day shown is the one before it.
            let lastDay = interval.end.addingTimeInterval(-1)
            let style = Date.IntervalFormatStyle(locale: locale, timeZone: timeZone).month(.abbreviated).day()
            return (interval.start..<lastDay).formatted(style)
        case .month:
            return interval.start.formatted(dateStyle.month(.wide).year())
        }
    }
}

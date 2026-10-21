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

    private(set) var period: CashFlowSeries.Period = .sixMonths
    /// `nil` before the first `update`, or if the active currency is not a valid code.
    private(set) var totals: Totals?
    private(set) var bars: [Bar] = []
    /// Whether the period has any income or expense in the active currency.
    private(set) var hasData = false

    init(locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent,
         now: @escaping () -> Date = { .now }) {
        self.locale = locale
        self.timeZone = timeZone
        self.now = now
    }

    /// Recomputes the period ending with the current month from the latest transactions in the active
    /// currency. The view calls it when they, the period, the currency or a save change.
    func update(transactions: [Transaction], period: CashFlowSeries.Period, currencyCode: String) {
        self.period = period
        let today = now()
        let month = YearMonth(containing: today, timeZone: timeZone)
        guard let series = try? CashFlowSeries(transactions: transactions, period: period, endingWith: month,
                                               currencyCode: currencyCode, timeZone: timeZone, locale: locale) else {
            totals = nil
            bars = []
            hasData = false
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
    }

    // MARK: - Private

    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let timeZone: TimeZone
    @ObservationIgnored private let now: () -> Date

    private var dateStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, timeZone: timeZone)
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

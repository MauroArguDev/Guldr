//
//  CashFlowSeries.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation

/// Income and expenses over time: the bars of the Charts screen and its period totals.
///
/// Buckets end with the given month. `.oneMonth` splits that month into calendar weeks (starting on
/// the locale's first weekday, clipped to the month); the other periods use one bucket per month.
/// Empty buckets are kept, so the chart's time axis never skips. Other currencies are ignored (ADR 005).
public struct CashFlowSeries: Equatable, Sendable {

    public enum Period: String, CaseIterable, Sendable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"

        /// How many months the period covers, ending with the selected month.
        public var months: Int {
            switch self {
            case .oneMonth: 1
            case .threeMonths: 3
            case .sixMonths: 6
            case .oneYear: 12
            }
        }
    }

    public enum Granularity: Sendable {
        case week
        case month
    }

    public struct Bucket: Equatable, Sendable, Identifiable {
        public let interval: DateInterval
        public let income: Money
        public let expenses: Money

        public var id: Date { interval.start }
    }

    public let period: Period
    public let granularity: Granularity
    /// Oldest first.
    public let buckets: [Bucket]
    public let totalIncome: Money
    public let totalExpenses: Money

    /// Income minus expenses over the whole period: the Charts mockup's "Saved". Negative when the
    /// period spent more than it earned.
    public var net: Money {
        Money.unchecked(totalIncome.minorUnits - totalExpenses.minorUnits, totalIncome.currencyCode)
    }

    public init(transactions: some Sequence<Transaction>, period: Period, endingWith month: YearMonth,
                currencyCode: String, timeZone: TimeZone = .autoupdatingCurrent,
                locale: Locale = .autoupdatingCurrent) throws(MoneyError) {
        let code = try Currency.validatedCode(currencyCode)
        let intervals = period == .oneMonth
            ? Self.weeks(of: month, timeZone: timeZone, locale: locale)
            : (0..<period.months).reversed().map { month.adding(months: -$0).dateInterval(in: timeZone) }

        var income = Array(repeating: Tally(), count: intervals.count)
        var expenses = Array(repeating: Tally(), count: intervals.count)
        var totalIncome = Tally()
        var totalExpenses = Tally()
        let start = intervals.first?.start ?? .distantFuture
        let end = intervals.last?.end ?? .distantPast
        for transaction in transactions where transaction.currencyCode == code {
            // Read the date once: every model property read goes through SwiftData's backing data.
            let date = transaction.date
            guard date >= start, date < end,
                  let index = intervals.firstIndex(where: { date < $0.end }) else { continue }
            switch transaction.kind {
            case .income:
                try income[index].add(transaction.amountMinorUnits)
                try totalIncome.add(transaction.amountMinorUnits)
            case .expense:
                try expenses[index].add(transaction.amountMinorUnits)
                try totalExpenses.add(transaction.amountMinorUnits)
            }
        }

        self.period = period
        granularity = period == .oneMonth ? .week : .month
        buckets = intervals.indices.map { index in
            Bucket(interval: intervals[index], income: income[index].money(code), expenses: expenses[index].money(code))
        }
        self.totalIncome = totalIncome.money(code)
        self.totalExpenses = totalExpenses.money(code)
    }

    // MARK: - Private

    /// Calendar weeks that overlap `month`, each clipped to the month's bounds.
    static func weeks(of month: YearMonth, timeZone: TimeZone, locale: Locale) -> [DateInterval] {
        var calendar = YearMonth.calendar(timeZone)
        calendar.locale = locale
        calendar.firstWeekday = locale.calendar.firstWeekday
        let monthInterval = month.dateInterval(in: timeZone)

        var weeks: [DateInterval] = []
        var start = monthInterval.start
        while start < monthInterval.end {
            let weekEnd = calendar.dateInterval(of: .weekOfYear, for: start)?.end ?? monthInterval.end
            let end = min(weekEnd, monthInterval.end)
            weeks.append(DateInterval(start: start, end: end))
            start = end
        }
        return weeks
    }
}

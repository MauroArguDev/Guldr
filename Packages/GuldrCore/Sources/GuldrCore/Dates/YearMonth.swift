//
//  YearMonth.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 8/10/26.
//

import Foundation

/// A calendar month, the unit of budgets and monthly summaries (ADR 008).
///
/// Stored as an integer such as `202610`. Months are always Gregorian, so the stored value means the
/// same thing for every user; the time zone decides which month a moment belongs to.
public struct YearMonth: Hashable, Comparable, Sendable {

    public let year: Int
    public let month: Int

    /// `nil` unless `month` is 1–12 and `year` is 1–9999.
    public init?(year: Int, month: Int) {
        guard (1...12).contains(month), (1...9_999).contains(year) else { return nil }
        self.year = year
        self.month = month
    }

    /// From the stored form, e.g. `202610`.
    public init?(rawValue: Int) {
        self.init(year: rawValue / 100, month: rawValue % 100)
    }

    /// The month that contains `date` in `timeZone`.
    public init(containing date: Date, timeZone: TimeZone = .autoupdatingCurrent) {
        let components = Self.calendar(timeZone).dateComponents([.year, .month], from: date)
        // Gregorian components of a valid Date are always in range.
        self.year = components.year ?? 1
        self.month = components.month ?? 1
    }

    /// The stored form, e.g. `202610`.
    public var rawValue: Int { year * 100 + month }

    public var next: YearMonth { adding(months: 1) }
    public var previous: YearMonth { adding(months: -1) }

    public func adding(months: Int) -> YearMonth {
        let zeroBased = year * 12 + (month - 1) + months
        return YearMonth(unchecked: zeroBased / 12, zeroBased % 12 + 1)
    }

    /// From the first instant of the month to the first instant of the next, in `timeZone`.
    public func dateInterval(in timeZone: TimeZone = .autoupdatingCurrent) -> DateInterval {
        let calendar = Self.calendar(timeZone)
        let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .distantPast
        let end = calendar.date(from: DateComponents(year: next.year, month: next.month, day: 1)) ?? .distantFuture
        return DateInterval(start: start, end: end)
    }

    /// Whether `date` falls in this month in `timeZone` (start inclusive, end exclusive).
    public func contains(_ date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> Bool {
        let interval = dateInterval(in: timeZone)
        return date >= interval.start && date < interval.end
    }

    /// Number of days in the month.
    public func numberOfDays(in timeZone: TimeZone = .autoupdatingCurrent) -> Int {
        let calendar = Self.calendar(timeZone)
        let start = dateInterval(in: timeZone).start
        return calendar.range(of: .day, in: .month, for: start)?.count ?? 30
    }

    /// Display name such as "September 2026" or "Septiembre de 2026", capitalized for a header.
    public func title(locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        var style = Date.FormatStyle(locale: locale, calendar: Self.calendar(timeZone), timeZone: timeZone)
            .month(.wide)
            .year()
        style.capitalizationContext = .beginningOfSentence
        return dateInterval(in: timeZone).start.formatted(style)
    }

    public static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // MARK: - Private

    private init(unchecked year: Int, _ month: Int) {
        self.year = year
        self.month = month
    }

    static func calendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

extension YearMonth: Codable {
    /// Encoded as the integer form, the same value stored in `Budget.yearMonth`.
    public init(from decoder: any Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(Int.self)
        guard let value = YearMonth(rawValue: rawValue) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid year-month \(rawValue)"))
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension YearMonth: CustomStringConvertible {
    public var description: String { String(format: "%04d-%02d", year, month) }
}

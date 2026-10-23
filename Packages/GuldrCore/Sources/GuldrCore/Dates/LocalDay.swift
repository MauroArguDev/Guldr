//
//  LocalDay.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation

/// A calendar day, the unit of the logging streak (ADR 012).
///
/// Stored as an integer such as `20261023`. Like `YearMonth`, days are always Gregorian; the time zone
/// only decides which day a moment belongs to, once, when the day is recorded. Arithmetic works on the
/// date alone, so it never meets a DST gap.
public struct LocalDay: Hashable, Comparable, Sendable {

    public let year: Int
    public let month: Int
    public let day: Int

    /// `nil` unless the date exists, e.g. not February 30.
    public init?(year: Int, month: Int, day: Int) {
        // The calendar rolls an impossible date over (February 30 becomes March 2); reading it back catches that.
        guard (1...9_999).contains(year),
              let date = Self.utc.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        let resolved = Self.utc.dateComponents([.year, .month, .day], from: date)
        guard resolved.year == year, resolved.month == month, resolved.day == day else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// From the stored form, e.g. `20261023`.
    public init?(rawValue: Int) {
        self.init(year: rawValue / 10_000, month: rawValue / 100 % 100, day: rawValue % 100)
    }

    /// The day that contains `date` in `timeZone`.
    public init(containing date: Date, timeZone: TimeZone) {
        let components = YearMonth.calendar(timeZone).dateComponents([.year, .month, .day], from: date)
        // Gregorian components of a valid Date are always in range.
        self.init(unchecked: components.year ?? 1, components.month ?? 1, components.day ?? 1)
    }

    /// The stored form, e.g. `20261023`.
    public var rawValue: Int { year * 10_000 + month * 100 + day }

    public func adding(days: Int) -> LocalDay {
        let date = Self.utc.date(byAdding: .day, value: days, to: noonUTC) ?? noonUTC
        return LocalDay(containing: date, timeZone: Self.utc.timeZone)
    }

    /// 1 for Sunday through 7 for Saturday, as `Calendar` numbers weekdays.
    public var weekday: Int {
        Self.utc.component(.weekday, from: noonUTC)
    }

    /// Whole days from this day to `other`; negative when `other` is earlier.
    public func days(to other: LocalDay) -> Int {
        Self.utc.dateComponents([.day], from: noonUTC, to: other.noonUTC).day ?? 0
    }

    /// From the first instant of the day to the first instant of the next, in `timeZone`.
    public func dateInterval(in timeZone: TimeZone) -> DateInterval {
        let calendar = YearMonth.calendar(timeZone)
        let start = calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
        let next = adding(days: 1)
        let end = calendar.date(from: DateComponents(year: next.year, month: next.month, day: next.day)) ?? .distantFuture
        return DateInterval(start: start, end: end)
    }

    public static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // MARK: - Private

    private init(unchecked year: Int, _ month: Int, _ day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    private static let utc = YearMonth.calendar(TimeZone(identifier: "UTC") ?? .gmt)

    /// Noon keeps day arithmetic away from midnight in any representation.
    private var noonUTC: Date {
        Self.utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
    }
}

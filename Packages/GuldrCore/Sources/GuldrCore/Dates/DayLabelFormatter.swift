//
//  DayLabelFormatter.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 8/10/26.
//

import Foundation

/// Section titles for lists grouped by day: "Today", "Yesterday", "Friday, Sep 25", or with the year
/// when it differs from the current one. Words come from Foundation, already localized ("Hoy", "Ayer").
public struct DayLabelFormatter: Sendable {

    public let locale: Locale
    public let timeZone: TimeZone

    public init(locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent) {
        self.locale = locale
        self.timeZone = timeZone
    }

    /// The start of the day that contains `date`; the grouping key for day sections.
    public func startOfDay(for date: Date) -> Date {
        YearMonth.calendar(timeZone).startOfDay(for: date)
    }

    /// The add sheet's date chip: "Today, Sep 28", "Yesterday, Sep 27", otherwise "Thu, Sep 24", with
    /// the year when it is not the current one.
    public func chipLabel(for date: Date, relativeTo now: Date = .now) -> String {
        let calendar = YearMonth.calendar(timeZone)
        let days = calendar.dateComponents([.day], from: startOfDay(for: now), to: startOfDay(for: date)).day ?? 0
        var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone).month(.abbreviated).day()
        if calendar.component(.year, from: date) != calendar.component(.year, from: now) {
            style = style.year()
        }
        guard days == 0 || days == -1 else {
            style = style.weekday(.abbreviated)
            style.capitalizationContext = .beginningOfSentence
            return date.formatted(style)
        }
        return label(for: date, relativeTo: now) + ", " + date.formatted(style)
    }

    /// The Dashboard's recent rows: "Today", "Yesterday", otherwise "Sep 25", with the year when it is
    /// not the current one.
    public func shortLabel(for date: Date, relativeTo now: Date = .now) -> String {
        let calendar = YearMonth.calendar(timeZone)
        let days = calendar.dateComponents([.day], from: startOfDay(for: now), to: startOfDay(for: date)).day ?? 0
        guard days != 0, days != -1 else { return label(for: date, relativeTo: now) }
        var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone).month(.abbreviated).day()
        if calendar.component(.year, from: date) != calendar.component(.year, from: now) {
            style = style.year()
        }
        return date.formatted(style)
    }

    public func label(for date: Date, relativeTo now: Date = .now) -> String {
        let calendar = YearMonth.calendar(timeZone)
        let days = calendar.dateComponents([.day], from: startOfDay(for: now), to: startOfDay(for: date)).day ?? 0

        if days == 0 || days == -1 {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = locale
            formatter.dateTimeStyle = .named
            formatter.unitsStyle = .full
            formatter.formattingContext = .beginningOfSentence
            return formatter.localizedString(from: DateComponents(day: days))
        }

        var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone)
            .weekday(.wide)
            .month(.abbreviated)
            .day()
        if calendar.component(.year, from: date) != calendar.component(.year, from: now) {
            style = style.year()
        }
        style.capitalizationContext = .beginningOfSentence
        return date.formatted(style)
    }
}

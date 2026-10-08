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

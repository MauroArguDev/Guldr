//
//  ReminderSchedule.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation

/// The time of day the daily reminder arrives, on the 24-hour clock. Stored as minutes after midnight.
public struct ReminderTime: Hashable, Sendable {

    public let hour: Int
    public let minute: Int

    /// `nil` outside 00:00–23:59.
    public init?(hour: Int, minute: Int) {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    public init?(minutesAfterMidnight: Int) {
        self.init(hour: minutesAfterMidnight / 60, minute: minutesAfterMidnight % 60)
    }

    public var minutesAfterMidnight: Int { hour * 60 + minute }

    /// The author's default (2026-10-23): after the day's spending, with time left to log it.
    public static let `default` = ReminderTime(hour: 20, minute: 0)!
}

/// When the daily reminder arrives (v1 plan, Phase 28). iOS can't skip a day of a repeating trigger, so
/// the app keeps the next few days as one-off requests and asks again after every save: a day that is
/// already logged simply isn't among them.
public enum ReminderSchedule {

    /// How many reminders are pending at a time. A week covers anyone who doesn't open the app for a few
    /// days, and stays far below iOS's limit of 64 pending requests.
    public static let pendingDays = 7

    /// The next reminders, as wall-clock components (year, month, day, hour, minute). Components, not
    /// dates: iOS matches them against the clock wherever the iPhone is, so a reminder set in one time zone
    /// still arrives at 20:00 in another. Today is left out once it's logged or its time has passed.
    public static func upcoming(after now: Date, at time: ReminderTime, todayIsLogged: Bool,
                                timeZone: TimeZone, count: Int = pendingDays) -> [DateComponents] {
        let calendar = calendar(in: timeZone)
        let today = calendar.startOfDay(for: now)
        var reminders: [DateComponents] = []
        var offset = 0
        while reminders.count < count {
            defer { offset += 1 }
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { break }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = time.hour
            components.minute = time.minute
            if offset == 0 {
                // A time that doesn't exist on a DST day resolves forward, as iOS fires it.
                guard !todayIsLogged, let fire = calendar.date(from: components), fire > now else { continue }
            }
            reminders.append(components)
        }
        return reminders
    }

    /// Today, from midnight to midnight, for finding a transaction dated today.
    public static func today(containing now: Date, timeZone: TimeZone) -> DateInterval {
        let calendar = calendar(in: timeZone)
        return calendar.dateInterval(of: .day, for: now) ?? DateInterval(start: calendar.startOfDay(for: now),
                                                                          duration: 86_400)
    }

    /// One identifier per day ("reminder-2026-10-23"), so rescheduling replaces a day instead of adding
    /// a second request for it.
    public static func identifier(for components: DateComponents) -> String {
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return "\(identifierPrefix)\(year)-\(twoDigits(month))-\(twoDigits(day))"
    }

    /// Every reminder's identifier starts with this, so they can be told apart from budget alerts.
    public static let identifierPrefix = "reminder-"

    private static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}

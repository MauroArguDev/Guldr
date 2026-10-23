//
//  ReminderScheduleTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import Testing
@testable import GuldrCore

/// The next week of daily reminders, mostly in Mexico City (no DST) and New York (DST).
struct ReminderScheduleTests {

    private let mexico = TimeZone(identifier: "America/Mexico_City")!
    private let newYork = TimeZone(identifier: "America/New_York")!
    private let eight = ReminderTime.default

    @Test func todayIsIncludedBeforeItsTime() throws {
        let now = try date("2026-10-23T18:00:00-06:00")
        let reminders = ReminderSchedule.upcoming(after: now, at: eight, todayIsLogged: false, timeZone: mexico)
        #expect(reminders.count == 7)
        #expect(days(reminders) == ["2026-10-23", "2026-10-24", "2026-10-25", "2026-10-26", "2026-10-27",
                                    "2026-10-28", "2026-10-29"])
        #expect(reminders.allSatisfy { $0.hour == 20 && $0.minute == 0 })
    }

    @Test func aLoggedTodayStartsTomorrow() throws {
        let now = try date("2026-10-23T09:00:00-06:00")
        let reminders = ReminderSchedule.upcoming(after: now, at: eight, todayIsLogged: true, timeZone: mexico)
        #expect(days(reminders).first == "2026-10-24")
        #expect(reminders.count == 7)
    }

    @Test func todayIsLeftOutOnceItsTimeHasPassed() throws {
        let atTime = try date("2026-10-23T20:00:00-06:00")
        #expect(days(ReminderSchedule.upcoming(after: atTime, at: eight, todayIsLogged: false,
                                               timeZone: mexico)).first == "2026-10-24")
        let justBefore = try date("2026-10-23T19:59:00-06:00")
        #expect(days(ReminderSchedule.upcoming(after: justBefore, at: eight, todayIsLogged: false,
                                               timeZone: mexico)).first == "2026-10-23")
    }

    @Test func todayIsTheDeviceDay() throws {
        // 01:00 UTC on the 24th is still the evening of the 23rd in Mexico City.
        let now = try date("2026-10-24T01:00:00Z")
        let late = try #require(ReminderTime(hour: 21, minute: 30))
        let reminders = ReminderSchedule.upcoming(after: now, at: late, todayIsLogged: false, timeZone: mexico)
        #expect(days(reminders).first == "2026-10-23")
    }

    @Test func wallClockTimeSurvivesDaylightSaving() throws {
        // New York springs forward on March 8 and falls back on November 1, 2026.
        let march = ReminderSchedule.upcoming(after: try date("2026-03-06T12:00:00-05:00"), at: eight,
                                              todayIsLogged: false, timeZone: newYork)
        #expect(days(march).prefix(4) == ["2026-03-06", "2026-03-07", "2026-03-08", "2026-03-09"])
        #expect(march.allSatisfy { $0.hour == 20 && $0.minute == 0 })

        let november = ReminderSchedule.upcoming(after: try date("2026-10-31T12:00:00-04:00"), at: eight,
                                                 todayIsLogged: false, timeZone: newYork)
        #expect(days(november).prefix(3) == ["2026-10-31", "2026-11-01", "2026-11-02"])
    }

    @Test func aTimeMissingOnTheDSTDayStillCounts() throws {
        // 02:30 doesn't exist on March 8 in New York; before it, today's reminder is kept and iOS fires it
        // at the next valid time.
        let halfPastTwo = try #require(ReminderTime(hour: 2, minute: 30))
        let now = try date("2026-03-08T01:00:00-05:00")
        let reminders = ReminderSchedule.upcoming(after: now, at: halfPastTwo, todayIsLogged: false, timeZone: newYork)
        #expect(days(reminders).first == "2026-03-08")
        #expect(reminders.first?.hour == 2)
        #expect(reminders.first?.minute == 30)
    }

    @Test func crossesMonthsAndYears() throws {
        let now = try date("2026-12-28T21:00:00-06:00")
        let reminders = ReminderSchedule.upcoming(after: now, at: eight, todayIsLogged: false, timeZone: mexico)
        #expect(days(reminders) == ["2026-12-29", "2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02",
                                    "2027-01-03", "2027-01-04"])
    }

    @Test func identifiersNameTheDay() {
        let components = DateComponents(year: 2026, month: 3, day: 8, hour: 20, minute: 0)
        #expect(ReminderSchedule.identifier(for: components) == "reminder-2026-03-08")
        #expect(ReminderSchedule.identifier(for: components).hasPrefix(ReminderSchedule.identifierPrefix))
    }

    @Test func todayRunsMidnightToMidnightInTheDeviceZone() throws {
        let today = ReminderSchedule.today(containing: try date("2026-10-23T23:30:00-06:00"), timeZone: mexico)
        #expect(today.start == (try date("2026-10-23T00:00:00-06:00")))
        #expect(today.end == (try date("2026-10-24T00:00:00-06:00")))

        // A DST day is 23 hours long.
        let short = ReminderSchedule.today(containing: try date("2026-03-08T12:00:00-04:00"), timeZone: newYork)
        #expect(short.duration == 23 * 3_600)
    }

    @Test func timesAreValidated() {
        #expect(ReminderTime(hour: 24, minute: 0) == nil)
        #expect(ReminderTime(hour: 8, minute: 60) == nil)
        #expect(ReminderTime(hour: -1, minute: 0) == nil)
        #expect(ReminderTime(minutesAfterMidnight: 1_439) == ReminderTime(hour: 23, minute: 59))
        #expect(ReminderTime(minutesAfterMidnight: 1_440) == nil)
        #expect(ReminderTime.default.minutesAfterMidnight == 1_200)
    }

    // MARK: - Helpers

    private func date(_ text: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: text))
    }

    private func days(_ reminders: [DateComponents]) -> [String] {
        reminders.map { ReminderSchedule.identifier(for: $0).replacingOccurrences(of: "reminder-", with: "") }
    }
}

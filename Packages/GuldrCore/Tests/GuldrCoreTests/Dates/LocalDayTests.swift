//
//  LocalDayTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import Testing
@testable import GuldrCore

struct LocalDayTests {

    private let mexico = TimeZone(identifier: "America/Mexico_City")!
    private let madrid = TimeZone(identifier: "Europe/Madrid")!
    private let newYork = TimeZone(identifier: "America/New_York")!

    @Test func theTimeZoneDecidesTheDay() throws {
        let moment = try #require(ISO8601DateFormatter().date(from: "2026-10-24T03:30:00Z"))
        #expect(LocalDay(containing: moment, timeZone: mexico).rawValue == 20_261_023)
        #expect(LocalDay(containing: moment, timeZone: madrid).rawValue == 20_261_024)
    }

    @Test func storedFormRoundTrips() {
        #expect(LocalDay(rawValue: 20_261_023) == LocalDay(year: 2026, month: 10, day: 23))
        #expect(LocalDay(rawValue: 20_261_023)?.rawValue == 20_261_023)
        #expect(LocalDay(rawValue: 20_260_230) == nil)
        #expect(LocalDay(year: 2026, month: 13, day: 1) == nil)
        #expect(LocalDay(year: 2028, month: 2, day: 29) != nil)
        #expect(LocalDay(year: 2027, month: 2, day: 29) == nil)
    }

    @Test func arithmeticCrossesMonthsYearsAndDST() throws {
        let day = try #require(LocalDay(year: 2026, month: 12, day: 31))
        #expect(day.adding(days: 1) == LocalDay(year: 2027, month: 1, day: 1))
        #expect(day.adding(days: -365) == LocalDay(year: 2025, month: 12, day: 31))
        let dstDay = try #require(LocalDay(year: 2026, month: 3, day: 8))
        #expect(dstDay.adding(days: 1) == LocalDay(year: 2026, month: 3, day: 9))
        #expect(dstDay.days(to: try #require(LocalDay(year: 2026, month: 4, day: 7))) == 30)
        #expect(day.days(to: dstDay) < 0)
    }

    @Test func intervalsFollowTheZone() throws {
        let dstDay = try #require(LocalDay(year: 2026, month: 3, day: 8))
        #expect(dstDay.dateInterval(in: newYork).duration == 23 * 3_600)
        let interval = try #require(LocalDay(year: 2026, month: 10, day: 23)).dateInterval(in: mexico)
        #expect(interval.start == ISO8601DateFormatter().date(from: "2026-10-23T06:00:00Z"))
    }
}

//
//  DayLabelFormatterTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 8/10/26.
//

import Foundation
import Testing
@testable import GuldrCore

struct DayLabelFormatterTests {

    private let utc = TimeZone(identifier: "UTC")!

    private func date(_ iso: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: iso))
    }

    private func formatter(_ locale: String, timeZone: TimeZone? = nil) -> DayLabelFormatter {
        DayLabelFormatter(locale: Locale(identifier: locale), timeZone: timeZone ?? utc)
    }

    @Test func todayAndYesterdayInEnglishAndSpanish() throws {
        let now = try date("2026-09-28T09:41:00Z")
        #expect(formatter("en_US").label(for: try date("2026-09-28T00:05:00Z"), relativeTo: now) == "Today")
        #expect(formatter("en_US").label(for: try date("2026-09-27T23:59:00Z"), relativeTo: now) == "Yesterday")
        #expect(formatter("es_MX").label(for: try date("2026-09-28T08:00:00Z"), relativeTo: now) == "Hoy")
        #expect(formatter("es_MX").label(for: try date("2026-09-27T08:00:00Z"), relativeTo: now) == "Ayer")
    }

    @Test func olderDaysShowWeekdayAndDate() throws {
        let now = try date("2026-09-28T09:41:00Z")
        let friday = try date("2026-09-25T12:00:00Z")
        #expect(formatter("en_US").label(for: friday, relativeTo: now) == "Friday, Sep 25")
        let spanish = formatter("es_MX").label(for: friday, relativeTo: now)
        #expect(spanish.hasPrefix("Viernes"))
        #expect(spanish.contains("25"))
    }

    @Test func otherYearsIncludeTheYear() throws {
        let now = try date("2026-01-02T10:00:00Z")
        #expect(formatter("en_US").label(for: try date("2025-12-24T10:00:00Z"), relativeTo: now) == "Wednesday, Dec 24, 2025")
    }

    @Test func futureDatesAreNotTodayOrYesterday() throws {
        let now = try date("2026-09-28T09:41:00Z")
        #expect(formatter("en_US").label(for: try date("2026-09-29T09:00:00Z"), relativeTo: now) == "Tuesday, Sep 29")
    }

    @Test func dayBoundariesFollowTheTimeZone() throws {
        // 02:00 UTC on Sept 28 is 20:00 on Sept 27 in Mexico City.
        let mexico = formatter("en_US", timeZone: TimeZone(identifier: "America/Mexico_City")!)
        let now = try date("2026-09-28T18:00:00Z")
        #expect(mexico.label(for: try date("2026-09-28T02:00:00Z"), relativeTo: now) == "Yesterday")
        #expect(mexico.startOfDay(for: try date("2026-09-28T02:00:00Z")) == (try date("2026-09-27T06:00:00Z")))
    }
}

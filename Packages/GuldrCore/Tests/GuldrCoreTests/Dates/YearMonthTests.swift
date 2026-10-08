//
//  YearMonthTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 8/10/26.
//

import Foundation
import Testing
@testable import GuldrCore

struct YearMonthTests {

    private let utc = TimeZone(identifier: "UTC")!
    private let mexicoCity = TimeZone(identifier: "America/Mexico_City")!
    private let newYork = TimeZone(identifier: "America/New_York")!

    private func date(_ iso: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: iso))
    }

    @Test func rawValueRoundTrip() throws {
        let month = try #require(YearMonth(year: 2026, month: 10))
        #expect(month.rawValue == 202_610)
        #expect(YearMonth(rawValue: 202_610) == month)
        #expect(month.description == "2026-10")
    }

    @Test(arguments: [202_600, 202_613, 0, -202_610])
    func invalidRawValuesAreRejected(rawValue: Int) {
        #expect(YearMonth(rawValue: rawValue) == nil)
    }

    @Test func theTimeZoneDecidesTheMonth() throws {
        // 03:00 UTC on Oct 1 is still Sept 30 in Mexico City (UTC−6).
        let moment = try date("2026-10-01T03:00:00Z")
        #expect(YearMonth(containing: moment, timeZone: utc).rawValue == 202_610)
        #expect(YearMonth(containing: moment, timeZone: mexicoCity).rawValue == 202_609)
    }

    @Test func intervalIsStartInclusiveEndExclusive() throws {
        let october = try #require(YearMonth(year: 2026, month: 10))
        let interval = october.dateInterval(in: utc)
        #expect(interval.start == (try date("2026-10-01T00:00:00Z")))
        #expect(interval.end == (try date("2026-11-01T00:00:00Z")))
        #expect(october.contains(interval.start, timeZone: utc))
        #expect(!october.contains(interval.end, timeZone: utc))
        #expect(october.contains(try date("2026-10-31T23:59:59Z"), timeZone: utc))
    }

    @Test func daylightSavingChangesAreRespected() throws {
        // New York springs forward in March 2026: the month is one hour shorter than 31 days.
        let march = try #require(YearMonth(year: 2026, month: 3))
        #expect(march.dateInterval(in: newYork).duration == TimeInterval(31 * 24 * 3_600 - 3_600))
        // And falls back on Nov 1: November is one hour longer than 30 days.
        let november = try #require(YearMonth(year: 2026, month: 11))
        #expect(november.dateInterval(in: newYork).duration == TimeInterval(30 * 24 * 3_600 + 3_600))
    }

    @Test func navigationRollsOverYears() throws {
        let december = try #require(YearMonth(year: 2026, month: 12))
        #expect(december.next.rawValue == 202_701)
        #expect(december.next.previous == december)
        #expect(december.adding(months: -12).rawValue == 202_512)
        #expect(december.adding(months: 25).rawValue == 202_901)
        #expect(december.adding(months: -23).rawValue == 202_501)
    }

    @Test(arguments: [(2026, 2, 28), (2028, 2, 29), (2026, 9, 30), (2026, 12, 31)])
    func numberOfDays(year: Int, month: Int, days: Int) throws {
        #expect(try #require(YearMonth(year: year, month: month)).numberOfDays(in: utc) == days)
    }

    @Test func comparesChronologically() throws {
        let months = [202_612, 202_601, 202_511].compactMap(YearMonth.init(rawValue:))
        #expect(months.sorted().map(\.rawValue) == [202_511, 202_601, 202_612])
    }

    @Test func titlesAreLocalizedAndCapitalized() throws {
        let september = try #require(YearMonth(year: 2026, month: 9))
        #expect(september.title(locale: Locale(identifier: "en_US"), timeZone: utc) == "September 2026")
        #expect(september.title(locale: Locale(identifier: "es_MX"), timeZone: utc) == "Septiembre de 2026")
    }

    @Test func codableUsesTheIntegerForm() throws {
        let month = try #require(YearMonth(year: 2026, month: 10))
        let data = try JSONEncoder().encode(month)
        #expect(String(bytes: data, encoding: .utf8) == "202610")
        #expect(try JSONDecoder().decode(YearMonth.self, from: data) == month)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(YearMonth.self, from: Data("202613".utf8)) }
    }
}

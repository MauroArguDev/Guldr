//
//  StreakCalendarTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import Testing
@testable import GuldrCore

struct StreakCalendarTests {

    /// A Friday.
    private let today = LocalDay(year: 2026, month: 10, day: 23)!

    @Test func weeksEndWithTheOneContainingToday() {
        let weeks = StreakCalendar.weeks(endingWith: today, firstWeekday: 1)
        #expect(weeks.count == 5)
        #expect(weeks.allSatisfy { $0.count == 7 })
        #expect(weeks.last?.contains(today) == true)
        #expect(weeks.flatMap(\.self) == (0..<35).map { weeks[0][0].adding(days: $0) })
    }

    @Test func theFirstWeekdayFollowsTheLocale() {
        // Sunday first (US) and Monday first (Mexico, Spain).
        #expect(StreakCalendar.weeks(endingWith: today, firstWeekday: 1).last?.first == LocalDay(year: 2026, month: 10, day: 18))
        #expect(StreakCalendar.weeks(endingWith: today, firstWeekday: 2).last?.first == LocalDay(year: 2026, month: 10, day: 19))
        #expect(today.weekday == 6)
    }

    @Test func aTodayOnTheFirstWeekdayStartsTheLastRow() throws {
        let sunday = try #require(LocalDay(year: 2026, month: 10, day: 18))
        #expect(StreakCalendar.weeks(endingWith: sunday, firstWeekday: 1).last?.first == sunday)
    }
}

//
//  LoggingStreakTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import Testing
@testable import GuldrCore

/// The streak as of Friday, October 23, 2026. Days are written as offsets from today: 0 is today,
/// -1 yesterday.
struct LoggingStreakTests {

    private let today = LocalDay(year: 2026, month: 10, day: 23)!

    @Test func noHistoryHasNoStreak() {
        let streak = streak([])
        #expect(streak.current == 0)
        #expect(streak.best == 0)
        #expect(streak.runStart == nil)
        #expect(streak.state(of: today) == .open)
        #expect(streak.state(of: day(-1)) == .repairable)
        #expect(!streak.isYesterdayAtRisk)
        #expect(streak.nextMilestone == 3)
    }

    @Test func todayCountsOnceLogged() {
        let streak = streak([0])
        #expect(streak.current == 1)
        #expect(streak.isTodayLogged)
        #expect(streak.runStart == today)
    }

    @Test func anOpenTodayDoesNotBreakTheRun() {
        let streak = streak([-5, -4, -3, -2, -1])
        #expect(streak.current == 5)
        #expect(!streak.isTodayLogged)
        #expect(streak.state(of: today) == .open)
    }

    @Test func yesterdayCanStillBeRepaired() {
        let open = streak([-4, -3, -2])
        #expect(open.current == 3)
        #expect(open.isYesterdayAtRisk)
        #expect(open.state(of: day(-1)) == .repairable)

        let repaired = streak([-4, -3, -2, -1])
        #expect(repaired.current == 4)
        #expect(!repaired.isYesterdayAtRisk)
    }

    @Test func aFinalMissedDayEndsTheRunButKeepsTheBest() {
        let streak = streak([-6, -5, -4, -3, 0])
        #expect(streak.state(of: day(-2)) == .missed)
        #expect(streak.state(of: day(-1)) == .repairable)
        #expect(streak.current == 1)
        #expect(streak.best == 4)
        #expect(streak.runStart == today)
    }

    @Test func noSpendingCountsLikeATransaction() {
        let streak = LoggingStreak(loggedDays: [day(-2): .transaction, day(-1): .noSpending, today: .transaction],
                                   today: today)
        #expect(streak.current == 3)
        #expect(streak.state(of: day(-1)) == .noSpending)
        #expect(streak.state(of: day(-2)) == .logged)
    }

    @Test func freezesAreEarnedEverySevenDaysUpToTwo() {
        #expect(streak(Array(-5...0)).freezesHeld == 0)
        #expect(streak(Array(-6...0)).freezesHeld == 1)
        #expect(streak(Array(-13...0)).freezesHeld == 2)
        #expect(streak(Array(-20...0)).freezesHeld == 2)
    }

    @Test func aFreezeCoversAMissedDayWithoutCounting() {
        // Seven days earn a freeze, day -3 is missed, then two more days.
        let streak = streak(Array(-10 ... -4) + [-2, -1, 0])
        #expect(streak.state(of: day(-3)) == .frozen)
        #expect(streak.freezesHeld == 0)
        #expect(streak.current == 10)
        #expect(streak.runStart == day(-10))
    }

    @Test func twoMissesWithOneFreezeEndTheRun() {
        let streak = streak(Array(-12 ... -6) + [0])
        #expect(streak.state(of: day(-5)) == .frozen)
        #expect(streak.state(of: day(-4)) == .missed)
        #expect(streak.current == 1)
        #expect(streak.best == 7)
    }

    @Test func aFrozenDayRestartsTheCountTowardTheNextFreeze() {
        // 7 days (1 freeze), a frozen day, then 6 days: not yet a new freeze.
        let sixAfter = streak(Array(-14 ... -8) + Array(-6 ... -1))
        #expect(sixAfter.state(of: day(-7)) == .frozen)
        #expect(sixAfter.freezesHeld == 0)
        #expect(streak(Array(-14 ... -8) + Array(-6 ... 0)).freezesHeld == 1)
    }

    @Test func milestonesFollowTheCurrentCount() {
        #expect(streak([-2, -1, 0]).reachedMilestone == 3)
        #expect(streak([-2, -1, 0]).nextMilestone == 7)
        #expect(streak([-3, -2, -1, 0]).reachedMilestone == nil)
        #expect(streak(Array(-364...0)).reachedMilestone == 365)
        #expect(streak(Array(-365...0)).nextMilestone == nil)
    }

    @Test func daysOutsideTheHistoryAreOutside() {
        let streak = streak([-2, -1, 0])
        #expect(streak.state(of: day(-3)) == .outside)
        #expect(streak.state(of: day(1)) == .outside)
    }

    @Test func fiveYearsOfDaysAreFast() {
        var days = Array(-1_825...0)
        days.removeAll { $0.isMultiple(of: 11) }
        let clock = ContinuousClock()
        var result: LoggingStreak?
        let elapsed = clock.measure { result = streak(days) }
        print("[performance] LoggingStreak (5 years): \(elapsed)")
        #expect(elapsed < .milliseconds(100))
        #expect((result?.best ?? 0) > 0)
    }

    // MARK: - Helpers

    private func day(_ offset: Int) -> LocalDay {
        today.adding(days: offset)
    }

    private func streak(_ offsets: [Int]) -> LoggingStreak {
        LoggingStreak(loggedDays: Dictionary(uniqueKeysWithValues: offsets.map { (day($0), .transaction) }),
                      today: today)
    }
}

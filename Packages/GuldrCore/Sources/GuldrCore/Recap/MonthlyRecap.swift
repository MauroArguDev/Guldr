//
//  MonthlyRecap.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation

/// A month in review for the recap card (v1 plan, Phase 31). It holds counts, percentages and
/// identifiers only, never `Money`, so a shared card can't show an amount by construction (author's call,
/// 2026-10-23).
public struct MonthlyRecap: Equatable, Sendable {

    /// The category that took the largest share of the month's spending.
    public struct TopCategory: Equatable, Sendable {
        public let categoryID: UUID
        /// Whole percent of the month's expenses.
        public let share: Int
    }

    public let month: YearMonth
    public let daysInMonth: Int
    /// Days logged with a transaction or "No spending" (ADR 012).
    public let daysLogged: Int
    /// Over, with 90 % of its days logged or frozen (ADR 013).
    public let isComplete: Bool
    /// Budgets in the active currency that ended within their limit, and all of them.
    public let budgetsKept: Int
    public let budgetsSet: Int
    /// Whole percent of the month's income saved; `nil` without income.
    public let savingsRate: Int?
    /// The longest run of logged days inside the month; a frozen day keeps a run going.
    public let bestStreak: Int
    public let topCategory: TopCategory?
    /// Tiers earned during the month, in the catalog's order.
    public let achievementsEarned: [EarnedTier]

    /// Nothing happened: no logged day and no transaction. Such a month isn't offered.
    public var isEmpty: Bool { daysLogged == 0 && savingsRate == nil && topCategory == nil && budgetsSet == 0 }

    public init(month: YearMonth, transactions: [Transaction], budgets: [Budget],
                loggedDays: [LocalDay: LoggedDaySource], earned: [EarnedTier], currencyCode: String,
                now: Date, timeZone: TimeZone) {
        self.month = month
        daysInMonth = month.numberOfDays(in: timeZone)
        let streak = LoggingStreak(loggedDays: loggedDays, today: LocalDay(containing: now, timeZone: timeZone))
        let days = (1...daysInMonth).compactMap { LocalDay(year: month.year, month: month.month, day: $0) }
        daysLogged = days.count { loggedDays[$0] != nil }
        isComplete = month < YearMonth(containing: now, timeZone: timeZone)
            && AchievementEvaluator.isComplete(month, streak: streak, timeZone: timeZone)
        bestStreak = Self.longestRun(in: days, streak: streak)

        let interval = month.dateInterval(in: timeZone)
        let inMonth = transactions.filter { $0.currencyCode == currencyCode && interval.contains($0.date)
            && $0.date != interval.end }
        if let status = try? BudgetStatus(budgets: budgets, transactions: inMonth, month: month,
                                          currencyCode: currencyCode, now: now, timeZone: timeZone) {
            budgetsSet = status.lines.count
            budgetsKept = status.lines.count - status.overBudgetCount
        } else {
            budgetsSet = 0
            budgetsKept = 0
        }
        if let summary = try? MonthSummary(transactions: inMonth, month: month, currencyCode: currencyCode,
                                           timeZone: timeZone), summary.income.minorUnits > 0 {
            savingsRate = Int((summary.savingsRate * 100).rounded(.down))
        } else {
            savingsRate = nil
        }
        let breakdown = try? CategoryBreakdown(transactions: inMonth, month: month, currencyCode: currencyCode,
                                               timeZone: timeZone)
        topCategory = breakdown?.slices.lazy.compactMap { slice -> TopCategory? in
            guard case .category(let id) = slice.kind else { return nil }
            return TopCategory(categoryID: id, share: slice.percentage)
        }.first
        achievementsEarned = earned
            .filter { interval.contains($0.earnedAt) && $0.earnedAt != interval.end }
            .sorted { lhs, rhs in
                let order = AchievementID.allCases
                return (order.firstIndex(of: lhs.id) ?? 0, lhs.tier.rawValue) < (order.firstIndex(of: rhs.id) ?? 0,
                                                                                 rhs.tier.rawValue)
            }
    }

    /// Logged days add to a run; a frozen day, yesterday still open or today keep it; anything else ends it.
    private static func longestRun(in days: [LocalDay], streak: LoggingStreak) -> Int {
        var longest = 0
        var run = 0
        for day in days {
            switch streak.state(of: day) {
            case .logged, .noSpending:
                run += 1
                longest = max(longest, run)
            case .frozen, .repairable, .open:
                continue
            case .missed, .outside:
                run = 0
            }
        }
        return longest
    }
}

//
//  AchievementEvaluator.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation

/// Turns the store into one value per achievement (ADR 013). Pure: the same data gives the same values,
/// in the app, in tests and later in the share cards.
///
/// Money achievements only count **complete months**: over, with at least 90 % of their days logged or
/// covered by a freeze. Logging less can never earn a medal.
public enum AchievementEvaluator {

    /// The share of a month's days that must be logged (author's call, 2026-10-23).
    public static let completeMonthShare = 0.9

    /// What the evaluator reads: the store's contents and the active currency.
    public struct Input {
        public let transactions: [Transaction]
        public let budgets: [Budget]
        public let loggedDays: [LocalDay: LoggedDaySource]
        public let currencyCode: String

        public init(transactions: [Transaction], budgets: [Budget], loggedDays: [LocalDay: LoggedDaySource],
                    currencyCode: String) {
            self.transactions = transactions
            self.budgets = budgets
            self.loggedDays = loggedDays
            self.currencyCode = currencyCode
        }
    }

    public static func values(for input: Input, now: Date, timeZone: TimeZone) -> [AchievementID: Int] {
        let (transactions, budgets, loggedDays, currencyCode) = (input.transactions, input.budgets, input.loggedDays,
                                                                 input.currencyCode)
        let today = LocalDay(containing: now, timeZone: timeZone)
        let streak = LoggingStreak(loggedDays: loggedDays, today: today)
        let months = completeMonths(streak: streak, loggedDays: loggedDays, timeZone: timeZone)

        // Each complete month's transactions in the active currency, grouped once.
        let completeSet = Set(months)
        var byMonth: [YearMonth: [Transaction]] = [:]
        for transaction in transactions where transaction.currencyCode == currencyCode {
            let month = YearMonth(containing: transaction.date, timeZone: timeZone)
            if completeSet.contains(month) { byMonth[month, default: []].append(transaction) }
        }

        var withinBudget: [YearMonth] = []
        var saving: [YearMonth] = []
        var bestRate = 0
        for month in months {
            let monthTransactions = byMonth[month] ?? []
            if let status = try? BudgetStatus(budgets: budgets, transactions: monthTransactions, month: month,
                                              currencyCode: currencyCode, now: now, timeZone: timeZone),
               !status.lines.isEmpty, status.overBudgetCount == 0 {
                withinBudget.append(month)
            }
            if let summary = try? MonthSummary(transactions: monthTransactions, month: month,
                                               currencyCode: currencyCode, timeZone: timeZone),
               summary.income.minorUnits > 0 {
                if summary.net.minorUnits > 0 { saving.append(month) }
                bestRate = max(bestRate, Int((summary.savingsRate * 100).rounded(.down)))
            }
        }

        return [
            .unbroken: streak.best,
            .daysLogged: loggedDays.count,
            .completeMonth: months.count,
            .bookkeeper: transactions.count,
            .withinBudget: withinBudget.count,
            .steadyHand: longestRun(of: withinBudget),
            .saver: bestRate,
            .inTheBlack: longestRun(of: saving)
        ]
    }

    /// Every complete month, oldest first, from the first logged day's month to last month.
    public static func completeMonths(streak: LoggingStreak, loggedDays: [LocalDay: LoggedDaySource],
                                      timeZone: TimeZone) -> [YearMonth] {
        guard let first = loggedDays.keys.min() else { return [] }
        let current = YearMonth(year: streak.today.year, month: streak.today.month)
        var month = YearMonth(year: first.year, month: first.month)
        var complete: [YearMonth] = []
        while let candidate = month, let current, candidate < current {
            if isComplete(candidate, streak: streak, timeZone: timeZone) { complete.append(candidate) }
            month = candidate.next
        }
        return complete
    }

    /// At least 90 % of the month's days, rounded up, logged or covered by a freeze (ADR 013).
    public static func isComplete(_ month: YearMonth, streak: LoggingStreak, timeZone: TimeZone) -> Bool {
        let days = month.numberOfDays(in: timeZone)
        let needed = Int((Double(days) * completeMonthShare).rounded(.up))
        var covered = 0
        for day in 1...days {
            guard let localDay = LocalDay(year: month.year, month: month.month, day: day) else { continue }
            switch streak.state(of: localDay) {
            case .logged, .noSpending, .frozen: covered += 1
            default: break
            }
        }
        return covered >= needed
    }

    /// Combines the values with the stored tiers: what to show for each achievement, in catalog order.
    public static func progress(values: [AchievementID: Int], earned: [EarnedTier]) -> [AchievementProgress] {
        let stored = highestTiers(earned)
        return AchievementCatalog.all.map { achievement in
            let value = values[achievement.id] ?? 0
            let reached = achievement.tier(for: value)
            let kept = stored[achievement.id]
            let tier = [reached, kept?.tier].compactMap(\.self).max()
            return AchievementProgress(achievement: achievement, value: value, tier: tier,
                                       earnedAt: kept.flatMap { $0.tier == tier ? $0.earnedAt : nil })
        }
    }

    /// The tiers the values reach above what is stored: one per achievement, its highest new tier.
    public static func newlyEarned(values: [AchievementID: Int], earned: [EarnedTier], at date: Date) -> [EarnedTier] {
        let stored = highestTiers(earned)
        return AchievementCatalog.all.compactMap { achievement in
            guard let reached = achievement.tier(for: values[achievement.id] ?? 0) else { return nil }
            if let kept = stored[achievement.id], kept.tier >= reached { return nil }
            return EarnedTier(id: achievement.id, tier: reached, earnedAt: date)
        }
    }

    // MARK: - Private

    /// Duplicates (two devices in v1.1) collapse to the highest tier.
    private static func highestTiers(_ earned: [EarnedTier]) -> [AchievementID: EarnedTier] {
        var highest: [AchievementID: EarnedTier] = [:]
        for tier in earned where highest[tier.id].map({ tier.tier > $0.tier }) ?? true {
            highest[tier.id] = tier
        }
        return highest
    }

    /// The longest run of consecutive calendar months in `months` (ascending).
    private static func longestRun(of months: [YearMonth]) -> Int {
        var longest = 0
        var run = 0
        var previous: YearMonth?
        for month in months {
            run = previous?.next == month ? run + 1 : 1
            longest = max(longest, run)
            previous = month
        }
        return longest
    }
}

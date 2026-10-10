//
//  BudgetStatus.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation

/// How each category's budget is doing in one month, plus the overall ring (ADR 008).
///
/// Only budgets for `month`, in the active currency (ADR 005) and for categories that are not
/// archived count. Overall totals cover budgeted categories only: spending in a category without a
/// budget does not use up the ring.
public struct BudgetStatus: Equatable, Sendable {

    public struct Line: Equatable, Sendable, Identifiable {
        public let budgetID: UUID
        public let categoryID: UUID
        public let spent: Money
        public let limit: Money

        public var id: UUID { budgetID }

        public init(budgetID: UUID, categoryID: UUID, spent: Money, limit: Money) {
            self.budgetID = budgetID
            self.categoryID = categoryID
            self.spent = spent
            self.limit = limit
        }

        /// `spent / limit`; above 1 when over budget. A zero limit counts as fully used once anything
        /// is spent.
        public var usage: Double { BudgetStatus.usage(spent: spent.minorUnits, limit: limit.minorUnits) }
        public var isOver: Bool { spent.minorUnits > limit.minorUnits }
        /// What is left before the limit; zero once over.
        public var remaining: Money { Money.unchecked(max(0, limit.minorUnits - spent.minorUnits), limit.currencyCode) }
        /// How far past the limit; zero while within it.
        public var overAmount: Money { Money.unchecked(max(0, spent.minorUnits - limit.minorUnits), limit.currencyCode) }
    }

    public let month: YearMonth
    /// Sorted by usage, highest first, so the categories that need attention lead.
    public let lines: [Line]
    public let totalSpent: Money
    public let totalLimit: Money
    /// Days after today until the month ends: the mockup shows "2 days left" on Sept 28. The whole
    /// month for a future month, 0 for a past one.
    public let daysLeft: Int

    public var overallUsage: Double { Self.usage(spent: totalSpent.minorUnits, limit: totalLimit.minorUnits) }
    /// The ring's "available"; zero once the total is over.
    public var totalRemaining: Money {
        Money.unchecked(max(0, totalLimit.minorUnits - totalSpent.minorUnits), totalLimit.currencyCode)
    }
    public var overBudgetCount: Int { lines.count { $0.isOver } }

    public init(budgets: some Sequence<Budget>, transactions: some Sequence<Transaction>, month: YearMonth,
                currencyCode: String, now: Date = .now, timeZone: TimeZone = .autoupdatingCurrent) throws(MoneyError) {
        let code = try Currency.validatedCode(currencyCode)

        // One budget per category. Duplicates can exist without unique constraints; keep the one with
        // the smallest ID so the result never depends on fetch order.
        var budgetByCategory: [UUID: Budget] = [:]
        for budget in budgets where budget.yearMonth == month.rawValue && budget.currencyCode == code {
            guard let category = budget.category, !category.isArchived else { continue }
            if let existing = budgetByCategory[category.id], existing.id.uuidString < budget.id.uuidString { continue }
            budgetByCategory[category.id] = budget
        }

        let interval = month.dateInterval(in: timeZone)
        var spentByCategory: [UUID: Tally] = [:]
        for transaction in transactions where transaction.kind == .expense && transaction.currencyCode == code {
            guard let categoryID = transaction.category?.id, budgetByCategory[categoryID] != nil,
                  transaction.date >= interval.start, transaction.date < interval.end else { continue }
            try spentByCategory[categoryID, default: Tally()].add(transaction.amountMinorUnits)
        }

        var totalSpent = Tally()
        var totalLimit = Tally()
        var lines: [Line] = []
        for (categoryID, budget) in budgetByCategory {
            let spent = spentByCategory[categoryID]?.minorUnits ?? 0
            try totalSpent.add(spent)
            try totalLimit.add(budget.limitMinorUnits)
            lines.append(Line(budgetID: budget.id, categoryID: categoryID,
                              spent: Money.unchecked(spent, code), limit: budget.limit))
        }

        self.month = month
        self.lines = lines.sorted { lhs, rhs in
            if lhs.usage != rhs.usage { return lhs.usage > rhs.usage }
            if lhs.spent != rhs.spent { return lhs.spent.minorUnits > rhs.spent.minorUnits }
            return lhs.budgetID.uuidString < rhs.budgetID.uuidString
        }
        self.totalSpent = totalSpent.money(code)
        self.totalLimit = totalLimit.money(code)
        self.daysLeft = Self.daysLeft(in: month, now: now, timeZone: timeZone)
    }

    // MARK: - Private

    static func usage(spent: Int64, limit: Int64) -> Double {
        guard limit > 0 else { return spent > 0 ? 1 : 0 }
        return Double(spent) / Double(limit)
    }

    private static func daysLeft(in month: YearMonth, now: Date, timeZone: TimeZone) -> Int {
        let interval = month.dateInterval(in: timeZone)
        if now < interval.start { return month.numberOfDays(in: timeZone) }
        guard now < interval.end else { return 0 }
        let calendar = YearMonth.calendar(timeZone)
        let today = calendar.startOfDay(for: now)
        return max(0, (calendar.dateComponents([.day], from: today, to: interval.end).day ?? 1) - 1)
    }
}

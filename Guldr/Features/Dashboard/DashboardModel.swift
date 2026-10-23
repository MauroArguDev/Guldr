//
//  DashboardModel.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 16/10/26.
//

import Foundation
import GuldrCore
import Observation
import SwiftData

/// The Dashboard's numbers, turned into display values. Like the Transactions list, the view owns the
/// `@Query` and calls `update` when the data, the currency or a save changes; the model never holds a
/// context, so the view can create it before its environment exists.
@Observable
final class DashboardModel {

    /// What `BalanceCard` shows.
    struct Balance: Equatable {
        /// Every income minus every expense ever recorded, in the active currency (ADR 005).
        let total: Money
        let income: Money
        let expenses: Money
        /// 0…1, or `nil` when the month has no income.
        let savingsRate: Double?
    }

    /// What the budget summary row shows: the month's budgets added up.
    struct BudgetSummary: Equatable {
        /// "October budget".
        let title: String
        /// "$1,443.00 of $2,030.00 · 1 category over budget", or "· 15 days left" when none is over.
        let detail: String
        /// Total spent over total limit; above 1 when the month is over.
        let usage: Double
    }

    /// One of the latest transactions, as `TransactionRow` draws it.
    struct RecentRow: Identifiable, Equatable {
        let id: PersistentIdentifier
        /// The description, or the category's name when it is empty.
        let title: String
        /// "Food · Today", "Salary · Sep 25".
        let meta: String
        let symbol: String
        let amount: Money
        let kind: TransactionKind
    }

    /// How many transactions the Recent section shows.
    static let recentLimit = 5

    /// The month the Dashboard covers: the current one.
    private(set) var month: YearMonth
    /// `nil` until the first `update`, or if the active currency is not a valid code.
    private(set) var balance: Balance?
    /// `nil` when the month has no budgets in the active currency: the row is hidden.
    private(set) var budget: BudgetSummary?
    /// The latest transactions, newest first, in every currency (like the Transactions list).
    private(set) var recent: [RecentRow] = []
    /// Whether there is any transaction at all, so the screen can invite the first one.
    private(set) var hasTransactions = false

    init(locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent,
         now: @escaping () -> Date = { .now }) {
        self.locale = locale
        self.timeZone = timeZone
        self.now = now
        month = YearMonth(containing: now(), timeZone: timeZone)
    }

    /// Recomputes everything from the latest transactions and budgets in the active currency. `recent` is
    /// the newest transactions, already limited and sorted by the view's query.
    func update(transactions: [Transaction], budgets: [Budget], recent: [Transaction], currencyCode: String) {
        month = YearMonth(containing: now(), timeZone: timeZone)
        hasTransactions = !transactions.isEmpty
        self.recent = recent.prefix(Self.recentLimit).map(recentRow(for:))
        guard let summary = try? MonthSummary(transactions: transactions, month: month, currencyCode: currencyCode,
                                              timeZone: timeZone) else {
            balance = nil
            budget = nil
            return
        }
        balance = Balance(total: summary.balance, income: summary.income, expenses: summary.expenses,
                          savingsRate: summary.income.isZero ? nil : summary.savingsRate)
        budget = budgetSummary(budgets: budgets, transactions: transactions, currencyCode: currencyCode)
    }

    // MARK: - Private

    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let timeZone: TimeZone
    @ObservationIgnored private let now: () -> Date

    private func recentRow(for transaction: Transaction) -> RecentRow {
        let categoryName = transaction.category?.displayName ?? String(localized: "Uncategorized", locale: locale)
        return RecentRow(id: transaction.persistentModelID,
                         title: transaction.title.isEmpty ? categoryName : transaction.title,
                         meta: categoryName + " · " + DayLabelFormatter(locale: locale, timeZone: timeZone)
                            .shortLabel(for: transaction.date, relativeTo: now()),
                         symbol: transaction.category?.symbolName ?? "questionmark",
                         amount: transaction.amount,
                         kind: transaction.kind)
    }

    private func budgetSummary(budgets: [Budget], transactions: [Transaction], currencyCode: String) -> BudgetSummary? {
        guard let status = try? BudgetStatus(budgets: budgets, transactions: transactions, month: month,
                                             currencyCode: currencyCode, now: now(), timeZone: timeZone),
              !status.lines.isEmpty else { return nil }
        let formatter = MoneyFormatter(locale: locale)
        let amounts = String(localized: "\(formatter.string(from: status.totalSpent)) of \(formatter.string(from: status.totalLimit))",
                             locale: locale)
        let state = status.overBudgetCount > 0
            ? String(localized: "\(status.overBudgetCount) categories over budget", locale: locale)
            : String(localized: "\(status.daysLeft) days left", locale: locale)
        var monthStyle = Date.FormatStyle(locale: locale, timeZone: timeZone).month(.wide)
        // Mid-sentence: Spanish puts the month after "Presupuesto de", lowercase; English months stay capitalized.
        monthStyle.capitalizationContext = .middleOfSentence
        let monthName = month.dateInterval(in: timeZone).start.formatted(monthStyle)
        return BudgetSummary(title: String(localized: "\(monthName) budget", locale: locale),
                             detail: amounts + " · " + state, usage: status.overallUsage)
    }
}

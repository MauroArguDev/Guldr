//
//  DashboardModel.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 16/10/26.
//

import Foundation
import GuldrCore
import Observation

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

    /// The month the Dashboard covers: the current one.
    private(set) var month: YearMonth
    /// `nil` until the first `update`, or if the active currency is not a valid code.
    private(set) var balance: Balance?
    /// Whether there is any transaction at all, so the screen can invite the first one.
    private(set) var hasTransactions = false

    init(timeZone: TimeZone = .autoupdatingCurrent, now: @escaping () -> Date = { .now }) {
        self.timeZone = timeZone
        self.now = now
        month = YearMonth(containing: now(), timeZone: timeZone)
    }

    /// Recomputes everything from the latest transactions in the active currency.
    func update(transactions: [Transaction], currencyCode: String) {
        month = YearMonth(containing: now(), timeZone: timeZone)
        hasTransactions = !transactions.isEmpty
        guard let summary = try? MonthSummary(transactions: transactions, month: month, currencyCode: currencyCode,
                                              timeZone: timeZone) else {
            balance = nil
            return
        }
        balance = Balance(total: summary.balance, income: summary.income, expenses: summary.expenses,
                          savingsRate: summary.income.isZero ? nil : summary.savingsRate)
    }

    // MARK: - Private

    @ObservationIgnored private let timeZone: TimeZone
    @ObservationIgnored private let now: () -> Date
}

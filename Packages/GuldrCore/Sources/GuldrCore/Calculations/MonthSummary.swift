//
//  MonthSummary.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation

/// The Dashboard's numbers for one month, in the active currency (ADR 005).
///
/// - `balance` is the all-time net: every income minus every expense ever recorded, whatever its
///   date. It does not depend on `month`.
/// - `income`, `expenses` and `savingsRate` cover `month` in `timeZone`.
///
/// Transactions in other currencies are ignored: v1 totals only the active currency.
public struct MonthSummary: Equatable, Sendable {

    public let month: YearMonth
    public let balance: Money
    public let income: Money
    public let expenses: Money
    /// Share of the month's income that was not spent, clamped to 0…1; 0 when there was no income.
    public let savingsRate: Double

    /// Income minus expenses for the month; negative when the month spent more than it earned.
    public var net: Money {
        Money.unchecked(income.minorUnits - expenses.minorUnits, income.currencyCode)
    }

    public init(transactions: some Sequence<Transaction>, month: YearMonth, currencyCode: String,
                timeZone: TimeZone = .autoupdatingCurrent) throws(MoneyError) {
        let code = try Currency.validatedCode(currencyCode)
        let interval = month.dateInterval(in: timeZone)
        var balance = Tally()
        var income = Tally()
        var expenses = Tally()

        for transaction in transactions where transaction.currencyCode == code {
            let inMonth = interval.contains(transaction.date) && transaction.date != interval.end
            switch transaction.kind {
            case .income:
                try balance.add(transaction.amountMinorUnits)
                if inMonth { try income.add(transaction.amountMinorUnits) }
            case .expense:
                try balance.subtract(transaction.amountMinorUnits)
                if inMonth { try expenses.add(transaction.amountMinorUnits) }
            }
        }

        self.month = month
        self.balance = balance.money(code)
        self.income = income.money(code)
        self.expenses = expenses.money(code)
        if income.minorUnits > 0 {
            let rate = Double(income.minorUnits - expenses.minorUnits) / Double(income.minorUnits)
            savingsRate = min(1, max(0, rate))
        } else {
            savingsRate = 0
        }
    }
}

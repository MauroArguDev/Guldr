//
//  WidgetSummary.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation

/// What the home screen widgets show, computed from the shared store with the same calculations as the
/// app's Dashboard (ADR 007): the balance, with its starting balance (ADR 016), and the month's income
/// and expenses in the active currency, and the newest transactions in any currency, as Recent shows them.
public struct WidgetSummary: Equatable, Sendable {

    /// One row of the medium widget: "Groceries", "Today", −$42.80.
    public struct Recent: Equatable, Sendable, Identifiable {
        public let id: UUID
        public let title: String
        public let meta: String
        public let amount: Money
        public let kind: TransactionKind

        public init(id: UUID, title: String, meta: String, amount: Money, kind: TransactionKind) {
            self.id = id
            self.title = title
            self.meta = meta
            self.amount = amount
            self.kind = kind
        }
    }

    /// How many rows the medium widget has room for (Widgets mockup).
    public static let recentLimit = 3

    public let balance: Money
    public let monthIncome: Money
    public let monthExpenses: Money
    /// The month's abbreviation for the small widget's "Sep: −$1,759.50".
    public let monthLabel: String
    public let recent: [Recent]

    /// No transactions yet: the widgets invite the first one instead of showing empty rows.
    public var isEmpty: Bool { recent.isEmpty }

    /// Values as they are, for placeholders and previews.
    public init(balance: Money, monthIncome: Money, monthExpenses: Money, monthLabel: String, recent: [Recent]) {
        self.balance = balance
        self.monthIncome = monthIncome
        self.monthExpenses = monthExpenses
        self.monthLabel = monthLabel
        self.recent = recent
    }

    /// `categoryName` names a transaction without a description: the app passes its translated name, and
    /// `nil` stands for no category. `openingBalance` is the currency's starting balance in minor units.
    public init(transactions: [Transaction], currencyCode: String, openingBalance: Int64 = 0, now: Date,
                timeZone: TimeZone = .autoupdatingCurrent, locale: Locale = .autoupdatingCurrent,
                categoryName: (Category?) -> String) throws(MoneyError) {
        let month = YearMonth(containing: now, timeZone: timeZone)
        let summary = try MonthSummary(transactions: transactions, month: month, currencyCode: currencyCode,
                                       openingBalance: openingBalance, timeZone: timeZone)
        balance = summary.balance
        monthIncome = summary.income
        monthExpenses = summary.expenses

        var style = Date.FormatStyle(locale: locale, calendar: YearMonth.calendar(timeZone), timeZone: timeZone)
            .month(.abbreviated)
        style.capitalizationContext = .standalone
        monthLabel = month.dateInterval(in: timeZone).start.formatted(style)

        let days = DayLabelFormatter(locale: locale, timeZone: timeZone)
        recent = transactions
            .sorted { ($0.date, $0.createdAt) > ($1.date, $1.createdAt) }
            .prefix(Self.recentLimit)
            .map { transaction in
                Recent(id: transaction.id,
                       title: transaction.title.isEmpty ? categoryName(transaction.category) : transaction.title,
                       meta: days.shortLabel(for: transaction.date, relativeTo: now),
                       amount: transaction.amount,
                       kind: transaction.kind)
            }
    }

    /// The Widgets mockup's numbers in US dollars, for the widget gallery and placeholders, where the
    /// user's own numbers must not appear. Day labels follow the device's language.
    public static var sample: WidgetSummary {
        let usd = { (cents: Int64) in Money.unchecked(cents, "USD") }
        let now = Date.now
        let days = DayLabelFormatter()
        let day: TimeInterval = 86_400
        return WidgetSummary(
            balance: usd(1_248_000), monthIncome: usd(500_000), monthExpenses: usd(175_950),
            monthLabel: now.formatted(.dateTime.month(.abbreviated)),
            recent: [
                Recent(id: UUID(), title: "Groceries", meta: days.shortLabel(for: now, relativeTo: now),
                       amount: usd(4_280), kind: .expense),
                Recent(id: UUID(), title: "Salary", meta: days.shortLabel(for: now - 3 * day, relativeTo: now),
                       amount: usd(500_000), kind: .income),
                Recent(id: UUID(), title: "Gas", meta: days.shortLabel(for: now - 4 * day, relativeTo: now),
                       amount: usd(3_500), kind: .expense)
            ])
    }
}

//
//  BudgetModel.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 20/10/26.
//

import Foundation
import GuldrCore
import Observation
import SwiftData

/// The Budget screen's state. Like the Dashboard, the view owns the `@Query`s and the model never holds a
/// context, so the view can create it before its environment exists.
@Observable
final class BudgetModel {

    /// What the ring card shows: the month's budgets added up.
    struct Overview: Equatable {
        /// The ring's "available"; zero once the month is over its total.
        let remaining: Money
        let spent: Money
        let limit: Money
        /// Total spent over total limit; above 1 when the month is over.
        let usage: Double
        /// "71% used · 2 days left"; a past month shows only the percentage.
        let detail: String
    }

    /// One category over its limit, for `OverBudgetAlert`.
    struct Alert: Identifiable, Equatable {
        let id: UUID
        let categoryName: String
        let overAmount: Money
    }

    /// One budgeted category, for `CategoryBudgetRow`.
    struct Row: Identifiable, Equatable {
        let id: UUID
        let name: String
        let symbol: String
        let line: BudgetStatus.Line
    }

    /// What one month shows.
    struct Page: Equatable {
        /// `nil` when the month has no budgets in the active currency, or before the first `update`.
        var overview: Overview?
        /// Over-budget categories, the furthest over first.
        var alerts: [Alert] = []
        /// Every budgeted category, highest usage first (`BudgetStatus`'s order).
        var rows: [Row] = []
        /// Whether the month before has budgets to copy, so an empty month can offer it.
        var canCopyLastMonth = false
    }

    /// The month on screen; starts at the current one.
    private(set) var month: YearMonth

    init(locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent,
         now: @escaping () -> Date = { .now }) {
        self.locale = locale
        self.timeZone = timeZone
        self.now = now
        month = YearMonth(containing: now(), timeZone: timeZone)
    }

    /// "September 2026".
    var monthTitle: String {
        month.title(locale: locale, timeZone: timeZone)
    }

    /// Past months have no limit, so their budgets and spending stay readable; future ones stop at next
    /// month, so a budget can be planned before the month starts (author's call, 2026-10-20).
    var canShowNextMonth: Bool {
        month < latestMonth
    }

    func showPreviousMonth() {
        month = month.previous
    }

    func showNextMonth() {
        guard canShowNextMonth else { return }
        month = month.next
    }

    /// The month on screen and the ones a swipe reaches, oldest first.
    var visibleMonths: [YearMonth] {
        canShowNextMonth ? [month.previous, month, month.next] : [month.previous, month]
    }

    /// The month on screen's page.
    var page: Page { page(for: month) }

    /// A month in `visibleMonths`; empty until the first `update`, or for any other month.
    func page(for month: YearMonth) -> Page {
        pages[month] ?? Page()
    }

    /// Moves to the month a swipe lands on: past half a page, counting how far its speed would carry it.
    func finishSwipe(translation: Double, velocity: Double, pageWidth: Double) {
        let landing = translation + velocity * 0.2
        guard abs(landing) > pageWidth / 2 else { return }
        if landing < 0 {
            showNextMonth()
        } else {
            showPreviousMonth()
        }
    }

    /// Recomputes `visibleMonths` from the latest transactions and budgets in the active currency.
    /// The view calls it when they, the currency, a save or the month change.
    func update(transactions: [Transaction], budgets: [Budget], currencyCode: String) {
        pages = Dictionary(uniqueKeysWithValues: visibleMonths.map { month in
            (month, makePage(for: month, transactions: transactions, budgets: budgets, currencyCode: currencyCode))
        })
    }

    // MARK: - Private

    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let timeZone: TimeZone
    @ObservationIgnored private let now: () -> Date
    private var pages: [YearMonth: Page] = [:]

    private func makePage(for month: YearMonth, transactions: [Transaction], budgets: [Budget],
                          currencyCode: String) -> Page {
        let previousKey = month.previous.rawValue
        let canCopyLastMonth = budgets.contains { budget in
            budget.yearMonth == previousKey && budget.currencyCode == currencyCode
                && budget.category.map { !$0.isArchived && $0.kind == .expense } == true
        }
        guard let status = try? BudgetStatus(budgets: budgets, transactions: transactions, month: month,
                                             currencyCode: currencyCode, now: now(), timeZone: timeZone),
              !status.lines.isEmpty else {
            return Page(canCopyLastMonth: canCopyLastMonth)
        }
        let overview = Overview(remaining: status.totalRemaining, spent: status.totalSpent, limit: status.totalLimit,
                                usage: status.overallUsage, detail: detail(for: status))

        var categories: [UUID: Category] = [:]
        for budget in budgets {
            if let category = budget.category { categories[category.id] = category }
        }
        let fallbackName = String(localized: "Uncategorized", locale: locale)
        let rows = status.lines.map { line in
            let category = categories[line.categoryID]
            return Row(id: line.id, name: category?.displayName ?? fallbackName,
                       symbol: category?.symbolName ?? "questionmark", line: line)
        }
        let alerts = rows.filter(\.line.isOver).map { row in
            Alert(id: row.id, categoryName: row.name, overAmount: row.line.overAmount)
        }
        return Page(overview: overview, alerts: alerts, rows: rows, canCopyLastMonth: canCopyLastMonth)
    }

    /// "71% used · 2 days left". Days left mean nothing once the month is over, so a past month shows
    /// only the percentage; a future month counts all its days.
    private func detail(for status: BudgetStatus) -> String {
        let percent = status.overallUsage.formatted(.percent.precision(.fractionLength(0)).locale(locale))
        let used = String(localized: "\(percent) used", locale: locale)
        guard status.month >= YearMonth(containing: now(), timeZone: timeZone) else { return used }
        return used + " · " + String(localized: "\(status.daysLeft) days left", locale: locale)
    }

    /// Read from the clock each time, so a screen left open across midnight on the last day still moves on.
    private var latestMonth: YearMonth {
        YearMonth(containing: now(), timeZone: timeZone).next
    }
}

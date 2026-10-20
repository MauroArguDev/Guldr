//
//  BudgetModel.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 20/10/26.
//

import Foundation
import GuldrCore
import Observation

/// The Budget screen's state. Like the Dashboard, the view owns the `@Query`s and the model never holds a
/// context, so the view can create it before its environment exists.
@Observable
final class BudgetModel {

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

    // MARK: - Private

    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let timeZone: TimeZone
    @ObservationIgnored private let now: () -> Date

    /// Read from the clock each time, so a screen left open across midnight on the last day still moves on.
    private var latestMonth: YearMonth {
        YearMonth(containing: now(), timeZone: timeZone).next
    }
}

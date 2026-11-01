//
//  Preferences.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import GuldrCore
import Observation

/// The app's observable view of `AppSettings`. `UserDefaults` does not notify SwiftUI, so this keeps
/// the values views read and writes every change through, which the widget then sees.
@Observable
final class Preferences {

    private(set) var activeCurrencyCode: String?
    private(set) var hasCompletedOnboarding: Bool
    /// Settings › Security › "Hide amounts in widgets", independent of the lock (author's call, 2026-10-23).
    private(set) var hidesWidgetAmounts: Bool
    /// The month whose recap card was closed on Home (v1 plan, Phase 31).
    private(set) var dismissedRecapMonth: YearMonth?
    /// The starting balance per currency, in minor units (ADR 016).
    private(set) var openingBalances: [String: Int64]
    /// Whether the starting balance was asked for, so Home's card shows once to earlier users.
    private(set) var hasOfferedStartingBalance: Bool

    init(settings: AppSettings) {
        self.settings = settings
        activeCurrencyCode = settings.activeCurrencyCode
        hasCompletedOnboarding = settings.hasCompletedOnboarding
        hidesWidgetAmounts = settings.hidesWidgetAmounts
        dismissedRecapMonth = settings.dismissedRecapMonth
        openingBalances = settings.openingBalances
        hasOfferedStartingBalance = settings.hasOfferedStartingBalance
    }

    /// `startingBalance` is what the user has today, in minor units; nothing is logged yet.
    func completeOnboarding(currencyCode: String, startingBalance: Int64 = 0) throws(MoneyError) {
        try settings.completeOnboarding(currencyCode: currencyCode, startingBalance: startingBalance)
        activeCurrencyCode = settings.activeCurrencyCode
        hasCompletedOnboarding = settings.hasCompletedOnboarding
        openingBalances = settings.openingBalances
        hasOfferedStartingBalance = settings.hasOfferedStartingBalance
    }

    /// Zero for a currency without one.
    func openingBalance(for currencyCode: String) -> Int64 {
        openingBalances[currencyCode] ?? 0
    }

    /// Stores the starting balance that makes the balance show what the user has today (ADR 016), and
    /// counts as having asked for it.
    func setOpeningBalance(_ minorUnits: Int64, for currencyCode: String) throws(MoneyError) {
        try settings.setOpeningBalance(minorUnits, for: currencyCode)
        settings.setHasOfferedStartingBalance()
        openingBalances = settings.openingBalances
        hasOfferedStartingBalance = settings.hasOfferedStartingBalance
    }

    /// Home's card was closed: it doesn't come back, and Settings keeps the row.
    func dismissStartingBalanceOffer() {
        settings.setHasOfferedStartingBalance()
        hasOfferedStartingBalance = settings.hasOfferedStartingBalance
    }

    /// Changes the currency totals show (ADR 005). Nothing is converted: transactions keep their own.
    func setActiveCurrency(_ code: String) throws(MoneyError) {
        try settings.setActiveCurrency(code)
        activeCurrencyCode = settings.activeCurrencyCode
    }

    func setHidesWidgetAmounts(_ hides: Bool) {
        settings.setHidesWidgetAmounts(hides)
        hidesWidgetAmounts = settings.hidesWidgetAmounts
    }

    func dismissRecap(_ month: YearMonth) {
        settings.setDismissedRecapMonth(month)
        dismissedRecapMonth = settings.dismissedRecapMonth
    }

    /// After "Delete all data": `LaunchGate` sees first launch is no longer completed and shows the
    /// welcome screen.
    func reset() {
        settings.reset()
        activeCurrencyCode = settings.activeCurrencyCode
        hasCompletedOnboarding = settings.hasCompletedOnboarding
        hidesWidgetAmounts = settings.hidesWidgetAmounts
        dismissedRecapMonth = settings.dismissedRecapMonth
        openingBalances = settings.openingBalances
        hasOfferedStartingBalance = settings.hasOfferedStartingBalance
    }

    // MARK: - Private

    @ObservationIgnored private let settings: AppSettings
}

#if DEBUG
extension Preferences {
    /// In-memory preferences for previews, backed by a throwaway defaults suite.
    static func preview(onboarded: Bool, currencyCode: String = "USD") -> Preferences {
        let suiteName = "preview.\(UUID().uuidString)"
        let settings = AppSettings(defaults: UserDefaults(suiteName: suiteName) ?? .standard)
        if onboarded {
            try? settings.completeOnboarding(currencyCode: currencyCode)
        }
        return Preferences(settings: settings)
    }
}
#endif

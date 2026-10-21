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
    /// Settings › "Hide amounts in widgets". The lock hides them too, whatever this says (ADR 011).
    private(set) var hidesWidgetAmounts: Bool

    init(settings: AppSettings) {
        self.settings = settings
        activeCurrencyCode = settings.activeCurrencyCode
        hasCompletedOnboarding = settings.hasCompletedOnboarding
        hidesWidgetAmounts = settings.hidesWidgetAmounts
    }

    func completeOnboarding(currencyCode: String) throws(MoneyError) {
        try settings.completeOnboarding(currencyCode: currencyCode)
        activeCurrencyCode = settings.activeCurrencyCode
        hasCompletedOnboarding = settings.hasCompletedOnboarding
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

    /// After "Delete all data": `LaunchGate` sees first launch is no longer completed and shows the
    /// welcome screen.
    func reset() {
        settings.reset()
        activeCurrencyCode = settings.activeCurrencyCode
        hasCompletedOnboarding = settings.hasCompletedOnboarding
        hidesWidgetAmounts = settings.hidesWidgetAmounts
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

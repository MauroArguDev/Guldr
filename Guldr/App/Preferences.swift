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

    init(settings: AppSettings) {
        self.settings = settings
        activeCurrencyCode = settings.activeCurrencyCode
        hasCompletedOnboarding = settings.hasCompletedOnboarding
    }

    func completeOnboarding(currencyCode: String) throws(MoneyError) {
        try settings.completeOnboarding(currencyCode: currencyCode)
        activeCurrencyCode = settings.activeCurrencyCode
        hasCompletedOnboarding = settings.hasCompletedOnboarding
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

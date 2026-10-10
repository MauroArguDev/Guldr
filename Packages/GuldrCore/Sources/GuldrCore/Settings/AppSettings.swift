//
//  AppSettings.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation

/// Small preferences shared by the app and the widget, kept in the App Group's `UserDefaults`: the
/// active currency (ADR 005), which the widget needs to total the right transactions, and whether first
/// launch was completed. Data lives in SwiftData; only these few values live here.
public struct AppSettings {

    enum Key {
        static let activeCurrencyCode = "activeCurrencyCode"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    private let defaults: UserDefaults

    /// Tests pass a throwaway suite; the app and widget use `shared(appGroupID:)`.
    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// The App Group's defaults. Throws when the group cannot be opened, like the store does.
    public static func shared(appGroupID: String) throws(PersistenceError) -> AppSettings {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            throw .appGroupUnavailable(appGroupID)
        }
        return AppSettings(defaults: defaults)
    }

    /// The currency new transactions use and totals include. `nil` before first launch completes, or if
    /// the stored value is not a known ISO 4217 code.
    public var activeCurrencyCode: String? {
        guard let stored = defaults.string(forKey: Key.activeCurrencyCode) else { return nil }
        return try? Currency.validatedCode(stored)
    }

    public var hasCompletedOnboarding: Bool {
        defaults.bool(forKey: Key.hasCompletedOnboarding)
    }

    /// Validates and stores the active currency.
    public func setActiveCurrency(_ code: String) throws(MoneyError) {
        defaults.set(try Currency.validatedCode(code), forKey: Key.activeCurrencyCode)
    }

    /// Ends first launch. The currency is stored before the flag, so a completed onboarding always has
    /// a currency; an invalid code throws and leaves both untouched.
    public func completeOnboarding(currencyCode: String) throws(MoneyError) {
        try setActiveCurrency(currencyCode)
        defaults.set(true, forKey: Key.hasCompletedOnboarding)
    }
}

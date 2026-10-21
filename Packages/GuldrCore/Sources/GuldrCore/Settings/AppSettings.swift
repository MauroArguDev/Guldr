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
        static let isLockEnabled = "isLockEnabled"
        static let lockGracePeriod = "lockGracePeriod"
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

    /// Whether the app asks for Face ID or the passcode on launch and after the grace period (ADR 011).
    /// Shared so the widget can respect it.
    public var isLockEnabled: Bool {
        defaults.bool(forKey: Key.isLockEnabled)
    }

    /// The default when nothing is stored or the stored value is not one of the choices.
    public var lockGracePeriod: LockGracePeriod {
        guard defaults.object(forKey: Key.lockGracePeriod) != nil else { return .default }
        return LockGracePeriod(rawValue: defaults.integer(forKey: Key.lockGracePeriod)) ?? .default
    }

    public func setLockEnabled(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: Key.isLockEnabled)
    }

    public func setLockGracePeriod(_ period: LockGracePeriod) {
        defaults.set(period.rawValue, forKey: Key.lockGracePeriod)
    }

    /// Validates and stores the active currency.
    public func setActiveCurrency(_ code: String) throws(MoneyError) {
        defaults.set(try Currency.validatedCode(code), forKey: Key.activeCurrencyCode)
    }

    /// Forgets every preference, so the app opens on the welcome screen again with the lock off.
    public func reset() {
        for key in [Key.activeCurrencyCode, Key.hasCompletedOnboarding, Key.isLockEnabled, Key.lockGracePeriod] {
            defaults.removeObject(forKey: key)
        }
    }

    /// Ends first launch. The currency is stored before the flag, so a completed onboarding always has
    /// a currency; an invalid code throws and leaves both untouched.
    public func completeOnboarding(currencyCode: String) throws(MoneyError) {
        try setActiveCurrency(currencyCode)
        defaults.set(true, forKey: Key.hasCompletedOnboarding)
    }
}

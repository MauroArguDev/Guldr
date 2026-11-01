//
//  AppSettings.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation

/// Small preferences shared by the app and the widget, kept in the App Group's `UserDefaults`: the
/// active currency (ADR 005), which the widget needs to total the right transactions, the starting
/// balances (ADR 016) and whether first launch was completed. Data lives in SwiftData; only these few
/// values live here.
public struct AppSettings {

    enum Key {
        static let activeCurrencyCode = "activeCurrencyCode"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let isLockEnabled = "isLockEnabled"
        static let lockGracePeriod = "lockGracePeriod"
        static let hidesWidgetAmounts = "hidesWidgetAmounts"
        static let budgetAlertsEnabled = "budgetAlertsEnabled"
        static let hasOfferedBudgetAlerts = "hasOfferedBudgetAlerts"
        static let budgetAlertKeys = "budgetAlertKeys"
        static let dailyReminderEnabled = "dailyReminderEnabled"
        static let dailyReminderMinutes = "dailyReminderMinutes"
        static let hasOfferedDailyReminder = "hasOfferedDailyReminder"
        static let hidesStreak = "hidesStreak"
        static let hasImportedStreakHistory = "hasImportedStreakHistory"
        static let celebratedStreakRun = "celebratedStreakRun"
        static let celebratedStreakMilestone = "celebratedStreakMilestone"
        static let hasRecordedAchievementHistory = "hasRecordedAchievementHistory"
        static let dismissedRecapMonth = "dismissedRecapMonth"
        static let openingBalances = "openingBalances"
        static let hasOfferedStartingBalance = "hasOfferedStartingBalance"
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

    /// The starting balance per currency code, in minor units (ADR 016). Only the balance adds it; it can
    /// be negative, since it's what the user has today minus what they had already logged.
    public var openingBalances: [String: Int64] {
        guard let stored = defaults.dictionary(forKey: Key.openingBalances) else { return [:] }
        return stored.compactMapValues { ($0 as? NSNumber)?.int64Value }
    }

    /// Zero for a currency without one.
    public func openingBalance(for currencyCode: String) -> Int64 {
        openingBalances[currencyCode] ?? 0
    }

    /// Validates the code and stores the starting balance; zero removes it.
    public func setOpeningBalance(_ minorUnits: Int64, for currencyCode: String) throws(MoneyError) {
        let code = try Currency.validatedCode(currencyCode)
        var balances = openingBalances
        balances[code] = minorUnits == 0 ? nil : minorUnits
        defaults.set(balances.mapValues { NSNumber(value: $0) }, forKey: Key.openingBalances)
    }

    /// Whether the starting balance was asked for, in onboarding or by Home's card, so the card shows once
    /// to users who finished onboarding before it existed.
    public var hasOfferedStartingBalance: Bool {
        defaults.bool(forKey: Key.hasOfferedStartingBalance)
    }

    public func setHasOfferedStartingBalance() {
        defaults.set(true, forKey: Key.hasOfferedStartingBalance)
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

    /// Settings › Security › "Hide amounts in widgets", off by default. Independent of the lock (author's
    /// call, 2026-10-23): a locked app can still show its balance on the home screen if the user wants.
    public var hidesWidgetAmounts: Bool {
        defaults.bool(forKey: Key.hidesWidgetAmounts)
    }

    /// Settings › "Budget alerts". Off until the user turns them on, from the pre-prompt or Settings.
    public var budgetAlertsEnabled: Bool {
        defaults.bool(forKey: Key.budgetAlertsEnabled)
    }

    /// Whether the pre-prompt was shown, so it's offered once (author's call, 2026-10-21).
    public var hasOfferedBudgetAlerts: Bool {
        defaults.bool(forKey: Key.hasOfferedBudgetAlerts)
    }

    /// The thresholds already notified this month (`BudgetAlertLedger`).
    public var budgetAlertLedger: BudgetAlertLedger {
        BudgetAlertLedger(keys: defaults.stringArray(forKey: Key.budgetAlertKeys) ?? [])
    }

    /// Settings › "Daily reminder". Off until the user turns it on, from its pre-prompt or Settings.
    public var dailyReminderEnabled: Bool {
        defaults.bool(forKey: Key.dailyReminderEnabled)
    }

    /// The reminder's time; the default when nothing valid is stored.
    public var dailyReminderTime: ReminderTime {
        guard defaults.object(forKey: Key.dailyReminderMinutes) != nil else { return .default }
        return ReminderTime(minutesAfterMidnight: defaults.integer(forKey: Key.dailyReminderMinutes)) ?? .default
    }

    /// Whether the reminder's pre-prompt was shown, so it's offered once (author's call, 2026-10-23).
    public var hasOfferedDailyReminder: Bool {
        defaults.bool(forKey: Key.hasOfferedDailyReminder)
    }

    public func setDailyReminderEnabled(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: Key.dailyReminderEnabled)
    }

    public func setDailyReminderTime(_ time: ReminderTime) {
        defaults.set(time.minutesAfterMidnight, forKey: Key.dailyReminderMinutes)
    }

    public func setHasOfferedDailyReminder() {
        defaults.set(true, forKey: Key.hasOfferedDailyReminder)
    }

    /// Settings › "Show streak" turned off (ADR 012). Days are still recorded while it's hidden.
    public var hidesStreak: Bool {
        defaults.bool(forKey: Key.hidesStreak)
    }

    /// Whether the history was imported once into logged days (`LoggedDays.importHistory`).
    public var hasImportedStreakHistory: Bool {
        defaults.bool(forKey: Key.hasImportedStreakHistory)
    }

    /// The highest milestone celebrated in the run that started on `runStart`; 0 for another run.
    public func celebratedMilestone(inRunStartingOn runStart: LocalDay) -> Int {
        guard defaults.integer(forKey: Key.celebratedStreakRun) == runStart.rawValue else { return 0 }
        return defaults.integer(forKey: Key.celebratedStreakMilestone)
    }

    /// Whether the history's achievements were recorded once, silently (ADR 013).
    public var hasRecordedAchievementHistory: Bool {
        defaults.bool(forKey: Key.hasRecordedAchievementHistory)
    }

    /// The month whose recap card the user closed on Home, so it stays closed until the next month.
    public var dismissedRecapMonth: YearMonth? {
        YearMonth(rawValue: defaults.integer(forKey: Key.dismissedRecapMonth))
    }

    public func setDismissedRecapMonth(_ month: YearMonth) {
        defaults.set(month.rawValue, forKey: Key.dismissedRecapMonth)
    }

    public func setHasRecordedAchievementHistory() {
        defaults.set(true, forKey: Key.hasRecordedAchievementHistory)
    }

    public func setHidesStreak(_ hides: Bool) {
        defaults.set(hides, forKey: Key.hidesStreak)
    }

    public func setHasImportedStreakHistory() {
        defaults.set(true, forKey: Key.hasImportedStreakHistory)
    }

    public func setCelebratedMilestone(_ milestone: Int, inRunStartingOn runStart: LocalDay) {
        defaults.set(runStart.rawValue, forKey: Key.celebratedStreakRun)
        defaults.set(milestone, forKey: Key.celebratedStreakMilestone)
    }

    public func setBudgetAlertsEnabled(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: Key.budgetAlertsEnabled)
    }

    public func setHasOfferedBudgetAlerts() {
        defaults.set(true, forKey: Key.hasOfferedBudgetAlerts)
    }

    public func setBudgetAlertLedger(_ ledger: BudgetAlertLedger) {
        defaults.set(ledger.keys.sorted(), forKey: Key.budgetAlertKeys)
    }

    public func setHidesWidgetAmounts(_ hides: Bool) {
        defaults.set(hides, forKey: Key.hidesWidgetAmounts)
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
        for key in [Key.activeCurrencyCode, Key.hasCompletedOnboarding, Key.isLockEnabled, Key.lockGracePeriod,
                    Key.hidesWidgetAmounts, Key.budgetAlertsEnabled, Key.hasOfferedBudgetAlerts, Key.budgetAlertKeys,
                    Key.dailyReminderEnabled, Key.dailyReminderMinutes, Key.hasOfferedDailyReminder, Key.hidesStreak,
                    Key.hasImportedStreakHistory, Key.celebratedStreakRun, Key.celebratedStreakMilestone,
                    Key.hasRecordedAchievementHistory, Key.dismissedRecapMonth, Key.openingBalances,
                    Key.hasOfferedStartingBalance] {
            defaults.removeObject(forKey: key)
        }
    }

    /// Ends first launch with what the user has today, which becomes the currency's starting balance: no
    /// transaction exists yet. The currency is stored before the flag, so a completed onboarding always
    /// has a currency; an invalid code throws and leaves everything untouched.
    public func completeOnboarding(currencyCode: String, startingBalance: Int64 = 0) throws(MoneyError) {
        try setActiveCurrency(currencyCode)
        try setOpeningBalance(startingBalance, for: currencyCode)
        setHasOfferedStartingBalance()
        defaults.set(true, forKey: Key.hasCompletedOnboarding)
    }
}

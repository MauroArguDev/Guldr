//
//  AppSettingsTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import Testing
@testable import GuldrCore

/// Each test gets its own defaults suite, removed afterwards, so nothing leaks between tests or into
/// the machine's preferences.
struct AppSettingsTests {

    @Test func startsWithoutCurrencyOrOnboarding() {
        withSettings { settings, _ in
            #expect(settings.activeCurrencyCode == nil)
            #expect(!settings.hasCompletedOnboarding)
        }
    }

    @Test func completingOnboardingStoresTheCurrencyUppercased() throws {
        try withSettings { settings, _ in
            try settings.completeOnboarding(currencyCode: "eur")
            #expect(settings.activeCurrencyCode == "EUR")
            #expect(settings.hasCompletedOnboarding)
        }
    }

    @Test func anInvalidCurrencyLeavesEverythingUntouched() {
        withSettings { settings, _ in
            #expect(throws: MoneyError.unknownCurrency("XYZ")) {
                try settings.completeOnboarding(currencyCode: "XYZ")
            }
            #expect(settings.activeCurrencyCode == nil)
            #expect(!settings.hasCompletedOnboarding)
        }
    }

    @Test func changingTheCurrencyKeepsOnboardingDone() throws {
        try withSettings { settings, _ in
            try settings.completeOnboarding(currencyCode: "USD")
            try settings.setActiveCurrency("MXN")
            #expect(settings.activeCurrencyCode == "MXN")
            #expect(settings.hasCompletedOnboarding)
        }
    }

    @Test func aCorruptStoredCurrencyReadsAsNone() {
        withSettings { settings, defaults in
            defaults.set("not a currency", forKey: AppSettings.Key.activeCurrencyCode)
            #expect(settings.activeCurrencyCode == nil)
        }
    }

    @Test func valuesAreSharedThroughTheSuite() throws {
        try withSettings { settings, defaults in
            try settings.completeOnboarding(currencyCode: "JPY")
            // A second instance on the same suite, as the widget would open it, sees the same values.
            let other = AppSettings(defaults: defaults)
            #expect(other.activeCurrencyCode == "JPY")
            #expect(other.hasCompletedOnboarding)
        }
    }

    @Test func theLockStartsOffWithAOneMinuteGracePeriod() {
        withSettings { settings, defaults in
            #expect(!settings.isLockEnabled)
            #expect(settings.lockGracePeriod == .oneMinute)
            // A value no version of the app writes falls back to the default.
            defaults.set(42, forKey: AppSettings.Key.lockGracePeriod)
            #expect(settings.lockGracePeriod == .oneMinute)
        }
    }

    @Test func lockPreferencesAreStoredAndReset() {
        withSettings { settings, defaults in
            settings.setLockEnabled(true)
            settings.setLockGracePeriod(.immediately)
            #expect(settings.isLockEnabled)
            #expect(settings.lockGracePeriod == .immediately)
            #expect(AppSettings(defaults: defaults).lockGracePeriod == .immediately)

            settings.reset()
            #expect(!settings.isLockEnabled)
            #expect(settings.lockGracePeriod == .oneMinute)
        }
    }

    @Test func widgetAmountsFollowOnlyTheirSetting() {
        withSettings { settings, _ in
            #expect(!settings.hidesWidgetAmounts)
            // The lock doesn't hide them (author's call, 2026-10-23).
            settings.setLockEnabled(true)
            #expect(!settings.hidesWidgetAmounts)
            settings.setHidesWidgetAmounts(true)
            #expect(settings.hidesWidgetAmounts)
            settings.reset()
            #expect(!settings.hidesWidgetAmounts)
        }
    }

    @Test func budgetAlertPreferencesAreStoredAndReset() {
        withSettings { settings, defaults in
            #expect(!settings.budgetAlertsEnabled)
            #expect(!settings.hasOfferedBudgetAlerts)
            settings.setBudgetAlertsEnabled(true)
            settings.setHasOfferedBudgetAlerts()
            settings.setBudgetAlertLedger(BudgetAlertLedger(keys: ["202610:A:80"]))
            #expect(AppSettings(defaults: defaults).budgetAlertLedger.keys == ["202610:A:80"])

            settings.reset()
            #expect(!settings.budgetAlertsEnabled)
            #expect(!settings.hasOfferedBudgetAlerts)
            #expect(settings.budgetAlertLedger.keys.isEmpty)
        }
    }

    @Test func dailyReminderPreferencesAreStoredAndReset() throws {
        try withSettings { settings, defaults in
            #expect(!settings.dailyReminderEnabled)
            #expect(!settings.hasOfferedDailyReminder)
            #expect(settings.dailyReminderTime == .default)

            settings.setDailyReminderEnabled(true)
            settings.setHasOfferedDailyReminder()
            settings.setDailyReminderTime(try #require(ReminderTime(hour: 21, minute: 15)))
            #expect(AppSettings(defaults: defaults).dailyReminderTime == ReminderTime(hour: 21, minute: 15))

            defaults.set(5_000, forKey: AppSettings.Key.dailyReminderMinutes)
            #expect(settings.dailyReminderTime == .default)

            settings.reset()
            #expect(!settings.dailyReminderEnabled)
            #expect(!settings.hasOfferedDailyReminder)
            #expect(defaults.object(forKey: AppSettings.Key.dailyReminderMinutes) == nil)
        }
    }

    @Test func streakPreferencesAreStoredAndReset() throws {
        try withSettings { settings, _ in
            let run = try #require(LocalDay(year: 2026, month: 10, day: 20))
            let otherRun = try #require(LocalDay(year: 2026, month: 10, day: 1))
            #expect(!settings.hidesStreak)
            #expect(!settings.hasImportedStreakHistory)
            #expect(settings.celebratedMilestone(inRunStartingOn: run) == 0)

            settings.setHidesStreak(true)
            settings.setHasImportedStreakHistory()
            settings.setHasRecordedAchievementHistory()
            settings.setCelebratedMilestone(7, inRunStartingOn: run)
            #expect(settings.celebratedMilestone(inRunStartingOn: run) == 7)
            #expect(settings.celebratedMilestone(inRunStartingOn: otherRun) == 0)

            settings.reset()
            #expect(!settings.hidesStreak)
            #expect(!settings.hasImportedStreakHistory)
            #expect(!settings.hasRecordedAchievementHistory)
            #expect(settings.celebratedMilestone(inRunStartingOn: run) == 0)
        }
    }

    @Test func resetForgetsTheCurrencyAndFirstLaunch() throws {
        try withSettings { settings, defaults in
            try settings.completeOnboarding(currencyCode: "EUR")
            settings.reset()
            #expect(settings.activeCurrencyCode == nil)
            #expect(!settings.hasCompletedOnboarding)
            #expect(defaults.object(forKey: AppSettings.Key.activeCurrencyCode) == nil)
        }
    }

    // MARK: - Helpers

    private func withSettings(_ body: (AppSettings, UserDefaults) throws -> Void) rethrows {
        let suiteName = "GuldrCoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create the defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(AppSettings(defaults: defaults), defaults)
    }
}

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

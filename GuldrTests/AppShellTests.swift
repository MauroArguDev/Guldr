//
//  AppShellTests.swift
//  GuldrTests
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import GuldrCore
import Testing
@testable import Guldr

/// Navigation state: tabs, sheets and deep links.
struct AppRouterTests {

    @Test func startsOnHomeWithNoSheet() {
        let router = AppRouter()
        #expect(router.selectedTab == .home)
        #expect(router.sheet == nil)
    }

    @Test func selectingATabSwitchesToIt() {
        let router = AppRouter()
        router.select(.analytics)
        #expect(router.selectedTab == .analytics)
        #expect(router.sheet == nil)
    }

    @Test func theAddButtonOpensTheSheetAndKeepsTheTab() {
        let router = AppRouter()
        router.select(.budget)
        router.select(.add)
        #expect(router.selectedTab == .budget)
        #expect(router.sheet == .addTransaction)
        router.dismissSheet()
        #expect(router.sheet == nil)
    }

    @Test func addLinkOpensTheSheetOverTheCurrentTab() {
        let router = AppRouter()
        router.select(.transactions)
        #expect(router.open(DeepLink.add.url))
        #expect(router.selectedTab == .transactions)
        #expect(router.sheet == .addTransaction)
    }

    @Test func budgetLinkClosesAnySheetAndShowsBudget() {
        let router = AppRouter()
        router.present(.addTransaction)
        #expect(router.open(DeepLink.budget.url))
        #expect(router.selectedTab == .budget)
        #expect(router.sheet == nil)
    }

    @Test func unknownLinksChangeNothing() throws {
        let router = AppRouter()
        router.select(.analytics)
        #expect(!router.open(try #require(URL(string: "guldr://settings"))))
        #expect(router.selectedTab == .analytics)
        #expect(router.sheet == nil)
    }
}

/// The observable mirror of `AppSettings` that drives first launch.
struct PreferencesTests {

    @Test func mirrorsTheStoredSettings() throws {
        try withSuite { settings in
            try settings.completeOnboarding(currencyCode: "MXN")
            let preferences = Preferences(settings: settings)
            #expect(preferences.hasCompletedOnboarding)
            #expect(preferences.activeCurrencyCode == "MXN")
        }
    }

    @Test func completingOnboardingUpdatesBothValuesAndTheStore() throws {
        try withSuite { settings in
            let preferences = Preferences(settings: settings)
            #expect(!preferences.hasCompletedOnboarding)
            try preferences.completeOnboarding(currencyCode: "eur")
            #expect(preferences.hasCompletedOnboarding)
            #expect(preferences.activeCurrencyCode == "EUR")
            #expect(settings.hasCompletedOnboarding)
        }
    }

    @Test func anInvalidCurrencyKeepsFirstLaunchOpen() {
        withSuite { settings in
            let preferences = Preferences(settings: settings)
            #expect(throws: MoneyError.self) {
                try preferences.completeOnboarding(currencyCode: "XYZ")
            }
            #expect(!preferences.hasCompletedOnboarding)
            #expect(preferences.activeCurrencyCode == nil)
        }
    }

    private func withSuite(_ body: (AppSettings) throws -> Void) rethrows {
        let suiteName = "GuldrTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create the defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(AppSettings(defaults: defaults))
    }
}

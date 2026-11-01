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

    @Test func homeLinkClosesAnySheetAndShowsHome() {
        let router = AppRouter()
        router.select(.analytics)
        router.present(.addTransaction)
        #expect(router.open(DeepLink.home.url))
        #expect(router.selectedTab == .home)
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

    @Test func changingTheCurrencyUpdatesTheStore() throws {
        try withSuite { settings in
            let preferences = Preferences(settings: settings)
            try preferences.completeOnboarding(currencyCode: "USD")
            try preferences.setActiveCurrency("EUR")
            #expect(preferences.activeCurrencyCode == "EUR")
            #expect(settings.activeCurrencyCode == "EUR")
            #expect(preferences.hasCompletedOnboarding)
        }
    }

    @Test func onboardingKeepsTheStartingBalanceAndDoesntOfferItAgain() throws {
        try withSuite { settings in
            let preferences = Preferences(settings: settings)
            #expect(!preferences.hasOfferedStartingBalance)
            try preferences.completeOnboarding(currencyCode: "MXN", startingBalance: 500_000)
            #expect(preferences.openingBalance(for: "MXN") == 500_000)
            #expect(preferences.hasOfferedStartingBalance)
            #expect(settings.openingBalance(for: "MXN") == 500_000)
        }
    }

    /// Users who finished onboarding before this version see Home's card until they save or close it.
    @Test func earlierUsersAreOfferedTheStartingBalanceUntilTheyAnswer() throws {
        try withSuite { settings in
            // Before this version, nothing recorded the offer.
            try settings.setActiveCurrency("USD")
            let saving = Preferences(settings: settings)
            #expect(!saving.hasOfferedStartingBalance)
            try saving.setOpeningBalance(-25_000, for: "USD")
            #expect(saving.hasOfferedStartingBalance)
            #expect(saving.openingBalance(for: "USD") == -25_000)

            settings.reset()
            let closing = Preferences(settings: settings)
            closing.dismissStartingBalanceOffer()
            #expect(closing.hasOfferedStartingBalance)
            #expect(closing.openingBalances.isEmpty)
        }
    }

    @Test func resettingReturnsToFirstLaunch() throws {
        try withSuite { settings in
            let preferences = Preferences(settings: settings)
            try preferences.completeOnboarding(currencyCode: "USD")
            try preferences.setOpeningBalance(9_900, for: "USD")
            preferences.reset()
            #expect(!preferences.hasCompletedOnboarding)
            #expect(preferences.activeCurrencyCode == nil)
            #expect(preferences.openingBalances.isEmpty)
            #expect(!preferences.hasOfferedStartingBalance)
            #expect(!settings.hasCompletedOnboarding)
            #expect(settings.activeCurrencyCode == nil)
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

struct AboutViewTests {

    @Test func versionShowsTheBuildNumber() {
        #expect(AboutView.versionText(infoDictionary: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "7"])
                == "1.0 (7)")
        #expect(AboutView.versionText(infoDictionary: ["CFBundleShortVersionString": "1.0"]) == "1.0")
        #expect(AboutView.versionText(infoDictionary: nil) == "—")
    }
}

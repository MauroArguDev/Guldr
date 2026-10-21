//
//  BudgetAlertCenterTests.swift
//  GuldrTests
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation
import GuldrCore
import SwiftData
import Testing
@testable import Guldr

// The app's aliases are internal to the app module; the test module needs its own (ARCHITECTURE.md › Data).
private typealias Category = GuldrCore.Category
private typealias Transaction = GuldrCore.Transaction
private typealias Budget = GuldrCore.Budget

/// Budget alerts end to end with a fake notification service: an in-memory store with the default
/// categories, US English, UTC and Oct 16, 2026.
struct BudgetAlertCenterTests {

    @Test func sendsEachThresholdOnceWithAmounts() async throws {
        try await withFixture(enabled: true) { fixture in
            try fixture.budget(40_000, "food")
            try fixture.spend(32_000, "food")
            await fixture.center.evaluate()
            await fixture.center.evaluate()

            #expect(fixture.service.delivered.count == 1)
            #expect(fixture.service.delivered.first?.title == "Food")
            #expect(fixture.service.delivered.first?.body
                    == "You've used 80% of your October budget: $320.00 of $400.00.")

            try fixture.spend(9_000, "food")
            await fixture.center.evaluate()
            #expect(fixture.service.delivered.last?.body == "You've reached your October budget: $410.00 of $400.00.")
            #expect(fixture.service.delivered.count == 2)
        }
    }

    @Test func theLockLeavesAmountsOut() async throws {
        try await withFixture(enabled: true) { fixture in
            fixture.settings.setLockEnabled(true)
            try fixture.budget(10_000, "food")
            try fixture.spend(10_000, "food")
            await fixture.center.evaluate()
            #expect(fixture.service.delivered.first?.body == "You've reached your October budget.")
        }
    }

    @Test func nothingIsSentWhileOffOrNotAllowed() async throws {
        try await withFixture(enabled: false) { fixture in
            try fixture.budget(10_000, "food")
            try fixture.spend(10_000, "food")
            await fixture.center.evaluate()
            #expect(fixture.service.delivered.isEmpty)
            // Nothing is recorded either, so turning alerts on later still sends it.
            #expect(fixture.settings.budgetAlertLedger.keys.isEmpty)
        }
        try await withFixture(enabled: true) { fixture in
            fixture.service.currentPermission = .denied
            try fixture.budget(10_000, "food")
            try fixture.spend(10_000, "food")
            await fixture.center.evaluate()
            #expect(fixture.service.delivered.isEmpty)
            #expect(!fixture.center.isOn)
        }
    }

    @Test func thePrePromptIsOfferedOnceWithBudgets() async throws {
        try await withFixture(enabled: false) { fixture in
            fixture.service.currentPermission = .notDetermined
            await fixture.center.offerIfNeeded()
            #expect(!fixture.center.isOfferingAlerts)

            try fixture.budget(10_000, "food")
            await fixture.center.offerIfNeeded()
            #expect(fixture.center.isOfferingAlerts)
            // The pre-prompt itself never asks iOS.
            #expect(fixture.service.requestCount == 0)

            fixture.center.isOfferingAlerts = false
            await fixture.center.offerIfNeeded()
            #expect(!fixture.center.isOfferingAlerts)
        }
    }

    @Test func notOfferedOnceIOSHasAnswered() async throws {
        try await withFixture(enabled: false) { fixture in
            fixture.service.currentPermission = .denied
            try fixture.budget(10_000, "food")
            await fixture.center.offerIfNeeded()
            #expect(!fixture.center.isOfferingAlerts)
        }
    }

    @Test func turningOnAsksIOSAndChecksTheMonth() async throws {
        try await withFixture(enabled: false) { fixture in
            fixture.service.currentPermission = .notDetermined
            try fixture.budget(10_000, "food")
            try fixture.spend(9_000, "food")

            await fixture.center.acceptOffer()
            #expect(fixture.service.requestCount == 1)
            #expect(fixture.center.isOn)
            #expect(fixture.settings.budgetAlertsEnabled)
            #expect(fixture.service.delivered.count == 1)
        }
    }

    @Test func aRefusalLeavesThemOff() async throws {
        try await withFixture(enabled: false) { fixture in
            fixture.service.currentPermission = .notDetermined
            fixture.service.grantsPermission = false
            #expect(!(await fixture.center.setEnabled(true)))
            #expect(!fixture.center.isOn)
            #expect(fixture.center.permission == .denied)
            #expect(!fixture.settings.budgetAlertsEnabled)
        }
    }

    @Test func turningOffKeepsThePermission() async throws {
        try await withFixture(enabled: true) { fixture in
            await fixture.center.refreshPermission()
            #expect(fixture.center.isOn)
            #expect(await fixture.center.setEnabled(false))
            #expect(!fixture.center.isOn)
            #expect(fixture.center.permission == .allowed)
        }
    }

    @Test func aResetClearsDeliveredAlerts() async throws {
        try await withFixture(enabled: true) { fixture in
            try fixture.budget(10_000, "food")
            try fixture.spend(10_000, "food")
            await fixture.center.evaluate()
            fixture.settings.reset()
            fixture.center.settingsDidReset()
            #expect(fixture.service.removedAll)
            #expect(!fixture.center.isEnabled)
        }
    }

    @Test func tappingAnAlertAsksForBudget() async throws {
        try await withFixture(enabled: true) { fixture in
            fixture.service.onOpen?()
            #expect(fixture.center.openRequests == 1)
        }
    }

    // MARK: - Helpers

    private func withFixture(enabled: Bool, _ body: (Fixture) async throws -> Void) async throws {
        let suiteName = "GuldrTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        try settings.completeOnboarding(currencyCode: "USD")
        settings.setBudgetAlertsEnabled(enabled)
        try await body(try Fixture(settings: settings))
    }
}

// MARK: - Fixture

private struct Fixture {

    let settings: AppSettings
    let service = FakeNotificationService()
    let container: ModelContainer
    let center: BudgetAlertCenter
    private let now: Date

    init(settings: AppSettings) throws {
        self.settings = settings
        container = try PersistenceController(mode: .inMemory).container
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-16T12:00:00Z"))
        self.now = now
        center = BudgetAlertCenter(container: container, settings: settings, service: service,
                                   locale: Locale(identifier: "en_US"), timeZone: TimeZone(identifier: "UTC")!,
                                   now: { now })
    }

    var context: ModelContext { container.mainContext }

    func category(_ systemKey: String) throws -> Category {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.systemKey == systemKey })
        return try #require(try context.fetch(descriptor).first)
    }

    func budget(_ cents: Int64, _ systemKey: String) throws {
        context.insert(Budget(month: YearMonth(year: 2026, month: 10)!,
                              limit: try Money(minorUnits: cents, currencyCode: "USD"),
                              category: try category(systemKey)))
        try context.save()
    }

    func spend(_ cents: Int64, _ systemKey: String) throws {
        context.insert(Transaction(amount: try Money(minorUnits: cents, currencyCode: "USD"), kind: .expense,
                                   date: now, category: try category(systemKey)))
        try context.save()
    }
}

//
//  AchievementCenterTests.swift
//  GuldrTests
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import GuldrCore
import SwiftData
import Testing
@testable import Guldr

/// Achievements for the app's screens, against an in-memory store, UTC and noon on Friday, Oct 16, 2026.
struct AchievementCenterTests {

    @Test func theHistoryIsRecordedWithoutMoments() throws {
        let fixture = try Fixture()
        try fixture.log(days: -9 ... 0)
        fixture.center.refresh()
        #expect(fixture.center.unlocks.isEmpty)
        #expect(fixture.settings.hasRecordedAchievementHistory)
        #expect(fixture.tier(.unbroken) == .bronze)
        #expect(try fixture.context.fetchCount(FetchDescriptor<EarnedAchievement>()) == 1)
    }

    @Test func aNewTierIsQueuedOnceAndShownInTurn() throws {
        let fixture = try Fixture()
        fixture.center.refresh()
        try fixture.log(days: -6 ... 0)
        fixture.center.refresh()
        fixture.center.refresh()
        #expect(fixture.center.unlocks.map(\.id) == [.unbroken])
        #expect(fixture.center.currentUnlock?.tier == .bronze)

        fixture.center.unlockDidEnd()
        #expect(fixture.center.currentUnlock == nil)
        fixture.center.unlockDidEnd()
        #expect(fixture.center.unlocks.isEmpty)
    }

    @Test func anEarnedTierStaysAfterItsDataGoes() throws {
        let fixture = try Fixture()
        try fixture.log(days: -6 ... 0)
        fixture.center.refresh()
        for day in try fixture.context.fetch(FetchDescriptor<LoggedDay>()) { fixture.context.delete(day) }
        try fixture.context.save()
        fixture.center.refresh()
        #expect(fixture.tier(.unbroken) == .bronze)
        #expect(fixture.center.earnedTierCount == 1)
        #expect(fixture.center.tierCount == 24)
    }

    @Test func nothingIsMeasuredBeforeFirstLaunch() throws {
        let fixture = try Fixture(onboarded: false)
        try fixture.log(days: -6 ... 0)
        fixture.center.refresh()
        #expect(!fixture.settings.hasRecordedAchievementHistory)
        #expect(fixture.tier(.unbroken) == nil)
    }

    @Test func aResetClearsTheQueueAndTheNextMedalGetsItsMoment() throws {
        let fixture = try Fixture()
        fixture.center.refresh()
        try fixture.log(days: -6 ... 0)
        fixture.center.refresh()
        #expect(!fixture.center.unlocks.isEmpty)

        try DataReset.eraseAll(in: fixture.context)
        fixture.settings.reset()
        try fixture.settings.completeOnboarding(currencyCode: "USD")
        fixture.center.settingsDidReset()
        #expect(fixture.center.unlocks.isEmpty)
        #expect(fixture.center.earnedTierCount == 0)

        try fixture.log(days: -6 ... 0)
        fixture.center.refresh()
        #expect(fixture.center.unlocks.map(\.id) == [.unbroken])
    }
}

// MARK: - Fixture

/// A class, so its defaults suite is removed when the test ends.
private final class Fixture {

    let container: ModelContainer
    let settings: AppSettings
    let center: AchievementCenter
    let timeZone = TimeZone(identifier: "UTC")!
    let now: Date
    private let suiteName = "GuldrTests.\(UUID().uuidString)"

    init(onboarded: Bool = true) throws {
        container = try PersistenceController(mode: .inMemory).container
        settings = AppSettings(defaults: try #require(UserDefaults(suiteName: suiteName)))
        if onboarded { try settings.completeOnboarding(currencyCode: "USD") }
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-16T12:00:00Z"))
        self.now = now
        center = AchievementCenter(container: container, settings: settings, timeZone: timeZone, now: { now })
    }

    deinit {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    var context: ModelContext { container.mainContext }

    func tier(_ id: AchievementID) -> AchievementTier? {
        center.progress.first { $0.id == id }?.tier
    }

    /// Logged days as offsets from today.
    func log(days offsets: ClosedRange<Int>) throws {
        let today = LocalDay(containing: now, timeZone: timeZone)
        for offset in offsets {
            context.insert(LoggedDay(day: today.adding(days: offset), source: .transaction))
        }
        try context.save()
    }
}

//
//  HabitPerformanceTests.swift
//  GuldrTests
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import GuldrCore
import SwiftData
import Testing
@testable import Guldr

// The app's aliases are internal to the app module; the test module needs its own (ARCHITECTURE.md › Data).
private typealias Category = GuldrCore.Category
private typealias Transaction = GuldrCore.Transaction

/// What runs after every save with a heavy history (v1 plan, 32.6): 5,000 transactions and two years of
/// logged days. Each refresh reads the whole store, so it must stay well inside a frame budget's worth of
/// work; the simulator is slower than a device.
struct HabitPerformanceTests {

    private static let budget = Duration.milliseconds(250)

    @Test func refreshesAfterASaveStayFast() throws {
        let container = try PersistenceController(mode: .inMemory).container
        let context = container.mainContext
        let food = try #require(try context.fetch(FetchDescriptor<Category>()).first { $0.systemKey == "food" })
        let start = Date.now.addingTimeInterval(-730 * 86_400)
        for index in 0..<5_000 {
            context.insert(Transaction(amount: try Money(minorUnits: Int64(100 + index % 900), currencyCode: "USD"),
                                       kind: index % 10 == 0 ? .income : .expense,
                                       date: start.addingTimeInterval(Double(index) * 12_600), category: food))
        }
        let today = LocalDay(containing: .now, timeZone: .autoupdatingCurrent)
        for offset in -730 ... 0 where !offset.isMultiple(of: 13) {
            context.insert(LoggedDay(day: today.adding(days: offset), source: .transaction))
        }
        try context.save()

        let suiteName = "GuldrTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        try settings.completeOnboarding(currencyCode: "USD")
        settings.setHasImportedStreakHistory()
        let streak = StreakCenter(container: container, settings: settings)
        let achievements = AchievementCenter(container: container, settings: settings)
        achievements.refresh()

        let clock = ContinuousClock()
        let streakTime = clock.measure { streak.refresh() }
        let achievementTime = clock.measure { achievements.refresh() }
        let recapTime = clock.measure {
            _ = RecapLibrary.availableMonths(in: context, currencyCode: "USD", now: .now, timeZone: .autoupdatingCurrent)
        }
        print("[performance] streak \(streakTime), achievements \(achievementTime), recap months \(recapTime)")
        #expect(streakTime < Self.budget)
        #expect(achievementTime < Self.budget)
        #expect(recapTime < Self.budget)
    }
}

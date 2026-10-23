//
//  AchievementCenter.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import GuldrCore
import Observation
import SwiftData

/// Achievements for the app's screens (ADR 013). After every save, on scene active and when the clock
/// moves to a new day (a month can end), it evaluates the store, stores the tiers newly reached and queues
/// them for their unlock moment. The first evaluation records the history silently.
@Observable
final class AchievementCenter {

    /// Every achievement with its value and the tier shown, in catalog order.
    private(set) var progress: [AchievementProgress] = []
    /// Tiers waiting for their moment, oldest first; `RootView` shows the first.
    private(set) var unlocks: [EarnedTier] = []

    init(container: ModelContainer, settings: AppSettings, timeZone: TimeZone = .autoupdatingCurrent,
         now: @escaping () -> Date = { .now }) {
        self.container = container
        self.settings = settings
        self.timeZone = timeZone
        self.now = now
        progress = AchievementEvaluator.progress(values: [:], earned: [])
    }

    /// The moment to show now, if any.
    var currentUnlock: EarnedTier? { unlocks.first }

    /// Medals earned out of every tier of the catalog, for the gallery's header.
    var earnedTierCount: Int { progress.reduce(0) { $0 + ($1.tier?.rawValue ?? 0) } }
    var tierCount: Int { AchievementCatalog.all.count * AchievementTier.allCases.count }

    func refresh() {
        // Before first launch picks a currency there's nothing to measure money in.
        guard let currencyCode = settings.activeCurrencyCode else { return }
        let context = container.mainContext
        let date = now()
        guard let values = try? EarnedAchievements.values(in: context, currencyCode: currencyCode, now: date,
                                                           timeZone: timeZone) else { return }
        if let new = try? EarnedAchievements.record(values, in: context, at: date) {
            if settings.hasRecordedAchievementHistory {
                unlocks.append(contentsOf: new)
            } else {
                // What the history already earned is kept without a moment for each (ADR 013).
                settings.setHasRecordedAchievementHistory()
            }
        }
        progress = AchievementEvaluator.progress(values: values,
                                                 earned: (try? EarnedAchievements.all(in: context)) ?? [])
    }

    func unlockDidEnd() {
        guard !unlocks.isEmpty else { return }
        unlocks.removeFirst()
    }

    /// After "Delete all data", which deleted the records and cleared the preferences.
    func settingsDidReset() {
        unlocks = []
        // An empty store has no history to record silently: the next medal gets its moment.
        settings.setHasRecordedAchievementHistory()
        progress = AchievementEvaluator.progress(values: [:], earned: [])
    }

    // MARK: - Private

    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let timeZone: TimeZone
    @ObservationIgnored private let now: () -> Date
}

#if DEBUG
extension AchievementCenter {
    /// Achievements over a throwaway defaults suite in US dollars, for previews.
    static func preview(container: ModelContainer) -> AchievementCenter {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "preview.\(UUID().uuidString)") ?? .standard)
        try? settings.completeOnboarding(currencyCode: "USD")
        let center = AchievementCenter(container: container, settings: settings)
        center.refresh()
        return center
    }
}
#endif

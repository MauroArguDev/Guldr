//
//  StreakCenter.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import GuldrCore
import Observation
import SwiftData

/// The logging streak for the app's screens (ADR 012). It reads the logged days from the store, marks
/// "No spending", and spots a milestone reached for the first time in the current run. The days
/// themselves are written where a transaction is saved, in the same save (`AddTransactionViewModel`).
@Observable
final class StreakCenter {

    enum StreakError: Error, Equatable {
        case saveFailed
    }

    private(set) var streak: LoggingStreak
    /// Settings › "Show streak". Hidden, the days are still recorded.
    private(set) var isShown: Bool
    /// A milestone reached and not celebrated yet in this run; `RootView` shows it once no sheet is up,
    /// then calls `celebrationDidEnd()`.
    private(set) var celebration: Int?

    init(container: ModelContainer, settings: AppSettings, timeZone: TimeZone = .autoupdatingCurrent,
         now: @escaping () -> Date = { .now }) {
        self.container = container
        self.settings = settings
        self.timeZone = timeZone
        self.now = now
        isShown = !settings.hidesStreak
        streak = LoggingStreak(loggedDays: [:], today: LocalDay(containing: now(), timeZone: timeZone))
    }

    /// When the app starts: imports the history once (people updating from 1.0 keep their streak), then
    /// reads the days.
    func start() {
        if !settings.hasImportedStreakHistory,
           (try? LoggedDays.importHistory(in: container.mainContext, timeZone: timeZone)) != nil {
            settings.setHasImportedStreakHistory()
        }
        refresh()
    }

    /// After every save, when the app comes to the front and at midnight.
    func refresh() {
        guard let streak = try? LoggedDays.streak(in: container.mainContext, now: now(), timeZone: timeZone) else {
            return
        }
        self.streak = streak
        celebrateIfNeeded()
    }

    var yesterday: LocalDay { streak.today.adding(days: -1) }

    /// "No spending" is offered for today and for yesterday while it's still open.
    func canMarkNoSpending(_ day: LocalDay) -> Bool {
        let state = streak.state(of: day)
        return (day == streak.today && state == .open) || (day == yesterday && state == .repairable)
    }

    /// Marks `day` and saves; does nothing for a day that can no longer be marked (an old notification).
    /// The caller tells `DataChangeNotifier`, which refreshes this center, the widget and the reminder.
    func markNoSpending(_ day: LocalDay) throws(StreakError) {
        let context = container.mainContext
        do {
            guard try LoggedDays.markNoSpending(day, now: now(), timeZone: timeZone, in: context) else { return }
            try context.save()
        } catch {
            context.rollback()
            throw .saveFailed
        }
        refresh()
    }

    func setShown(_ isShown: Bool) {
        settings.setHidesStreak(!isShown)
        self.isShown = isShown
        if !isShown { celebration = nil }
    }

    func celebrationDidEnd() {
        celebration = nil
    }

    /// After "Delete all data", which deleted the days and cleared the preferences.
    func settingsDidReset() {
        isShown = !settings.hidesStreak
        celebration = nil
        // Nothing to import into an empty store; this also stops a later launch from trying.
        settings.setHasImportedStreakHistory()
        refresh()
    }

    // MARK: - Private

    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let timeZone: TimeZone
    @ObservationIgnored private let now: () -> Date

    /// Each milestone once per run, remembered in `AppSettings`, so relaunching doesn't celebrate again
    /// and a new run can celebrate 7 days once more.
    private func celebrateIfNeeded() {
        guard isShown, let milestone = streak.reachedMilestone, let runStart = streak.runStart,
              settings.celebratedMilestone(inRunStartingOn: runStart) < milestone else { return }
        settings.setCelebratedMilestone(milestone, inRunStartingOn: runStart)
        celebration = milestone
    }
}

#if DEBUG
extension StreakCenter {
    /// A streak over a throwaway defaults suite, for previews: the container's logged days as they are.
    static func preview(container: ModelContainer) -> StreakCenter {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "preview.\(UUID().uuidString)") ?? .standard)
        let center = StreakCenter(container: container, settings: settings)
        center.refresh()
        return center
    }
}
#endif

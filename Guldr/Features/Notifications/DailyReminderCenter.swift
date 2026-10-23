//
//  DailyReminderCenter.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import GuldrCore
import Observation
import SwiftData

/// The daily reminder (v1 plan, Phase 28): one notification a day at the user's time, which opens the add
/// sheet. iOS can't skip a day of a repeating trigger, so it keeps the next week as one-off requests
/// (`ReminderSchedule`) and reschedules after every save, when the app comes to the front and when the
/// clock or the time zone changes; a day with a transaction dated that day loses its reminder. It owns
/// the "Daily reminder" preferences and its one-time pre-prompt (author's calls, 2026-10-23).
@Observable
final class DailyReminderCenter {

    /// The Settings toggle: on only while the preference is on and iOS allows notifications.
    var isOn: Bool { isEnabled && permission == .allowed }
    private(set) var isEnabled: Bool
    private(set) var time: ReminderTime
    private(set) var permission: NotificationPermission = .notDetermined
    /// Drives the pre-prompt alert in `RootView`.
    var isOfferingReminder = false

    init(container: ModelContainer, settings: AppSettings, service: any NotificationService,
         timeZone: TimeZone = .autoupdatingCurrent, now: @escaping () -> Date = { .now }) {
        self.container = container
        self.settings = settings
        self.service = service
        self.timeZone = timeZone
        self.now = now
        isEnabled = settings.dailyReminderEnabled
        time = settings.dailyReminderTime
    }

    func refreshPermission() async {
        permission = await service.permission()
    }

    // MARK: - Scheduling

    /// Brings the pending reminders up to date. Calls run one after another: a save and the app coming to
    /// the front can ask at the same moment, and an older answer must never land after a newer one (it
    /// could put back today's reminder right after a save removed it).
    func reschedule() async {
        let previous = rescheduling
        let task = Task {
            await previous?.value
            await updatePendingReminders()
        }
        rescheduling = task
        await task.value
    }

    /// The reminder's text: a calm question, with no amounts, so it reads the same with the lock on.
    static func content(for components: DateComponents) -> NotificationContent {
        NotificationContent(identifier: ReminderSchedule.identifier(for: components),
                            title: "Guldr",
                            body: String(localized: "Anything to log today? It takes a few seconds.",
                                         comment: "The daily reminder's notification."),
                            link: .add)
    }

    // MARK: - Settings

    /// The Settings toggle. Turning on asks iOS when it hasn't been asked; returns `false` when iOS
    /// doesn't allow notifications, so Settings can point to the Settings app.
    @discardableResult
    func setEnabled(_ isOn: Bool) async -> Bool {
        guard isOn else {
            settings.setDailyReminderEnabled(false)
            isEnabled = false
            await reschedule()
            return true
        }
        await refreshPermission()
        if permission == .notDetermined {
            _ = await service.requestPermission()
            await refreshPermission()
        }
        guard permission == .allowed else { return false }
        settings.setDailyReminderEnabled(true)
        isEnabled = true
        await reschedule()
        return true
    }

    func setTime(_ time: ReminderTime) async {
        settings.setDailyReminderTime(time)
        self.time = time
        await reschedule()
    }

    /// After "Delete all data", which clears the preferences: no reminder stays pending.
    func settingsDidReset() async {
        isEnabled = settings.dailyReminderEnabled
        time = settings.dailyReminderTime
        isOfferingReminder = false
        await reschedule()
    }

    // MARK: - Offer

    /// After a sheet closes: offers the reminder once, after the first transaction is saved (author's
    /// call, 2026-10-23). Not while iOS has notifications turned off, since "Turn on" couldn't help.
    func offerIfNeeded() async {
        guard !settings.hasOfferedDailyReminder, !isEnabled,
              let transactions = try? container.mainContext.fetchCount(FetchDescriptor<Transaction>()),
              transactions > 0 else { return }
        await refreshPermission()
        guard permission != .denied else { return }
        settings.setHasOfferedDailyReminder()
        isOfferingReminder = true
    }

    /// "Turn on" in the pre-prompt: iOS asks only if it hasn't been asked yet.
    func acceptOffer() async {
        await setEnabled(true)
    }

    // MARK: - Private

    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let service: any NotificationService
    @ObservationIgnored private let timeZone: TimeZone
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var rescheduling: Task<Void, Never>?

    private func updatePendingReminders() async {
        await refreshPermission()
        let pending = await service.pendingIdentifiers(withPrefix: ReminderSchedule.identifierPrefix)
        guard isOn else {
            service.removePending(pending)
            return
        }
        let date = now()
        let reminders = ReminderSchedule.upcoming(after: date, at: time, todayIsLogged: isLogged(on: date),
                                                  timeZone: timeZone)
        let wanted = Set(reminders.map(ReminderSchedule.identifier(for:)))
        service.removePending(pending.filter { !wanted.contains($0) })
        // Every wanted day is added again, replacing its request, so a new time or language reaches all.
        for components in reminders {
            await service.schedule(Self.content(for: components), at: components)
        }
    }

    /// Whether a transaction is dated on the day containing `date`, whenever it was added (author's call,
    /// 2026-10-23): backfilling older days doesn't count as logging today.
    private func isLogged(on date: Date) -> Bool {
        let today = ReminderSchedule.today(containing: date, timeZone: timeZone)
        let start = today.start
        let end = today.end
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.date >= start && $0.date < end })
        return ((try? container.mainContext.fetchCount(descriptor)) ?? 0) > 0
    }
}

#if DEBUG
extension DailyReminderCenter {
    /// A reminder over a throwaway defaults suite and a fake service, for previews.
    static func preview(container: ModelContainer) -> DailyReminderCenter {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "preview.\(UUID().uuidString)") ?? .standard)
        return DailyReminderCenter(container: container, settings: settings, service: FakeNotificationService())
    }
}
#endif

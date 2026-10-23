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
/// clock or the time zone changes; a logged day (ADR 012), or one with a transaction dated that day, loses
/// its reminder. The next reminder names the streak (Phase 29). It owns the "Daily reminder" preferences
/// and its one-time pre-prompt (author's calls, 2026-10-23).
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

    /// The reminder's text: a calm question, with no amounts, so it reads the same with the lock on. With
    /// the streak (only for the next reminder, since later days depend on what happens before them), it
    /// mentions an open day before the reminder's that a run depends on, or names the run from day 3.
    static func content(for components: DateComponents, streak: LoggingStreak? = nil) -> NotificationContent {
        let day = components.year.flatMap { year in
            components.month.flatMap { month in components.day.flatMap { LocalDay(year: year, month: month, day: $0) } }
        }
        return NotificationContent(identifier: ReminderSchedule.identifier(for: components), title: "Guldr",
                                   body: body(for: day, streak: streak), link: .add, day: day)
    }

    static func body(for day: LocalDay?, streak: LoggingStreak?) -> String {
        guard let day, let streak, streak.current > 0 else {
            return String(localized: "Anything to log today? It takes a few seconds.",
                          comment: "The daily reminder's notification.")
        }
        // Today's reminder depends on yesterday; tomorrow's on today, which will be yesterday by then.
        let dayBeforeIsOpen = day == streak.today ? streak.isYesterdayAtRisk
                                                  : day == streak.today.adding(days: 1) && !streak.isTodayLogged
        if dayBeforeIsOpen {
            return String(localized: "Yesterday is still open: log it or mark no spending to keep your \(streak.current)-day streak.",
                          comment: "The daily reminder while yesterday can still save the streak; the argument is its length.")
        }
        guard streak.current >= 3 else {
            return String(localized: "Anything to log today? It takes a few seconds.",
                          comment: "The daily reminder's notification.")
        }
        return String(localized: "Your streak is at \(streak.current) days. Anything to log today?",
                      comment: "The daily reminder from a 3-day streak on; the argument is its length.")
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
        let streak = settings.hidesStreak
            ? nil : try? LoggedDays.streak(in: container.mainContext, now: date, timeZone: timeZone)
        // Every wanted day is added again, replacing its request, so a new time, language or streak
        // reaches all.
        for (index, components) in reminders.enumerated() {
            await service.schedule(Self.content(for: components, streak: index == 0 ? streak : nil), at: components)
        }
    }

    /// Whether the day containing `date` is logged (ADR 012: a new transaction or "No spending"), or has a
    /// transaction dated on it, whenever it was added (author's call, 2026-10-23): backfilling older days
    /// doesn't count as logging today.
    private func isLogged(on date: Date) -> Bool {
        let context = container.mainContext
        let key = LocalDay(containing: date, timeZone: timeZone).rawValue
        let logged = FetchDescriptor<LoggedDay>(predicate: #Predicate { $0.dayKey == key })
        if ((try? context.fetchCount(logged)) ?? 0) > 0 { return true }
        let today = ReminderSchedule.today(containing: date, timeZone: timeZone)
        let start = today.start
        let end = today.end
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.date >= start && $0.date < end })
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
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

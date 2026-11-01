//
//  SummaryProvider.swift
//  GuldrWidget
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation
import GuldrCore
import SwiftData
import WidgetKit

/// One moment of the widgets: the summary, or the invitation to open the app, and whether amounts are
/// hidden. `nonisolated`, like the provider that builds it off the main actor.
nonisolated struct SummaryEntry: TimelineEntry {

    enum Content: Equatable {
        /// The app was never opened, or first launch isn't done: "Open Guldr to get started".
        case notStarted
        case summary(WidgetSummary)
    }

    /// The medium widget's streak line (ADR 012). It holds no amounts, so the lock doesn't hide it.
    nonisolated struct Streak: Equatable {
        let count: Int
        let isTodayLogged: Bool
    }

    let date: Date
    let content: Content
    /// Settings › Security › "Hide amounts in widgets", whether or not the lock is on (author's call,
    /// 2026-10-23).
    let hidesAmounts: Bool
    /// `nil` without a run, or while Settings › "Show streak" is off.
    var streak: Streak?
}

/// Builds the entry from the shared store, read-only, with the app's own calculations (ADR 007).
///
/// WidgetKit calls the provider off the main actor, so it opts out of the target's main-actor default;
/// everything it touches is created inside each call.
nonisolated struct SummaryProvider: TimelineProvider {

    func placeholder(in context: Context) -> SummaryEntry {
        SummaryEntry(date: .now, content: .summary(.sample), hidesAmounts: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (SummaryEntry) -> Void) {
        // The widget gallery shows the sample, not the user's numbers.
        completion(context.isPreview ? placeholder(in: context) : entry(at: .now))
    }

    /// One entry, refreshed by the app's `DataChangeNotifier` after every save and otherwise at the next
    /// midnight, when "Today" and the month can change.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SummaryEntry>) -> Void) {
        let now = Date.now
        completion(Timeline(entries: [entry(at: now)], policy: .after(Self.nextMidnight(after: now))))
    }

    func entry(at now: Date) -> SummaryEntry {
        let settings = WidgetStore.settings()
        let hidesAmounts = settings?.hidesWidgetAmounts ?? false
        guard case .ready(let container) = WidgetStore.open(),
              let settings, settings.hasCompletedOnboarding,
              let currencyCode = settings.activeCurrencyCode else {
            return SummaryEntry(date: now, content: .notStarted, hidesAmounts: hidesAmounts)
        }
        let context = ModelContext(container)
        let transactions = (try? context.fetch(FetchDescriptor<GuldrCore.Transaction>())) ?? []
        guard let summary = try? WidgetSummary(transactions: transactions, currencyCode: currencyCode,
                                               openingBalance: settings.openingBalance(for: currencyCode), now: now,
                                               categoryName: Self.name(of:)) else {
            return SummaryEntry(date: now, content: .notStarted, hidesAmounts: hidesAmounts)
        }
        return SummaryEntry(date: now, content: .summary(summary), hidesAmounts: hidesAmounts,
                            streak: settings.hidesStreak ? nil : Self.streak(in: context, at: now))
    }

    static func nextMidnight(after date: Date, calendar: Calendar = .autoupdatingCurrent) -> Date {
        let today = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: today) ?? date.addingTimeInterval(86_400)
    }

    /// The same days and rules as the app's chip; midnight's timeline refresh keeps "today" current.
    static func streak(in context: ModelContext, at now: Date) -> SummaryEntry.Streak? {
        guard let streak = try? LoggedDays.streak(in: context, now: now, timeZone: .autoupdatingCurrent),
              streak.current > 0 else { return nil }
        return SummaryEntry.Streak(count: streak.current, isTodayLogged: streak.isTodayLogged)
    }

    /// As the app's `Category.displayName`: seeded names are translated until the user renames them.
    static func name(of category: GuldrCore.Category?) -> String {
        guard let category else { return String(localized: "Uncategorized") }
        guard category.usesDefaultName else { return category.name }
        return String(localized: String.LocalizationValue(category.name))
    }
}

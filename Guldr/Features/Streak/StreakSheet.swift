//
//  StreakSheet.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import GuldrCore
import SwiftUI

/// The streak sheet (v1 plan, Phase 29), opened from Home's chip. From the top:
/// - the hero card: the current streak in serif, the best one and the freezes held;
/// - "No spending" for today, and for yesterday while it can still be repaired;
/// - the last five weeks, one circle per day;
/// - the next milestone and how a day counts.
///
/// Only design system tokens are used (DESIGN.md › Streak).
struct StreakSheet: View {

    @Environment(StreakCenter.self) private var center
    @Environment(\.dataChangeNotifier) private var notifier
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @State private var failedToSave = false
    /// Bumped on every mark, for the haptic.
    @State private var marks = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.stackDefault) {
                    hero
                    noSpendingActions
                    StreakCalendarCard(streak: center.streak)
                    footer
                    achievementsLink
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.stackDefault)
            }
            .background(Color(.sheetBackground))
            .navigationTitle(Text("Streak"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(Color(.gold))
                }
            }
        }
        .sensoryFeedback(Haptics.saved, trigger: marks)
        .alert("Couldn't save this day", isPresented: $failedToSave) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try again in a moment.")
        }
    }

    // MARK: - Sections

    private var hero: some View {
        let streak = center.streak
        return VStack(alignment: .leading, spacing: 12) {
            Text("Current streak")
                .textRole(.overline)
                .foregroundStyle(Color(.textSecondary))
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) { countAndUnit }
                VStack(alignment: .leading, spacing: 2) { countAndUnit }
            }
            .accessibilityElement(children: .combine)
            Text(status)
                .textRole(.meta)
                .foregroundStyle(streak.isTodayLogged ? Color(.gold) : Color(.textSecondary))
            Divider().overlay(Color(.hairline))
            bestAndFreezes
                .textRole(.meta)
                .foregroundStyle(Color(.textSecondary))
        }
        .padding(Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(.hero)
        .motion(.standard, value: streak.current)
    }

    /// The count in serif and "days in a row", side by side or stacked, whichever fits.
    @ViewBuilder
    private var countAndUnit: some View {
        let streak = center.streak
        Text(streak.current, format: .number)
            .displayFont(.balance)
            .foregroundStyle(Color(.textPrimary))
            .contentTransition(.numericText(value: Double(streak.current)))
        // English and Spanish both use the singular for 1 only, the two languages Guldr ships.
        Text(streak.current == 1 ? "day in a row" : "days in a row")
            .textRole(.rowTitle)
            .foregroundStyle(Color(.textSecondary))
    }

    /// The best streak and the freezes, side by side, or stacked at accessibility text sizes (32.3).
    private var bestAndFreezes: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout())
        return layout {
            Label {
                Text("Best: \(center.streak.best) days")
            } icon: {
                Image(systemName: "trophy")
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            freezes
        }
    }

    /// Two snowflakes, filled for each freeze held.
    private var freezes: some View {
        let held = center.streak.freezesHeld
        return HStack(spacing: 4) {
            ForEach(0..<LoggingStreak.maxFreezes, id: \.self) { index in
                Image(systemName: index < held ? "snowflake.circle.fill" : "snowflake.circle")
                    .foregroundStyle(index < held ? Color(.gold) : Color(.textSecondary))
            }
            Text("\(held) freezes")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(held) freezes"))
    }

    @ViewBuilder
    private var noSpendingActions: some View {
        let today = center.streak.today
        let canMarkToday = center.canMarkNoSpending(today)
        let canMarkYesterday = center.canMarkNoSpending(center.yesterday)
        if canMarkToday || canMarkYesterday {
            VStack(spacing: 4) {
                if canMarkToday {
                    Button("No spending today") { mark(today) }
                        .buttonStyle(.primary)
                }
                if canMarkYesterday {
                    Button("No spending yesterday") { mark(center.yesterday) }
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Color(.gold))
                        .frame(minHeight: Size.touchTargetMin)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let next = center.streak.nextMilestone {
                Text("Next milestone: \(next) days.")
                    .textRole(.rowTitle)
                    .foregroundStyle(Color(.textPrimary))
            }
            // The String Catalog key is this one literal, so it can't be split across lines.
            // swiftlint:disable:next line_length
            Text("A day counts when you log something dated that day, or mark it as no spending, by the end of the next day. Every 7 days in a row earn a freeze, up to 2, which covers a missed day.")
                .textRole(.meta)
                .foregroundStyle(Color(.textSecondary))
        }
    }

    /// The gallery, at the bottom of the sheet (author's call, 2026-10-23).
    private var achievementsLink: some View {
        NavigationLink {
            AchievementsView()
        } label: {
            HStack {
                Label("Achievements", systemImage: "medal")
                    .textRole(.rowTitle)
                    .foregroundStyle(Color(.textPrimary))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.textSecondary))
            }
            .padding(Spacing.cardPaddingCompact)
            .frame(minHeight: Size.touchTargetMin)
            .card(.compact)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var status: LocalizedStringKey {
        let streak = center.streak
        if streak.isTodayLogged { return "Today is logged." }
        if streak.isYesterdayAtRisk { return "Yesterday is still open: log it or mark no spending." }
        return "Today is still open."
    }

    private func mark(_ day: LocalDay) {
        do {
            try center.markNoSpending(day)
            marks += 1
            notifier.dataDidChange()
        } catch {
            failedToSave = true
        }
    }
}

/// The last five weeks, one circle per day, weeks starting on the locale's first weekday:
/// - logged: `GoldFill`;
/// - no spending: `GoldSoft` ringed in `GoldFill`;
/// - freeze: a snowflake on `Track`;
/// - missed: `Track`;
/// - yesterday still open: a dashed `GoldFill` ring;
/// - today still open: a `GoldFill` ring.
private struct StreakCalendarCard: View {

    let streak: LoggingStreak

    @Environment(\.calendar) private var calendar

    var body: some View {
        let weeks = StreakCalendar.weeks(endingWith: streak.today, firstWeekday: calendar.firstWeekday)
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 5 weeks")
                .textRole(.cardTitle)
                .foregroundStyle(Color(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    // By position: two weekdays can share a letter.
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(verbatim: symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(.textSecondary))
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                    }
                }
                ForEach(weeks, id: \.self) { week in
                    GridRow {
                        ForEach(week, id: \.self) { day in
                            DayCell(day: day, state: day > streak.today ? nil : streak.state(of: day),
                                    isToday: day == streak.today)
                        }
                    }
                }
            }
            // Seven columns of day circles don't fit an iPhone SE past this size; VoiceOver reads each
            // day's date and state, so the calendar caps its text instead of breaking the grid (32.3).
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .padding(Spacing.cardPaddingCompact)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(.standard)
    }

    /// "S M T W T F S" from the locale, rotated to start on its first weekday.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = (calendar.firstWeekday - 1) % symbols.count
        return Array(symbols[shift...] + symbols[..<shift])
    }
}

private struct DayCell: View {

    let day: LocalDay
    /// `nil` for a day after today.
    let state: LoggingStreak.DayState?
    let isToday: Bool

    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .caption) private var side: CGFloat = 32

    var body: some View {
        ZStack {
            background
            if state == .frozen {
                Image(systemName: "snowflake")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.textSecondary))
            } else if state != nil {
                Text(day.day, format: .number)
                    .font(.caption.weight(isToday ? .bold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(numberColor)
            }
        }
        // At most `side`, but never wider than its column: on an iPhone SE seven circles share ~260 pt.
        .frame(maxWidth: side, maxHeight: side)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: dateText))
        .accessibilityValue(stateText)
        .accessibilityHidden(state == nil)
    }

    @ViewBuilder
    private var background: some View {
        switch state {
        case .logged:
            Circle().fill(Color(.goldFill))
        case .noSpending:
            Circle().fill(Color(.goldSoft)).overlay { Circle().strokeBorder(Color(.goldFill), lineWidth: 1.5) }
        case .frozen, .missed:
            Circle().fill(Color(.track))
        case .repairable:
            Circle().strokeBorder(Color(.goldFill), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
        case .open:
            Circle().strokeBorder(Color(.goldFill), lineWidth: 1.5)
        case .outside, nil:
            Color.clear
        }
    }

    private var numberColor: Color {
        switch state {
        case .logged: Color(.onGold)
        case .noSpending: Color(.gold)
        case .open, .repairable: Color(.textPrimary)
        default: Color(.textSecondary)
        }
    }

    private var dateText: String {
        day.dateInterval(in: .autoupdatingCurrent).start
            .formatted(Date.FormatStyle(locale: locale).month(.wide).day())
    }

    private var stateText: Text {
        switch state {
        case .logged: Text("Logged")
        case .noSpending: Text("No spending")
        case .frozen: Text("Covered by a freeze")
        case .missed: Text("Not logged")
        case .repairable: Text("Still open")
        case .open: Text("Today, still open")
        case .outside, nil: Text(verbatim: "")
        }
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    PreviewEnvironment { StreakSheet() }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewEnvironment { StreakSheet() }
        .preferredColorScheme(.dark)
}
#endif

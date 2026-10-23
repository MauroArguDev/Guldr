//
//  StreakChip.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import GuldrCore
import SwiftUI

/// Home's streak chip, beside the month (author's call, 2026-10-23): a flame and the count in a capsule.
/// Once today is logged the flame fills and the capsule turns `GoldSoft` with `Gold` text; while today is
/// still open it's an outlined flame on `Field`. A tap opens the streak sheet.
struct StreakChip: View {

    let streak: LoggingStreak
    let action: () -> Void

    var body: some View {
        let isLogged = streak.isTodayLogged
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isLogged ? "flame.fill" : "flame")
                    .symbolEffect(.bounce, options: .nonRepeating, value: isLogged)
                Text(streak.current, format: .number)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(streak.current)))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isLogged ? Color(.gold) : Color(.textSecondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isLogged ? Color(.goldSoft) : Color(.field), in: Capsule())
            .frame(minHeight: Size.touchTargetMin)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .motion(.standard, value: streak.current)
        .motion(.snappy, value: isLogged)
        .accessibilityLabel(Text("Streak, \(streak.current) days"))
        .accessibilityValue(isLogged ? Text("Today is logged") : Text("Today is still open"))
        .accessibilityHint(Text("Opens your streak"))
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
private struct StreakChipSpecimen: View {

    private let today = LocalDay(containing: .now, timeZone: .autoupdatingCurrent)

    var body: some View {
        HStack(spacing: 12) {
            StreakChip(streak: streak(through: 0)) {}
            StreakChip(streak: streak(through: -1)) {}
            StreakChip(streak: LoggingStreak(loggedDays: [:], today: today)) {}
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.appBackground))
    }

    /// Twelve days in a row ending on `last` (0 is today).
    private func streak(through last: Int) -> LoggingStreak {
        let days = (last - 11 ... last).map { (today.adding(days: $0), LoggedDaySource.transaction) }
        return LoggingStreak(loggedDays: Dictionary(uniqueKeysWithValues: days), today: today)
    }
}

#Preview("Light") {
    StreakChipSpecimen().preferredColorScheme(.light)
}

#Preview("Dark") {
    StreakChipSpecimen().preferredColorScheme(.dark)
}
#endif

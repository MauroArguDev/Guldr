//
//  AchievementsView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import GuldrCore
import SwiftUI

/// The achievements gallery (v1 plan, Phase 30), pushed from the streak sheet and from Settings
/// (author's call, 2026-10-23):
/// - a header card with the medals earned out of all of them;
/// - one section per family;
/// - one row per achievement: its medal, name and summary, then the tier and when it was earned, or the
///   progress toward the next tier. Nothing is hidden behind a "?".
struct AchievementsView: View {

    @Environment(AchievementCenter.self) private var center

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.stackDefault) {
                header
                ForEach(AchievementFamily.allCases, id: \.self) { family in
                    section(family)
                }
                Text("Money achievements only count complete months, so every medal stands for data you can trust.")
                    .textRole(.meta)
                    .foregroundStyle(Color(.textSecondary))
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.bottom, Spacing.stackDefault)
        }
        .background(Color(.appBackground))
        .navigationTitle(Text("Achievements"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { center.refresh() }
    }

    private var header: some View {
        HStack(spacing: Spacing.rowGap) {
            if let best = center.progress.max(by: { ($0.tier?.rawValue ?? 0) < ($1.tier?.rawValue ?? 0) }) {
                AchievementMedal(achievement: best.achievement, tier: best.tier, side: 56)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(center.earnedTierCount) of \(center.tierCount) medals")
                    .textRole(.rowTitle)
                    .foregroundStyle(Color(.textPrimary))
                ProgressBar(value: Double(center.earnedTierCount) / Double(center.tierCount))
            }
        }
        .padding(Spacing.cardPaddingCompact)
        .card(.hero)
        .accessibilityElement(children: .combine)
    }

    private func section(_ family: AchievementFamily) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(family.title)
                .textRole(.sectionTitle)
                .foregroundStyle(Color(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                let rows = center.progress.filter { $0.achievement.family == family }
                ForEach(rows) { progress in
                    AchievementRow(progress: progress)
                    if progress.id != rows.last?.id {
                        Divider().overlay(Color(.hairline)).padding(.leading, 52 + Spacing.rowGap)
                    }
                }
            }
            .padding(.horizontal, Spacing.cardPaddingCompact)
            .card(.standard)
        }
    }
}

private struct AchievementRow: View {

    let progress: AchievementProgress

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.rowGap) {
            AchievementMedal(achievement: progress.achievement, tier: progress.tier)
            VStack(alignment: .leading, spacing: 4) {
                Text(progress.id.title)
                    .textRole(.rowTitle)
                    .foregroundStyle(Color(.textPrimary))
                Text(progress.id.summary)
                    .textRole(.meta)
                    .foregroundStyle(Color(.textSecondary))
                status
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, Spacing.summaryRowVertical)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var status: some View {
        HStack(spacing: 8) {
            if let tier = progress.tier {
                Text(tier.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.gold))
                if let earnedAt = progress.earnedAt {
                    Text(earnedAt, format: .dateTime.month(.abbreviated).year().locale(locale))
                        .font(.caption)
                        .foregroundStyle(Color(.textSecondary))
                }
            }
            Spacer(minLength: 0)
            Text(verbatim: progress.amountText(locale: locale))
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Color(.textSecondary))
        }
        if progress.nextTier != nil {
            ProgressBar(value: progress.fractionToNext, height: .compact)
        }
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    PreviewEnvironment {
        NavigationStack { AchievementsView() }
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewEnvironment {
        NavigationStack { AchievementsView() }
    }
    .preferredColorScheme(.dark)
}
#endif

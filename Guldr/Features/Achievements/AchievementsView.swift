//
//  AchievementsView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import GuldrCore
import SwiftData
import SwiftUI

/// The achievements gallery (v1 plan, Phase 30), pushed from the streak sheet and from Settings
/// (author's call, 2026-10-23):
/// - a header card with the medals earned out of all of them;
/// - one section per family;
/// - one row per achievement: its medal, name and summary, then the tier and when it was earned, or the
///   progress toward the next tier. Nothing is hidden behind a "?".
struct AchievementsView: View {

    @Environment(AchievementCenter.self) private var center
    @Environment(Preferences.self) private var preferences
    @Environment(\.modelContext) private var context
    @State private var sharing: SharedItem?
    @State private var recapMonths: [YearMonth] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.stackDefault) {
                header
                ForEach(AchievementFamily.allCases, id: \.self) { family in
                    section(family)
                }
                if !recapMonths.isEmpty {
                    recaps
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
        .onAppear {
            center.refresh()
            if let currencyCode = preferences.activeCurrencyCode {
                recapMonths = RecapLibrary.availableMonths(in: context, currencyCode: currencyCode, now: .now,
                                                           timeZone: .autoupdatingCurrent)
            }
        }
        .sheet(item: $sharing) { item in
            switch item {
            case .achievement(let id):
                if let progress = center.progress.first(where: { $0.id == id }), let tier = progress.tier {
                    ShareCardSheet(content: .achievement(progress.achievement, tier))
                }
            case .recap(let month):
                RecapSheet(month: month)
            }
        }
    }

    /// What the gallery shares, by identifier, so the sheet reads the current data.
    private enum SharedItem: Identifiable, Hashable {
        case achievement(AchievementID)
        case recap(YearMonth)

        var id: Self { self }
    }

    /// Past months in review, newest first (v1 plan, Phase 31).
    private var recaps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly recaps")
                .textRole(.sectionTitle)
                .foregroundStyle(Color(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(recapMonths, id: \.self) { month in
                    Button {
                        sharing = .recap(month)
                    } label: {
                        HStack {
                            Text(verbatim: month.title())
                                .textRole(.rowTitle)
                                .foregroundStyle(Color(.textPrimary))
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(Color(.gold))
                        }
                        .frame(minHeight: Size.touchTargetMin)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Opens the recap to share it"))
                    if month != recapMonths.last {
                        Divider().overlay(Color(.hairline))
                    }
                }
            }
            .padding(.horizontal, Spacing.cardPaddingCompact)
            .padding(.vertical, 4)
            .card(.standard)
        }
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
                    AchievementRow(progress: progress) {
                        sharing = .achievement(progress.id)
                    }
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
    /// Shares the tier earned; only offered once there is one.
    let onShare: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            // A full 44 pt target in its own column; on the title's line it was clipped to 20 pt (32.2).
            if progress.tier != nil {
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color(.gold))
                        .frame(width: Size.touchTargetMin, height: Size.touchTargetMin)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Share"))
            }
        }
        .padding(.vertical, Spacing.summaryRowVertical)
        .accessibilityElement(children: .combine)
        .accessibilityActions {
            if progress.tier != nil {
                Button("Share", action: onShare)
            }
        }
    }

    /// Side by side, or stacked at accessibility text sizes so nothing is cut (32.3).
    private var statusLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(spacing: 8))
    }

    @ViewBuilder
    private var status: some View {
        statusLayout {
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

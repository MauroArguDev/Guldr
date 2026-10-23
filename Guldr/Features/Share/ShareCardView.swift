//
//  ShareCardView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import GuldrCore
import SwiftUI

/// The image itself (v1 plan, Phase 31), in the design system: `AppBackground`, the wordmark, the content,
/// the centered ledger lines and "Your gold, in order." (author's call, 2026-10-23). Laid out at a fixed
/// size and Dynamic Type, so every render looks the same.
struct ShareCardView: View {

    let content: ShareCardContent
    let format: ShareCardFormat

    var body: some View {
        VStack(spacing: 0) {
            Wordmark(size: format == .story ? .large : .header)
                .padding(.top, format == .story ? 56 : 24)
            Spacer(minLength: 12)
            switch content {
            case .achievement(let achievement, let tier):
                achievementBody(achievement, tier)
            case .recap(let card):
                recapBody(card)
            }
            Spacer(minLength: 12)
            LedgerLines(variant: .centered)
                .frame(width: 120)
            Text("Your gold, in order.")
                .font(.footnote)
                .foregroundStyle(Color(.textSecondary))
                .padding(.top, 10)
                .padding(.bottom, format == .story ? 48 : 20)
        }
        .padding(.horizontal, 28)
        .frame(width: format.points.width, height: format.points.height)
        .background(Color(.appBackground))
        .dynamicTypeSize(.large)
    }

    private func achievementBody(_ achievement: Achievement, _ tier: AchievementTier) -> some View {
        VStack(spacing: format == .story ? 20 : 12) {
            AchievementMedal(achievement: achievement, tier: tier, side: format == .story ? 150 : 104)
            Text(tier.title)
                .textRole(.overline)
                .foregroundStyle(Color(.gold))
            Text(achievement.id.title)
                .font(.system(size: format == .story ? 34 : 26, design: .serif))
                .foregroundStyle(Color(.textPrimary))
                .multilineTextAlignment(.center)
            Text(achievement.id.summary)
                .font(.callout)
                .foregroundStyle(Color(.textSecondary))
                .multilineTextAlignment(.center)
        }
    }

    private func recapBody(_ card: RecapCard) -> some View {
        let rows = format == .story ? card.rows : Array(card.rows.prefix(3))
        return VStack(spacing: format == .story ? 18 : 10) {
            Text(verbatim: card.monthTitle)
                .textRole(.overline)
                .foregroundStyle(Color(.gold))
            Text("My month in Guldr")
                .font(.system(size: format == .story ? 32 : 24, design: .serif))
                .foregroundStyle(Color(.textPrimary))
            if card.recap.isComplete {
                Label("Complete month", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.gold))
            }
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    HStack {
                        Text(row.label)
                            .foregroundStyle(Color(.textSecondary))
                        Spacer(minLength: 12)
                        Text(verbatim: row.value)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(Color(.textPrimary))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .font(.callout)
                    .padding(.vertical, format == .story ? 10 : 6)
                    if row.id != rows.last?.id {
                        Divider().overlay(Color(.hairline))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .card(.standard)
            if format == .story, !card.recap.achievementsEarned.isEmpty {
                HStack(spacing: 10) {
                    ForEach(card.recap.achievementsEarned.prefix(5), id: \.id) { tier in
                        AchievementMedal(achievement: AchievementCatalog.achievement(tier.id), tier: tier.tier, side: 40)
                    }
                }
            }
        }
    }
}

/// Renders a card to an image at 3×, in the given appearance and language.
enum ShareCardRenderer {

    static func image(for content: ShareCardContent, format: ShareCardFormat, colorScheme: ColorScheme,
                      locale: Locale) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(content: content, format: format)
            .environment(\.colorScheme, colorScheme)
            .environment(\.locale, locale))
        renderer.scale = ShareCardFormat.scale
        return renderer.uiImage
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Achievement") {
    ShareCardView(content: .achievement(AchievementCatalog.achievement(.saver), .gold), format: .story)
}

#Preview("Achievement, dark square") {
    ShareCardView(content: .achievement(AchievementCatalog.achievement(.unbroken), .silver), format: .square)
        .preferredColorScheme(.dark)
}
#endif

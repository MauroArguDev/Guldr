//
//  AchievementMedal.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import GuldrCore
import SwiftUI

/// A medal (ADR 013): a coin in its tier's color (`TierBronze`, `TierSilver`, `GoldFill`) with a thin inner
/// ring and the achievement's symbol in `OnGold`. Before bronze, the same coin on `Track` with the symbol
/// in `TextSecondary`. Decorative: the row or card beside it names the achievement and its tier.
struct AchievementMedal: View {

    let achievement: Achievement
    let tier: AchievementTier?
    var side: CGFloat = 52

    var body: some View {
        ZStack {
            Circle().fill(fill)
            Circle()
                .inset(by: side * 0.08)
                .strokeBorder(tier == nil ? Color(.hairline) : Color(.onGold).opacity(0.2), lineWidth: 1)
            Image(systemName: achievement.symbol)
                .font(.system(size: side * 0.38, weight: .semibold))
                .foregroundStyle(tier == nil ? Color(.textSecondary) : Color(.onGold))
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }

    private var fill: Color {
        switch tier {
        case .gold: Color(.goldFill)
        case .silver: Color(.tierSilver)
        case .bronze: Color(.tierBronze)
        case nil: Color(.track)
        }
    }
}

extension MomentBanner where Icon == AchievementMedal {

    /// An achievement unlocked (Phase 30): "Saver · Gold", what it measures, and its medal.
    init(unlock: EarnedTier, onEnd: @escaping () -> Void) {
        let achievement = AchievementCatalog.achievement(unlock.id)
        self.init(title: "\(unlock.id.title) · \(unlock.tier.title)", subtitle: unlock.id.summary,
                  icon: { AchievementMedal(achievement: achievement, tier: unlock.tier, side: Size.iconChip) },
                  onEnd: onEnd)
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
private struct MedalSpecimen: View {

    var body: some View {
        VStack(spacing: 16) {
            ForEach(AchievementCatalog.all) { achievement in
                HStack(spacing: 16) {
                    ForEach([nil] + AchievementTier.allCases.map(Optional.some), id: \.self) { tier in
                        AchievementMedal(achievement: achievement, tier: tier, side: 40)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.appBackground))
    }
}

#Preview("Light") {
    MedalSpecimen().preferredColorScheme(.light)
}

#Preview("Dark") {
    MedalSpecimen().preferredColorScheme(.dark)
}
#endif

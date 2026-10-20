//
//  BudgetOverviewCard.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 20/10/26.
//

import GuldrCore
import SwiftUI

/// The Budget mockup's hero card: the ring with what is still available, then the month's spent and
/// total limit and "71% used · 2 days left". Takes display values, so previews need no store.
struct BudgetOverviewCard: View {

    let overview: BudgetModel.Overview

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Side by side as in the mockup; the figures go under the ring at accessibility sizes, where
        // they no longer fit beside it.
        layout {
            BudgetRing(remaining: overview.remaining, usage: overview.usage)
            VStack(alignment: .leading, spacing: 12) {
                figure("Spent", overview.spent)
                figure("Total limit", overview.limit)
                Text(verbatim: overview.detail)
                    .textRole(.meta)
                    .fontWeight(.semibold)
                    .foregroundStyle(overview.usage > 1 ? Color(.negative) : Color(.gold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.cardPadding)
        .frame(maxWidth: .infinity)
        .card(.hero)
    }

    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
            : AnyLayout(HStackLayout(spacing: 20))
    }

    private func figure(_ title: LocalizedStringKey, _ amount: Money) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .textRole(.meta)
                .foregroundStyle(Color(.textSecondary))
            AmountText(amount, sign: .never, style: .summary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .combine)
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
private struct BudgetOverviewCardSpecimen: View {
    var body: some View {
        VStack(spacing: Spacing.stackDefault) {
            // The Budget mockup.
            BudgetOverviewCard(overview: .init(remaining: .previewUSD(58_700), spent: .previewUSD(144_300),
                                               limit: .previewUSD(203_000), usage: 0.71,
                                               detail: "71% used · 2 days left"))
            // Over the month's total.
            BudgetOverviewCard(overview: .init(remaining: .previewUSD(0), spent: .previewUSD(219_240),
                                               limit: .previewUSD(203_000), usage: 1.08, detail: "108% used"))
        }
        .padding(Spacing.screenHorizontal)
        .background(Color(.appBackground))
    }
}

#Preview("Light") {
    BudgetOverviewCardSpecimen().preferredColorScheme(.light)
}

#Preview("Dark") {
    BudgetOverviewCardSpecimen().preferredColorScheme(.dark)
}
#endif

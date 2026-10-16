//
//  BalanceCard.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 16/10/26.
//

import GuldrCore
import SwiftUI

/// The Dashboard's hero card (DESIGN.md › BalanceCard): the all-time balance in serif, the ledger lines,
/// the month's income and expenses, and the savings rate. Takes display values, so previews and the
/// gallery can show it without a store.
struct BalanceCard: View {

    let balance: Money
    let income: Money
    let expenses: Money
    /// 0…1, or `nil` when the month has no income, where a rate means nothing: shown as "—".
    let savingsRate: Double?
    /// Draws the ledger lines in. The Dashboard passes true only on its first appearance per launch.
    var drawsLedgerLines = false

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.stackDefault) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Total balance")
                    .textRole(.meta)
                    .foregroundStyle(Color(.textSecondary))
                AmountText(balance, style: .hero)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .accessibilityElement(children: .combine)

            LedgerLines(variant: .leading, drawsIn: drawsLedgerLines)

            HStack(alignment: .top, spacing: 12) {
                summary("Monthly income", symbol: "arrow.up", tint: Color(.positive), amount: income)
                summary("Monthly expenses", symbol: "arrow.down", tint: Color(.negative), amount: expenses)
            }

            savings
        }
        .padding(Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(.hero)
    }

    private func summary(_ title: LocalizedStringKey, symbol: String, tint: Color, amount: Money) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
            }
            .labelStyle(.titleAndIcon)
            .textRole(.meta)
            .foregroundStyle(Color(.textSecondary))
            AmountText(amount, sign: .never, style: .summary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var savings: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Savings rate")
                    .foregroundStyle(Color(.textSecondary))
                Spacer(minLength: 8)
                Text(verbatim: savingsText)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(savingsRate == nil ? Color(.textSecondary) : Color(.gold))
                    .contentTransition(.numericText())
                    .motion(.standard, value: savingsText)
            }
            .textRole(.meta)
            ProgressBar(value: savingsRate ?? 0)
                .accessibilityHidden(true)
        }
        .padding(.top, 14)
        .overlay(alignment: .top) {
            Rectangle().fill(Color(.hairline)).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    /// "64.8%", or "—" when there was no income this month.
    private var savingsText: String {
        guard let savingsRate else { return "—" }
        return savingsRate.formatted(.percent.precision(.fractionLength(1)).locale(locale))
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
private struct BalanceCardSpecimen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.stackDefault) {
                // The Dashboard mockup.
                BalanceCard(balance: .previewUSD(1_248_025), income: .previewUSD(500_000),
                            expenses: .previewUSD(175_950), savingsRate: 0.648, drawsLedgerLines: true)
                // No income this month, and a negative balance.
                BalanceCard(balance: .previewUSD(-4_280), income: .previewUSD(0),
                            expenses: .previewUSD(4_280), savingsRate: nil)
            }
            .padding(Spacing.screenHorizontal)
        }
        .background(Color(.appBackground))
    }
}

#Preview("Light") {
    BalanceCardSpecimen().preferredColorScheme(.light)
}

#Preview("Dark") {
    BalanceCardSpecimen().preferredColorScheme(.dark)
}
#endif

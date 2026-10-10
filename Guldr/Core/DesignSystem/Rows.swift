//
//  Rows.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftUI

/// A transaction in a list: icon chip, title and meta, trailing amount (DESIGN.md › TransactionRow).
/// Takes display values, not the model, so the Dashboard, the list and previews share it.
struct TransactionRow: View {

    let title: String
    /// Already composed by the screen, e.g. "Food · Today" or "Food · 9:41".
    let meta: String
    let symbol: String
    let amount: Money
    let kind: TransactionKind
    /// `.regular` (42) on the Dashboard, `.compact` (40) in the Transactions list.
    var chipSize: IconChip.Size = .regular

    var body: some View {
        HStack(spacing: Spacing.rowGap) {
            IconChip(symbol: symbol, size: chipSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).textRole(.rowTitle).foregroundStyle(Color(.textPrimary)).lineLimit(1)
                Text(meta).textRole(.meta).foregroundStyle(Color(.textSecondary)).lineLimit(1)
            }
            Spacer(minLength: 8)
            AmountText(amount, kind: kind)
        }
        .padding(.vertical, Spacing.rowVertical)
        .accessibilityElement(children: .combine)
    }
}

/// The Dashboard's budget summary: mini ring, title, "spent of limit" detail, chevron
/// (DESIGN.md › BudgetSummaryRow). The screen wraps it in a `NavigationLink` and a compact card.
struct BudgetSummaryRow: View {

    let title: String
    /// e.g. "$1,443.00 of $2,030.00 · 1 category over budget".
    let detail: String
    let usage: Double

    var body: some View {
        HStack(spacing: 14) {
            MiniRing(value: usage, tone: usage > 1 ? .over : .standard)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).textRole(.cardTitle).foregroundStyle(Color(.textPrimary))
                Text(detail).textRole(.meta).monospacedDigit().foregroundStyle(Color(.textSecondary))
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.textSecondary))
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One category on the Budget screen: chip, name, "spent of limit" and a 5 pt bar that turns
/// `Negative` when over (DESIGN.md › CategoryBudgetRow).
struct CategoryBudgetRow: View {

    let name: String
    let symbol: String
    /// From `BudgetStatus`: spent, limit, usage and whether it is over.
    let line: BudgetStatus.Line

    @Environment(\.locale) private var locale

    var body: some View {
        let formatter = MoneyFormatter(locale: locale)
        let spentText = Text(formatter.string(from: line.spent))
            .fontWeight(.semibold)
            .foregroundStyle(line.isOver ? Color(.negative) : Color(.textPrimary))
        HStack(spacing: Spacing.rowGap) {
            IconChip(symbol: symbol, size: .budget)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(name).textRole(.cardTitle).foregroundStyle(Color(.textPrimary))
                    Spacer(minLength: 8)
                    Text("\(spentText) of \(formatter.string(from: line.limit))")
                        .textRole(.meta).monospacedDigit().foregroundStyle(Color(.textSecondary))
                }
                ProgressBar(value: line.usage, height: .compact, tone: line.isOver ? .over : .standard)
            }
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

private struct RowsSpecimen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.stackDefault) {
                VStack(spacing: 0) {
                    TransactionRow(title: "Groceries", meta: "Food · Today", symbol: "fork.knife",
                                   amount: .previewUSD(4_280), kind: .expense)
                    TransactionRow(title: "Salary", meta: "Salary · Sep 25", symbol: "briefcase",
                                   amount: .previewUSD(500_000), kind: .income)
                    TransactionRow(title: "Streaming subscription", meta: "Entertainment", symbol: "play",
                                   amount: .previewUSD(1_599), kind: .expense, chipSize: .compact)
                }
                BudgetSummaryRow(title: "September budget",
                                 detail: "$1,443.00 of $2,030.00 · 1 category over budget", usage: 0.71)
                    .padding(.vertical, 16).padding(.horizontal, Spacing.cardPaddingCompact)
                    .card(.compact)
                VStack(spacing: 2) {
                    CategoryBudgetRow(name: "Entertainment", symbol: "play", line: .preview(9_600, of: 8_000))
                    CategoryBudgetRow(name: "Food", symbol: "fork.knife", line: .preview(31_200, of: 40_000))
                    CategoryBudgetRow(name: "Health", symbol: "heart", line: .preview(4_000, of: 15_000))
                }
            }
            .padding(Spacing.screenHorizontal)
        }
        .background(Color(.appBackground))
    }
}

#Preview("Light") {
    RowsSpecimen().preferredColorScheme(.light)
}

#Preview("Dark") {
    RowsSpecimen().preferredColorScheme(.dark)
}

#Preview("Largest Dynamic Type") {
    RowsSpecimen().dynamicTypeSize(.accessibility3)
}

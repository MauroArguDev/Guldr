//
//  SummaryWidgetView.swift
//  GuldrWidget
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import GuldrCore
import SwiftUI
import WidgetKit

/// Picks the family's layout, or the invitation to open the app before its first launch.
struct SummaryWidgetView: View {

    let entry: SummaryEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch entry.content {
            case .notStarted:
                NotStartedView()
            case .summary(let summary):
                if family == .systemMedium {
                    MediumSummaryView(summary: summary, hidesAmounts: entry.hidesAmounts)
                } else {
                    SmallSummaryView(summary: summary, hidesAmounts: entry.hidesAmounts)
                }
            }
        }
        // A tap anywhere opens Home (author's call, 2026-10-21); the medium widget's + opens the add
        // sheet instead. With the lock on, the app asks first.
        .widgetURL(DeepLink.home.url)
    }
}

/// Small (Widgets mockup): "Balance" and the glyph, then the balance in serif 28 (whole units), the
/// two ledger lines and the month's expenses ("Sep: −$1,759.50"). Without transactions, an invitation
/// takes the expenses' place.
struct SmallSummaryView: View {

    let summary: WidgetSummary
    let hidesAmounts: Bool

    var body: some View {
        let formatter = MoneyFormatter()
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader()
            Spacer(minLength: 8)
            VStack(alignment: .leading, spacing: 8) {
                WidgetAmount(text: formatter.string(from: summary.balance, precision: .wholeUnits),
                             hidesAmounts: hidesAmounts)
                    .font(.system(size: 28, design: .serif))
                    .foregroundStyle(Color(.textPrimary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                WidgetLedgerLines()
                if summary.isEmpty {
                    Text("Add your first transaction")
                        .font(.caption)
                        .foregroundStyle(Color(.textSecondary))
                        .lineLimit(2)
                } else {
                    HStack(spacing: 0) {
                        Text(verbatim: summary.monthLabel + ": ")
                        WidgetAmount(text: formatter.string(from: summary.monthExpenses, sign: .minus),
                                     hidesAmounts: hidesAmounts)
                    }
                    .font(.caption)
                    .foregroundStyle(Color(.textSecondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Medium (Widgets mockup): on the left the glyph and "Balance" (with a + to add), the balance in serif
/// 26 and the month's income and expenses; a hairline; on the right the three newest transactions.
struct MediumSummaryView: View {

    let summary: WidgetSummary
    let hidesAmounts: Bool

    var body: some View {
        HStack(spacing: 14) {
            leftColumn
                .frame(width: 128, alignment: .leading)
            Rectangle()
                .fill(Color(.hairline))
                .frame(width: 1)
            rightColumn
        }
    }

    private var leftColumn: some View {
        let formatter = MoneyFormatter()
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                WidgetHeader(glyphSize: 16, glyphLeading: true)
                Spacer(minLength: 4)
                AddButton()
            }
            Spacer(minLength: 6)
            WidgetAmount(text: formatter.string(from: summary.balance, precision: .wholeUnits),
                         hidesAmounts: hidesAmounts)
                .font(.system(size: 26, design: .serif))
                .foregroundStyle(Color(.textPrimary))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Spacer(minLength: 6)
            VStack(alignment: .leading, spacing: 3) {
                monthLine("arrow.up", formatter.string(from: summary.monthIncome, sign: .never), Color(.positive))
                monthLine("arrow.down", formatter.string(from: summary.monthExpenses, sign: .never), Color(.negative))
            }
            .font(.caption)
        }
    }

    private func monthLine(_ symbol: String, _ amount: String, _ tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.caption2.weight(.semibold))
                .accessibilityHidden(true)
            WidgetAmount(text: amount, hidesAmounts: hidesAmounts)
        }
        .foregroundStyle(tint)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    @ViewBuilder
    private var rightColumn: some View {
        if summary.isEmpty {
            Text("Add your first transaction")
                .font(.footnote)
                .foregroundStyle(Color(.textSecondary))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(summary.recent.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { Spacer(minLength: 4) }
                    recentRow(row)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// "Groceries" over "Today", and the amount: income `Positive` with "+", expenses `TextPrimary`
    /// with "−", as Recent in the app.
    private func recentRow(_ row: WidgetSummary.Recent) -> some View {
        let isIncome = row.kind == .income
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: row.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.textPrimary))
                Text(verbatim: row.meta)
                    .font(.caption2)
                    .foregroundStyle(Color(.textSecondary))
            }
            .lineLimit(1)
            Spacer(minLength: 4)
            WidgetAmount(text: MoneyFormatter().string(from: row.amount, sign: isIncome ? .plus : .minus),
                         hidesAmounts: hidesAmounts)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isIncome ? Color(.positive) : Color(.textPrimary))
                .lineLimit(1)
        }
    }
}

/// The medium widget's shortcut to the add sheet: a 24 pt `GoldFill` circle with a + in `OnGold`.
private struct AddButton: View {

    var body: some View {
        Link(destination: DeepLink.add.url) {
            Image(systemName: "plus")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(.onGold))
                .frame(width: 24, height: 24)
                .background(Color(.goldFill), in: Circle())
                .widgetAccentable()
        }
        .accessibilityLabel(Text("Add transaction"))
    }
}

/// Before the app's first launch: the glyph and "Open Guldr to get started".
struct NotStartedView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GlyphMark().frame(width: 28, height: 28)
            Spacer(minLength: 0)
            Text("Open Guldr to get started")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.textPrimary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

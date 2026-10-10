//
//  AmountText.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftUI

/// A money amount styled per DESIGN.md: a true minus sign, income in `Positive` with "+", expenses in
/// `TextPrimary`, tabular digits that roll to a new value. VoiceOver reads it as one amount.
struct AmountText: View {

    enum Style {
        /// Transaction rows: 16 pt semibold.
        case row
        /// Income and expense summaries: 19 pt semibold.
        case summary
        /// The balance: New York 46 pt with the cents at 26 pt in `TextSecondary`. Always full precision.
        case hero
        /// A New York display size, cents not split (budget ring, widgets, add sheet).
        case display(DisplaySize)
    }

    enum Tone {
        case primary
        /// Income.
        case positive
        /// Over budget.
        case negative

        var color: Color {
            switch self {
            case .primary: Color(.textPrimary)
            case .positive: Color(.positive)
            case .negative: Color(.negative)
            }
        }
    }

    let money: Money
    var sign: MoneyFormatter.SignDisplay = .automatic
    var style: Style = .row
    var tone: Tone = .primary
    /// `.wholeUnits` for large summary figures (ring center, chart totals, widgets), as in the mockups.
    var precision: MoneyFormatter.Precision = .full

    @Environment(\.locale) private var locale

    /// A transaction's amount: "+" and `Positive` for income, "−" for expenses.
    init(_ money: Money, kind: TransactionKind, style: Style = .row) {
        self.money = money
        self.sign = kind == .income ? .plus : .minus
        self.style = style
        self.tone = kind == .income ? .positive : .primary
    }

    init(_ money: Money, sign: MoneyFormatter.SignDisplay = .automatic, style: Style = .row, tone: Tone = .primary,
         precision: MoneyFormatter.Precision = .full) {
        self.money = money
        self.sign = sign
        self.style = style
        self.tone = tone
        self.precision = precision
    }

    var body: some View {
        let formatter = MoneyFormatter(locale: locale)
        content(formatter)
            .foregroundStyle(tone.color)
            .contentTransition(.numericText(value: Double(money.minorUnits)))
            .motion(.standard, value: money)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(formatter.string(from: money, sign: sign, precision: precision))
    }

    @ViewBuilder
    private func content(_ formatter: MoneyFormatter) -> some View {
        switch style {
        case .row:
            Text(formatter.string(from: money, sign: sign, precision: precision)).textRole(.rowAmount)
        case .summary:
            Text(formatter.string(from: money, sign: sign, precision: precision)).textRole(.summaryValue)
        case .display(let size):
            Text(formatter.string(from: money, sign: sign, precision: precision)).displayFont(size)
        case .hero:
            let parts = formatter.parts(from: money, sign: sign)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(parts.main).displayFont(.balance)
                if let fraction = parts.fraction {
                    Text(fraction).displayFont(.balanceCents).foregroundStyle(Color(.textSecondary))
                }
            }
        }
    }
}

// MARK: - Previews

private struct AmountTextSpecimen: View {

    @State private var balance: Int64 = 1_817_550

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            AmountText(Money.previewUSD(balance), style: .hero)
            AmountText(Money.previewUSD(500_000), kind: .income)
            AmountText(Money.previewUSD(4_280), kind: .expense)
            AmountText(Money.previewUSD(175_950), style: .summary)
            AmountText(Money.previewUSD(58_700), style: .display(.budgetRingCenter), precision: .wholeUnits)
            AmountText(Money.previewUSD(9_600), style: .summary, tone: .negative)
            AmountText(Money.previewUSD(4_280), kind: .expense).environment(\.locale, Locale(identifier: "es_ES"))
            Button("Add $42.80") { balance += 4_280 }
        }
        .padding(Spacing.screenHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(.appBackground))
    }
}

#Preview("Light") {
    AmountTextSpecimen().preferredColorScheme(.light)
}

#Preview("Dark") {
    AmountTextSpecimen().preferredColorScheme(.dark)
}

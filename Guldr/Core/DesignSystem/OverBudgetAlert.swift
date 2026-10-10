//
//  OverBudgetAlert.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftUI

/// "**Entertainment** went over its limit by $16.00" on `NegativeSoft`, radius 18
/// (DESIGN.md › OverBudgetAlert). The warning symbol pulses once when the alert appears.
///
/// The warning haptic is not here: it belongs to the save that pushed the budget over
/// (DESIGN.md › Motion › Haptics), not to every visit to the Budget screen.
struct OverBudgetAlert: View {

    let categoryName: String
    let overAmount: Money

    @State private var appeared = false
    @ScaledMetric(relativeTo: .subheadline) private var textSize: CGFloat = 14
    @Environment(\.locale) private var locale
    @ReduceMotion private var reduceMotion

    var body: some View {
        let amount = MoneyFormatter(locale: locale).string(from: overAmount)
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: Size.iconGlyph))
                .foregroundStyle(Color(.negative))
                .symbolEffect(.pulse, options: .nonRepeating, value: appeared)
                .symbolEffectsRemoved(reduceMotion)
                .accessibilityHidden(true)
            Text("\(Text(categoryName).fontWeight(.semibold)) went over its limit by \(amount)")
                .font(.system(size: textSize))
                .foregroundStyle(Color(.textPrimary))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color(.negativeSoft), in: RoundedRectangle(cornerRadius: Radius.alert, style: .continuous))
        .accessibilityElement(children: .combine)
        .onAppear { appeared = true }
    }
}

#Preview("Light and dark") {
    VStack(spacing: 16) {
        OverBudgetAlert(categoryName: "Entertainment", overAmount: .previewUSD(1_600))
            .environment(\.colorScheme, .light)
        OverBudgetAlert(categoryName: "Entertainment", overAmount: .previewUSD(1_600))
            .environment(\.colorScheme, .dark)
    }
    .padding()
    .background(Color(.appBackground))
}

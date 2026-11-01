//
//  AmountEntryLine.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 1/11/26.
//

import GuldrCore
import SwiftUI

/// The add sheet's typed amount (DESIGN.md › Add sheet): New York 58 in a 72 pt row with the blinking
/// `GoldFill` caret, in `TextSecondary` while empty. The starting balance screens use it with the same
/// keypad (ADR 016).
struct AmountEntryLine: View {

    let amount: AmountInput

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 4) {
            Text(verbatim: amount.formattedText(locale: locale))
                .displayFont(.addAmount)
                .foregroundStyle(amount.isEmpty ? Color(.textSecondary) : Color(.textPrimary))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText())
                .motion(.snappy, value: amount)
            RoundedRectangle(cornerRadius: Size.amountCaret.width / 2)
                .fill(Color(.goldFill))
                .frame(width: Size.amountCaret.width, height: Size.amountCaret.height)
                .caretBlink(isActive: true, restart: amount)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: Size.amountRow)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Amount"))
        .accessibilityValue(Text(verbatim: amount.formattedText(locale: locale)))
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    VStack {
        AmountEntryLine(amount: .preview())
        AmountEntryLine(amount: .preview(1_250_000))
    }
    .padding()
    .background(Color(.appBackground))
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    VStack {
        AmountEntryLine(amount: .preview(0, "MXN"))
        AmountEntryLine(amount: .preview(1_250_000, "MXN"))
    }
    .padding()
    .background(Color(.appBackground))
    .preferredColorScheme(.dark)
}
#endif

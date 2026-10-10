//
//  BudgetRing.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftUI

/// The Budget screen's ring: 168 pt, stroke 12, starting at 12 o'clock, with what is left in serif
/// 30 pt and "available" under it (DESIGN.md › BudgetRing). Remaining is shown in whole units.
struct BudgetRing: View {

    let remaining: Money
    let usage: Double

    var body: some View {
        ZStack {
            RingShape(value: usage, lineWidth: Size.budgetRingStroke, tone: usage > 1 ? .over : .standard)
            VStack(spacing: 2) {
                AmountText(remaining, sign: .never, style: .display(.budgetRingCenter), precision: .wholeUnits)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("available").font(.caption).foregroundStyle(Color(.textSecondary))
            }
            .padding(Size.budgetRingStroke + 8)
        }
        .frame(width: Size.budgetRing, height: Size.budgetRing)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Light and dark") {
    VStack(spacing: 24) {
        BudgetRing(remaining: .previewUSD(58_700), usage: 0.71)
            .padding(20).card(.hero).environment(\.colorScheme, .light)
        BudgetRing(remaining: .previewUSD(0), usage: 1.08)
            .padding(20).card(.hero).environment(\.colorScheme, .dark)
    }
    .padding()
    .background(Color(.appBackground))
}

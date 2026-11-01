//
//  StartingBalanceHomeCard.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 1/11/26.
//

import SwiftUI

/// Home's one-time card for users who finished onboarding before the starting balance existed (ADR 016;
/// DESIGN.md › Starting balance), built like the recap card. A tap opens Adjust balance; the × hides it
/// for good, and Settings keeps the row.
struct StartingBalanceHomeCard: View {

    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: Spacing.rowGap) {
            Button(action: onOpen) {
                HStack(spacing: Spacing.rowGap) {
                    Image(systemName: "banknote")
                        .font(.system(size: Size.iconGlyph))
                        .foregroundStyle(Color(.gold))
                        .frame(width: Size.iconChip, height: Size.iconChip)
                        .background(Color(.goldSoft),
                                    in: RoundedRectangle(cornerRadius: Radius.iconChipLarge, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Set your balance")
                            .textRole(.rowTitle)
                            .foregroundStyle(Color(.textPrimary))
                        Text("Tell Guldr what you have today so Home matches your accounts.")
                            .textRole(.meta)
                            .foregroundStyle(Color(.textSecondary))
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.textSecondary))
                    .frame(width: Size.touchTargetMin, height: Size.touchTargetMin)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Don't show again"))
        }
        .padding(.leading, Spacing.cardPaddingCompact)
        .padding(.vertical, 8)
        .card(.compact)
    }
}

#Preview("Light") {
    StartingBalanceHomeCard(onOpen: {}, onClose: {})
        .padding()
        .background(Color(.appBackground))
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    StartingBalanceHomeCard(onOpen: {}, onClose: {})
        .padding()
        .background(Color(.appBackground))
        .preferredColorScheme(.dark)
}

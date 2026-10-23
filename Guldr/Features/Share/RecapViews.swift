//
//  RecapViews.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import GuldrCore
import SwiftData
import SwiftUI

/// A month's recap, ready to share: the share sheet with the recap card, built from the store when it opens.
struct RecapSheet: View {

    let month: YearMonth

    @Environment(\.modelContext) private var context
    @Environment(Preferences.self) private var preferences
    @Environment(\.locale) private var locale

    var body: some View {
        if let currencyCode = preferences.activeCurrencyCode {
            ShareCardSheet(content: .recap(RecapLibrary.card(for: month, in: context, currencyCode: currencyCode,
                                                             locale: locale, timeZone: .autoupdatingCurrent)))
        }
    }
}

/// Home's recap card (author's call, 2026-10-23): "Your October in Guldr" during the first days of
/// November, with a close button that hides it until next month. A tap opens the recap.
struct RecapHomeCard: View {

    let month: YearMonth
    let onOpen: () -> Void
    let onClose: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: Spacing.rowGap) {
            Button(action: onOpen) {
                HStack(spacing: Spacing.rowGap) {
                    Image(systemName: "sparkles")
                        .font(.system(size: Size.iconGlyph))
                        .foregroundStyle(Color(.gold))
                        .frame(width: Size.iconChip, height: Size.iconChip)
                        .background(Color(.goldSoft),
                                    in: RoundedRectangle(cornerRadius: Radius.iconChipLarge, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your \(monthName) in Guldr")
                            .textRole(.rowTitle)
                            .foregroundStyle(Color(.textPrimary))
                        Text("See your month and share it.")
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
            .accessibilityLabel(Text("Hide until next month"))
        }
        .padding(.leading, Spacing.cardPaddingCompact)
        .padding(.vertical, 8)
        .card(.compact)
    }

    /// "October", mid-sentence: lowercase in Spanish.
    private var monthName: String {
        var style = Date.FormatStyle(locale: locale).month(.wide)
        style.capitalizationContext = .middleOfSentence
        return month.dateInterval().start.formatted(style)
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    RecapHomeCard(month: YearMonth(year: 2026, month: 9)!, onOpen: {}, onClose: {})
        .padding()
        .background(Color(.appBackground))
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    RecapHomeCard(month: YearMonth(year: 2026, month: 9)!, onOpen: {}, onClose: {})
        .padding()
        .background(Color(.appBackground))
        .preferredColorScheme(.dark)
}
#endif

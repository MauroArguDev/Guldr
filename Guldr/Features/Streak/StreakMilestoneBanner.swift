//
//  StreakMilestoneBanner.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import GuldrCore
import SwiftUI

/// The milestone moment (v1 plan, Phase 29): a card that drops in from the top once the sheet that
/// logged the day is gone, with the `emphasized` spring and the success haptic, then leaves after a few
/// seconds or on a tap. It never blocks the app: only the card itself takes touches. With Reduce Motion it
/// fades instead of dropping in.
struct StreakMilestoneBanner: View {

    let milestone: Int
    let onEnd: () -> Void

    @ReduceMotion private var reduceMotion
    @State private var isShown = false

    var body: some View {
        ZStack(alignment: .top) {
            if isShown {
                card
                    .motionTransition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .motion(.emphasized, value: isShown)
        .sensoryFeedback(Haptics.saved, trigger: isShown) { _, shown in shown }
        .task {
            // Lets the closing sheet and its own haptic finish first.
            try? await Task.sleep(for: .milliseconds(400))
            isShown = true
            AccessibilityNotification.Announcement(announcement).post()
            try? await Task.sleep(for: .seconds(Self.duration))
            await dismiss()
        }
    }

    /// Long enough to read two short lines.
    private static let duration = 3.5

    private var card: some View {
        Button {
            Task { await dismiss() }
        } label: {
            HStack(spacing: Spacing.rowGap) {
                Image(systemName: "flame.fill")
                    .font(.system(size: Size.iconGlyph))
                    .foregroundStyle(Color(.gold))
                    .frame(width: Size.iconChip, height: Size.iconChip)
                    .background(Color(.goldSoft),
                                in: RoundedRectangle(cornerRadius: Radius.iconChipLarge, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .textRole(.rowTitle)
                        .foregroundStyle(Color(.textPrimary))
                    Text(subtitle)
                        .textRole(.meta)
                        .foregroundStyle(Color(.textSecondary))
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.cardPaddingCompact)
            .card(.standard)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Dismisses this message"))
    }

    private var title: LocalizedStringResource {
        "\(milestone) days in a row"
    }

    private var subtitle: LocalizedStringResource {
        if let next = LoggingStreak.milestones.first(where: { $0 > milestone }) {
            return "Next milestone: \(next) days."
        }
        return "Every milestone reached. Keep it going."
    }

    private var announcement: String {
        String(localized: title) + ". " + String(localized: subtitle)
    }

    private func dismiss() async {
        guard isShown else { return }
        isShown = false
        // Leaves time for the card to slide out before the parent removes it.
        try? await Task.sleep(for: .milliseconds(450))
        onEnd()
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    Color(.appBackground)
        .ignoresSafeArea()
        .overlay(alignment: .top) { StreakMilestoneBanner(milestone: 7) {} }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    Color(.appBackground)
        .ignoresSafeArea()
        .overlay(alignment: .top) { StreakMilestoneBanner(milestone: 365) {} }
        .preferredColorScheme(.dark)
}
#endif

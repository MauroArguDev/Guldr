//
//  MomentBanner.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import GuldrCore
import SwiftUI

/// A brief moment of success: a streak milestone (Phase 29) or an achievement unlocked (Phase 30). A card
/// drops in from the top once the sheet that caused it is gone, with the `emphasized` spring and the
/// success haptic, then leaves after a few seconds or on a tap. It never blocks the app: only the card
/// itself takes touches. With Reduce Motion it fades instead of dropping in.
struct MomentBanner<Icon: View>: View {

    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    @ViewBuilder let icon: () -> Icon
    let onEnd: () -> Void

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
            AccessibilityNotification.Announcement(String(localized: title) + ". " + String(localized: subtitle)).post()
            try? await Task.sleep(for: .seconds(Self.duration))
            await dismiss()
        }
    }

    /// Long enough to read two short lines.
    private static var duration: Double { 3.5 }

    private var card: some View {
        Button {
            Task { await dismiss() }
        } label: {
            HStack(spacing: Spacing.rowGap) {
                icon()
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

    private func dismiss() async {
        guard isShown else { return }
        isShown = false
        // Leaves time for the card to slide out before the parent removes it.
        try? await Task.sleep(for: .milliseconds(450))
        onEnd()
    }
}

extension MomentBanner where Icon == StreakFlameIcon {

    /// A streak milestone (Phase 29): "7 days in a row", then the next one.
    init(milestone: Int, onEnd: @escaping () -> Void) {
        let subtitle: LocalizedStringResource = if let next = LoggingStreak.milestones.first(where: { $0 > milestone }) {
            "Next milestone: \(next) days."
        } else {
            "Every milestone reached. Keep it going."
        }
        self.init(title: "\(milestone) days in a row", subtitle: subtitle, icon: { StreakFlameIcon() }, onEnd: onEnd)
    }
}

/// The streak milestone's icon: a `Gold` flame on a 42 pt `GoldSoft` square.
struct StreakFlameIcon: View {

    var body: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: Size.iconGlyph))
            .foregroundStyle(Color(.gold))
            .frame(width: Size.iconChip, height: Size.iconChip)
            .background(Color(.goldSoft), in: RoundedRectangle(cornerRadius: Radius.iconChipLarge, style: .continuous))
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    Color(.appBackground)
        .ignoresSafeArea()
        .overlay(alignment: .top) { MomentBanner(milestone: 7) {} }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    Color(.appBackground)
        .ignoresSafeArea()
        .overlay(alignment: .top) { MomentBanner(milestone: 365) {} }
        .preferredColorScheme(.dark)
}
#endif

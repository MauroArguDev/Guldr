//
//  LockView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import GuldrCore
import SwiftUI

/// The Lock mockup: the app's tile, the wordmark (40 pt) and "Your finances, just for you." in the
/// upper part; the centered ledger lines, the biometry glyph, "Unlock with Face ID" and "Use iPhone
/// passcode" at the bottom. The prompt opens on its own (`AppLock.sceneDidBecomeActive`); the buttons
/// are for trying again after a cancel. Wording follows the device: Touch ID on an iPhone SE.
struct LockView: View {

    @Environment(AppLock.self) private var lock

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                AppTile()
                Wordmark(size: .large)
                Text("Your finances, just for you.")
                    .font(.callout)
                    .foregroundStyle(Color(.textSecondary))
                    .multilineTextAlignment(.center)
            }
            Spacer()
            VStack(spacing: 22) {
                LedgerLines(variant: .centered)
                Image(systemName: biometrySymbol)
                    .font(.system(size: 56, weight: .ultraLight))
                    .foregroundStyle(Color(.textPrimary))
                    .accessibilityHidden(true)
                VStack(spacing: 0) {
                    Button(action: unlock) {
                        Text(unlockTitle)
                    }
                    .buttonStyle(.primary)
                    if lock.availability.biometry != .none {
                        Button(action: unlock) {
                            Text("Use iPhone passcode")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(Color(.gold))
                                .frame(minHeight: Size.touchTargetMin)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 22)
                    }
                }
                .disabled(lock.isAuthenticating)
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, Spacing.stackDefault)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.appBackground))
        .sensoryFeedback(Haptics.unlockFailed, trigger: lock.failureCount)
        .onAppear { lock.refreshAvailability() }
    }

    private var unlockTitle: LocalizedStringKey {
        switch lock.availability.biometry {
        case .faceID: "Unlock with Face ID"
        case .touchID: "Unlock with Touch ID"
        case .opticID: "Unlock with Optic ID"
        case .none: "Unlock with passcode"
        }
    }

    private var biometrySymbol: String {
        switch lock.availability.biometry {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        case .none: "lock"
        }
    }

    /// Both buttons run `.deviceOwnerAuthentication`: iOS has no passcode-only policy, and it offers the
    /// passcode once Face ID fails or is unavailable (ADR 011).
    private func unlock() {
        Task { await lock.unlock() }
    }
}

extension Biometry {

    /// The lock's name in Settings.
    var lockTitle: LocalizedStringKey {
        switch self {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        case .none: "Passcode lock"
        }
    }

    /// The welcome screen's opt-in.
    var optInTitle: LocalizedStringKey {
        switch self {
        case .faceID: "Lock with Face ID"
        case .touchID: "Lock with Touch ID"
        case .opticID: "Lock with Optic ID"
        case .none: "Lock with passcode"
        }
    }
}

/// The app icon as the mockup draws it: an 84 pt tile on `Surface` with a `Hairline` border and the
/// glyph in `Gold`. The radius is the icon grid's (228 of 1024) at this size.
private struct AppTile: View {

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 84 * 228 / 1024, style: .continuous)
        Image(.launchGlyph)
            .resizable()
            .scaledToFit()
            // The glyph's ring spans 584 of the icon's 1024 units (DESIGN.md › Launch screen).
            .frame(width: 84 * 584 / 1024, height: 84 * 584 / 1024)
            .frame(width: 84, height: 84)
            .background(Color(.surface), in: shape)
            .overlay { shape.strokeBorder(Color(.hairline), lineWidth: 1) }
            .accessibilityHidden(true)
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    LockView()
        .environment(AppLock.preview(locked: true))
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    LockView()
        .environment(AppLock.preview(locked: true))
        .preferredColorScheme(.dark)
}

#Preview("Touch ID") {
    LockView()
        .environment(AppLock.preview(locked: true, biometry: .touchID))
}
#endif

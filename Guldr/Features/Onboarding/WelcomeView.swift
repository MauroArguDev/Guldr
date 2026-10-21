//
//  WelcomeView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftUI

/// First launch: the wordmark, the tagline and the currency, preset from the device's region (ADR 005).
/// Laid out like the Lock mockup, the other full-screen brand moment. Categories are already seeded when
/// the store opens. Under the currency, an opt-in to the Face ID lock, off by default (author's call,
/// 2026-10-21); turning it on asks for Face ID right there (ADR 011). Hidden on a device without a passcode.
struct WelcomeView: View {

    @Environment(Preferences.self) private var preferences
    @Environment(AppLock.self) private var lock
    @State private var currencyCode = Currency.defaultCode(for: .autoupdatingCurrent)
    @State private var failedToSave = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 18) {
                    Wordmark(size: .large)
                    Text("Your gold, in order.")
                        .font(.callout)
                        .foregroundStyle(Color(.textSecondary))
                        .multilineTextAlignment(.center)
                }
                Spacer()
                VStack(spacing: 22) {
                    LedgerLines(variant: .centered, drawsIn: true)
                    currencyRow
                    if lock.availability.canAuthenticate || lock.isEnabled {
                        lockRow
                    }
                    Button("Get started", action: getStarted)
                        .buttonStyle(.primary)
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.bottom, Spacing.stackDefault)
            .background(Color(.appBackground))
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { _ in
                CurrencyPickerView(selection: $currencyCode)
            }
        }
        .alert("Couldn't save your currency", isPresented: $failedToSave) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Choose another currency and try again.")
        }
    }

    private var currencyRow: some View {
        let option = CurrencyOption.option(for: currencyCode)
        return NavigationLink(value: "currency") {
            HStack(spacing: Spacing.rowGap) {
                Text("Currency")
                    .textRole(.rowTitle)
                    .foregroundStyle(Color(.textPrimary))
                Spacer(minLength: Spacing.rowGap)
                Text(verbatim: "\(option.name) (\(option.code))")
                    .font(.callout)
                    .foregroundStyle(Color(.textSecondary))
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.textSecondary))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.cardPaddingCompact)
            .padding(.vertical, Spacing.rowGap)
            .frame(minHeight: Size.touchTargetMin)
            .background(Color(.field), in: .rect(cornerRadius: Radius.field))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var lockRow: some View {
        Toggle(isOn: lockSelection) {
            Text(lock.availability.biometry.optInTitle)
                .textRole(.rowTitle)
                .foregroundStyle(Color(.textPrimary))
        }
        .tint(Color(.goldFill))
        .disabled(lock.isAuthenticating)
        .padding(.horizontal, Spacing.cardPaddingCompact)
        .padding(.vertical, Spacing.rowGap)
        .frame(minHeight: Size.touchTargetMin)
        .background(Color(.field), in: .rect(cornerRadius: Radius.field))
    }

    /// Moves once Face ID answers. A cancel or a failure leaves it off; Settings can turn it on later.
    private var lockSelection: Binding<Bool> {
        Binding {
            lock.isEnabled
        } set: { isOn in
            Task {
                if isOn {
                    try? await lock.enable()
                } else {
                    try? await lock.disable()
                }
            }
        }
    }

    private func getStarted() {
        do {
            try preferences.completeOnboarding(currencyCode: currencyCode)
        } catch {
            failedToSave = true
        }
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    WelcomeView()
        .environment(Preferences.preview(onboarded: false))
        .environment(AppLock.preview(locked: false))
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    WelcomeView()
        .environment(Preferences.preview(onboarded: false))
        .environment(AppLock.preview(locked: false))
        .preferredColorScheme(.dark)
}
#endif

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
/// the store opens; the Face ID opt-in joins this screen in Phase 23.
struct WelcomeView: View {

    @Environment(Preferences.self) private var preferences
    @State private var currencyCode = WelcomeView.suggestedCurrencyCode()
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

    private func getStarted() {
        do {
            try preferences.completeOnboarding(currencyCode: currencyCode)
        } catch {
            failedToSave = true
        }
    }

    /// The device region's currency, or US dollars if the region has none the system knows.
    private static func suggestedCurrencyCode() -> String {
        (try? Currency.validatedCode(Currency.defaultCode(for: .autoupdatingCurrent))) ?? "USD"
    }
}

#Preview("Light") {
    WelcomeView()
        .environment(Preferences.preview(onboarded: false))
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    WelcomeView()
        .environment(Preferences.preview(onboarded: false))
        .preferredColorScheme(.dark)
}

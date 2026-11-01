//
//  StartingBalanceView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 1/11/26.
//

import GuldrCore
import SwiftUI

/// The second first-launch screen (ADR 016; DESIGN.md › Starting balance): what the user has today, typed
/// on the add sheet's keypad, so Home's balance starts from it instead of from zero. Continue keeps the
/// amount; Start from zero skips it. Either one completes first launch, through `onFinish`.
struct StartingBalanceView: View {

    let currencyCode: String
    /// The amount in minor units; zero for Start from zero.
    let onFinish: (Int64) -> Void

    @State private var input: BalanceInput?

    init(currencyCode: String, onFinish: @escaping (Int64) -> Void) {
        self.currencyCode = currencyCode
        self.onFinish = onFinish
        // The welcome screen only offers known codes; without one, only Start from zero is left.
        _input = State(initialValue: try? BalanceInput(currencyCode: currencyCode))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.stackDefault) {
                VStack(spacing: Spacing.rowVertical) {
                    Text("How much do you have today?")
                        .textRole(.sectionTitle)
                        .foregroundStyle(Color(.textPrimary))
                        .accessibilityAddTraits(.isHeader)
                    Text("Add up your cash and accounts in \(currencyCode). You can change it later in Settings.")
                        .font(.callout)
                        .foregroundStyle(Color(.textSecondary))
                }
                .multilineTextAlignment(.center)
                if let input {
                    AmountEntryLine(amount: input.amount)
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.stackDefault)
        }
        .safeAreaInset(edge: .bottom) {
            controls
        }
        .background(Color(.appBackground))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The keypad, Continue and Start from zero, pinned to the bottom like the add sheet's keypad.
    private var controls: some View {
        VStack(spacing: Spacing.gridGap) {
            if input != nil {
                AmountKeypad(acceptsDecimals: (input?.amount.fractionDigitLimit ?? 0) > 0,
                             onDigit: { input?.pressDigit($0) ?? false },
                             onDecimalSeparator: { input?.pressDecimalSeparator() ?? false },
                             onDelete: { input?.pressDelete() ?? false })
                Button("Continue") {
                    onFinish(amount)
                }
                .buttonStyle(.primary)
                .disabled(amount == 0)
                .padding(.top, Spacing.gridGap)
            }
            Button {
                onFinish(0)
            } label: {
                Text("Start from zero")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Color(.gold))
                    .frame(minHeight: Size.touchTargetMin)
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.vertical, Spacing.gridGap)
        .background(Color(.appBackground))
    }

    private var amount: Int64 {
        input?.amount.minorUnits ?? 0
    }
}

#Preview("Light") {
    NavigationStack {
        StartingBalanceView(currencyCode: "MXN") { _ in }
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    NavigationStack {
        StartingBalanceView(currencyCode: "USD") { _ in }
    }
    .preferredColorScheme(.dark)
}

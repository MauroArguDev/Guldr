//
//  AdjustBalanceSheet.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 1/11/26.
//

import GuldrCore
import SwiftData
import SwiftUI

/// What the user has today (ADR 016; DESIGN.md › Starting balance), opened from Home's card and from
/// Settings. The amount starts at today's balance and the first key replaces it. Save stores the starting
/// balance that makes the balance show exactly what was typed; income, expenses and every other figure
/// stay as they are.
struct AdjustBalanceSheet: View {

    @Environment(Preferences.self) private var preferences
    @Environment(AppRouter.self) private var router
    @Environment(\.dataChangeNotifier) private var notifier
    @Query private var transactions: [Transaction]
    @State private var input: BalanceInput?
    @State private var failedToSave = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.sheetStack) {
                    if let input {
                        AmountEntryLine(amount: input.amount)
                    }
                    Text("Guldr changes your starting balance, never your income or expenses.")
                        .textRole(.meta)
                        .foregroundStyle(Color(.textSecondary))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.sheetStack)
            }
            .safeAreaInset(edge: .bottom) {
                if input != nil {
                    keypad
                }
            }
            .background(Color(.sheetBackground))
            .navigationTitle(Text("Adjust balance"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: router.dismissSheet)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .tint(Color(.gold))
                        .disabled(!canSave)
                }
            }
        }
        .presentationBackground(Color(.sheetBackground))
        .interactiveDismissDisabled(canSave)
        .onAppear(perform: open)
        .alert("Couldn't save your balance", isPresented: $failedToSave) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your balance didn't change. Try again in a moment.")
        }
    }

    private var keypad: some View {
        AmountKeypad(acceptsDecimals: (input?.amount.fractionDigitLimit ?? 0) > 0,
                     onDigit: { input?.pressDigit($0) ?? false },
                     onDecimalSeparator: { input?.pressDecimalSeparator() ?? false },
                     onDelete: { input?.pressDelete() ?? false })
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.gridGap)
            .background(Color(.sheetBackground))
    }

    /// Totals use the active currency (ADR 005).
    private var currencyCode: String {
        preferences.activeCurrencyCode ?? Currency.defaultCode(for: .autoupdatingCurrent)
    }

    /// Every income minus every expense logged in the active currency; `nil` if it can't be added up.
    private var loggedNet: Int64? {
        try? StartingBalance.loggedNet(of: transactions, currencyCode: currencyCode)
    }

    /// What Home shows as the balance now; `nil` if it overflows, as `MonthSummary` reports it.
    private var balanceToday: Int64? {
        guard let loggedNet else { return nil }
        let (balance, overflow) = loggedNet.addingReportingOverflow(preferences.openingBalance(for: currencyCode))
        return overflow ? nil : balance
    }

    /// Only a different amount is worth saving; it also keeps a typed amount from being swiped away.
    private var canSave: Bool {
        guard let input, let balanceToday else { return false }
        return input.amount.minorUnits != balanceToday
    }

    /// The keypad never types a negative amount, so a negative balance starts empty.
    private func open() {
        guard input == nil else { return }
        let today = max(0, balanceToday ?? 0)
        input = try? BalanceInput(prefilled: Money(minorUnits: today, currencyCode: currencyCode))
    }

    private func save() {
        guard let input, let loggedNet else {
            failedToSave = true
            return
        }
        do {
            let opening = try StartingBalance.opening(forBalanceToday: input.amount.minorUnits, loggedNet: loggedNet)
            try preferences.setOpeningBalance(opening, for: currencyCode)
        } catch {
            failedToSave = true
            return
        }
        // The widget's balance includes the starting balance.
        notifier.dataDidChange()
        router.dismissSheet()
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    PreviewEnvironment { AdjustBalanceSheet() }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewEnvironment { AdjustBalanceSheet() }
        .preferredColorScheme(.dark)
}
#endif

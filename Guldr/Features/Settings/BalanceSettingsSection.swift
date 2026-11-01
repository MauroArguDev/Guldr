//
//  BalanceSettingsSection.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 1/11/26.
//

import GuldrCore
import SwiftData
import SwiftUI

/// Settings' "Balance" section (ADR 016; DESIGN.md › Starting balance): "Adjust balance", with the balance
/// Home shows, opens the sheet that sets what the user has today.
struct BalanceSettingsSection: View {

    @Environment(Preferences.self) private var preferences
    @Environment(AppRouter.self) private var router
    @Environment(\.locale) private var locale
    @Query private var transactions: [Transaction]

    var body: some View {
        Section {
            Button {
                router.present(.adjustBalance)
            } label: {
                LabeledContent {
                    if let balance {
                        Text(verbatim: MoneyFormatter(locale: locale).string(from: balance))
                            .foregroundStyle(Color(.textSecondary))
                    }
                } label: {
                    Text("Adjust balance")
                        .foregroundStyle(Color(.textPrimary))
                }
            }
        } header: {
            Text("Balance")
        } footer: {
            Text("Set what you have today in \(currencyCode). Your income and expenses don't change.")
        }
    }

    /// Totals use the active currency (ADR 005).
    private var currencyCode: String {
        preferences.activeCurrencyCode ?? Currency.defaultCode(for: locale)
    }

    /// Home's balance; the month doesn't matter to it.
    private var balance: Money? {
        try? MonthSummary(transactions: transactions, month: YearMonth(containing: .now), currencyCode: currencyCode,
                          openingBalance: preferences.openingBalance(for: currencyCode)).balance
    }
}

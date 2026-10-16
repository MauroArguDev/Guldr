//
//  DashboardView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftData
import SwiftUI

/// The Home tab: the Dashboard mockup. The header is the wordmark and the current month as the first
/// row of the content, with no large title, and Settings as a native toolbar button (author's call,
/// 2026-10-16). Below it, the balance card; the budget summary and recent transactions arrive in the
/// next steps of the v1 plan's Phase 19.
struct DashboardView: View {

    @Environment(AppRouter.self) private var router
    @Environment(Preferences.self) private var preferences
    @Environment(\.locale) private var locale
    @Query private var transactions: [Transaction]
    @State private var model = DashboardModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.stackDefault) {
                    header
                    if let balance = model.balance {
                        BalanceCard(balance: balance.total, income: balance.income, expenses: balance.expenses,
                                    savingsRate: balance.savingsRate,
                                    drawsLedgerLines: LedgerLaunchDraw.isFirstAppearance)
                            .onAppear { LedgerLaunchDraw.isFirstAppearance = false }
                    }
                    if !model.hasTransactions {
                        // Until 19.5 builds the Recent section, which will hold this invitation.
                        EmptyStateView(title: "Your month starts here", symbol: "house",
                                       message: "Add your first expense or income to see your balance.",
                                       actionTitle: "Add transaction") {
                            router.present(.addTransaction)
                        }
                        .padding(.top, Spacing.stackDefault)
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.stackDefault)
            }
            .onChange(of: transactions, initial: true) { refresh() }
            .onChange(of: currencyCode) { refresh() }
            // An edit keeps the transaction's identity, so the query's results compare equal; a save says when.
            .onChange(of: router.lastSave) { refresh() }
            .background(Color(.appBackground))
            // The tab keeps its name for the back button and VoiceOver; the wordmark replaces the title,
            // so the bar shows it inline and hides it (removing it alone still drew the large title).
            .navigationTitle(Text(AppTab.home.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(removing: .title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
                }
            }
        }
    }

    /// Totals use the active currency (ADR 005); before first launch picks one, the locale's.
    private var currencyCode: String {
        preferences.activeCurrencyCode ?? Currency.defaultCode(for: .autoupdatingCurrent)
    }

    private func refresh() {
        model.update(transactions: transactions, currencyCode: currencyCode)
    }

    /// "guldr" over "October 2026".
    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Wordmark()
            Text(verbatim: model.month.title(locale: locale))
                .textRole(.meta)
                .foregroundStyle(Color(.textSecondary))
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The ledger lines draw in once per launch (DESIGN.md › Motion), not every time Home reappears.
@MainActor
private enum LedgerLaunchDraw {
    static var isFirstAppearance = true
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    PreviewEnvironment { DashboardView() }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewEnvironment { DashboardView() }
        .preferredColorScheme(.dark)
}
#endif

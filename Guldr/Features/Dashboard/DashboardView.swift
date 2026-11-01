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
/// 2026-10-16), with the streak chip on the right (author's call, 2026-10-23). Below it: the balance card,
/// the month's budget summary and the latest transactions, or an invitation to add the first one. Users
/// who finished onboarding before the starting balance existed get one card asking for it (ADR 016).
struct DashboardView: View {

    @Environment(AppRouter.self) private var router
    @Environment(Preferences.self) private var preferences
    @Environment(StreakCenter.self) private var streak
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var transactions: [Transaction]
    @Query private var budgets: [Budget]
    /// Only the newest few, so the Recent section never reads the whole history.
    @Query(Self.recentDescriptor) private var recentTransactions: [Transaction]
    @ReduceMotion private var reduceMotion
    @State private var model = DashboardModel()
    /// Last month, while its recap is offered on Home; read with the rest of the data, not on every render.
    @State private var recapMonth: YearMonth?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.stackDefault) {
                    header
                    if let month = recapMonth, month != preferences.dismissedRecapMonth {
                        RecapHomeCard(month: month) {
                            router.present(.recap(month))
                        } onClose: {
                            withMotion(.standard) { preferences.dismissRecap(month) }
                        }
                        .motionTransition(.opacity)
                    }
                    if !preferences.hasOfferedStartingBalance {
                        StartingBalanceHomeCard {
                            router.present(.adjustBalance)
                        } onClose: {
                            withMotion(.standard) { preferences.dismissStartingBalanceOffer() }
                        }
                        .motionTransition(.opacity)
                    }
                    if let balance = model.balance {
                        BalanceCard(balance: balance.total, income: balance.income, expenses: balance.expenses,
                                    savingsRate: balance.savingsRate,
                                    drawsLedgerLines: LaunchEntrance.ledgerLinesPending)
                            .onAppear { LaunchEntrance.ledgerLinesPending = false }
                    }
                    if let budget = model.budget {
                        budgetRow(budget)
                    }
                    if model.hasTransactions {
                        recentSection
                    } else {
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
            .onChange(of: budgets, initial: true) { refresh() }
            .onChange(of: recentTransactions) { refresh() }
            .onChange(of: currencyCode) { refresh() }
            .onChange(of: preferences.openingBalances) { refresh() }
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
        refreshRecapMonth()
        model.update(transactions: transactions, budgets: budgets, recent: recentTransactions,
                     currencyCode: currencyCode, openingBalance: preferences.openingBalance(for: currencyCode))
    }

    /// Last month's recap during the first days of this one (v1 plan, Phase 31), if last month has anything
    /// in it; the view leaves it out once closed.
    private func refreshRecapMonth() {
        guard let currencyCode = preferences.activeCurrencyCode else {
            recapMonth = nil
            return
        }
        let now = Date.now
        recapMonth = RecapLibrary.homeMonth(now: now, timeZone: .autoupdatingCurrent, dismissed: nil,
                                            available: RecapLibrary.availableMonths(in: context, currencyCode: currencyCode,
                                                                                    now: now, timeZone: .autoupdatingCurrent))
    }

    private static var recentDescriptor: FetchDescriptor<Transaction> {
        var descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse),
                                                               SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = DashboardModel.recentLimit
        return descriptor
    }

    private var recentHeaderLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
    }

    /// "Recent" with "See all", then the latest transactions; a row opens it for editing.
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Side by side as in the mockup; "See all" goes under the title at accessibility sizes.
            recentHeaderLayout {
                Text("Recent")
                    .textRole(.sectionTitle)
                    .foregroundStyle(Color(.textPrimary))
                    .accessibilityAddTraits(.isHeader)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
                Button("See all") {
                    router.select(.transactions)
                }
                .font(.body.weight(.medium))
                .foregroundStyle(Color(.gold))
                .accessibilityHint(Text("Opens Transactions"))
            }
            .padding(.horizontal, 2)
            .padding(.top, 4)
            .padding(.bottom, 6)

            ForEach(Array(model.recent.enumerated()), id: \.element.id) { index, row in
                Button {
                    router.present(.editTransaction(row.id))
                } label: {
                    TransactionRow(title: row.title, meta: row.meta, symbol: row.symbol, amount: row.amount,
                                   kind: row.kind)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Opens the transaction to edit it"))
                .modifier(RecentEntrance(index: index, animates: LaunchEntrance.recentRowsPending,
                                         reduceMotion: reduceMotion))
            }
            .onAppear { LaunchEntrance.recentRowsPending = false }
        }
    }

    /// The month's budgets in one row, opening the Budget tab.
    private func budgetRow(_ budget: DashboardModel.BudgetSummary) -> some View {
        Button {
            router.select(.budget)
        } label: {
            BudgetSummaryRow(title: budget.title, detail: budget.detail, usage: budget.usage)
                .padding(.vertical, Spacing.summaryRowVertical)
                .padding(.horizontal, Spacing.cardPaddingCompact)
                .card(.compact)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Opens Budget"))
    }

    /// "guldr" over "October 2026".
    /// The chip beside the month, or under it at accessibility text sizes, where they don't fit side by
    /// side on an iPhone SE (32.3).
    private var headerLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
    }

    private var header: some View {
        headerLayout {
            VStack(alignment: .leading, spacing: 2) {
                Wordmark()
                Text(verbatim: model.month.title(locale: locale))
                    .textRole(.meta)
                    .foregroundStyle(Color(.textSecondary))
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            if streak.isShown {
                StreakChip(streak: streak.streak) {
                    router.present(.streak)
                }
            }
        }
    }
}

/// Home's entrances run once per launch (DESIGN.md › Motion), not every time the tab reappears.
@MainActor
private enum LaunchEntrance {
    static var ledgerLinesPending = true
    static var recentRowsPending = true
}

/// Recent rows rise into place one after another (`stagger`); with Reduce Motion they only fade in,
/// all together.
private struct RecentEntrance: ViewModifier {

    let index: Int
    let animates: Bool
    let reduceMotion: Bool
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(!animates || shown ? 1 : 0)
            .offset(y: !animates || shown || reduceMotion ? 0 : 8)
            .motion(.standard, value: shown, delay: Motion.staggerDelay(index: index, reduceMotion: reduceMotion))
            .onAppear { shown = true }
    }
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

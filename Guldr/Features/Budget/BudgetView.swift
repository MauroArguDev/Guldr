//
//  BudgetView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftData
import SwiftUI

/// The Budget tab: the Budget mockup. A native large title, then the month with previous and next
/// buttons as the first row of the content, the ring card, an alert per over-budget category and every
/// budgeted category's row. A month without budgets shows the empty state.
struct BudgetView: View {

    @Environment(AppRouter.self) private var router
    @Environment(Preferences.self) private var preferences
    @Query private var transactions: [Transaction]
    @Query private var budgets: [Budget]
    @State private var model = BudgetModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.stackCompact) {
                    monthSwitcher
                    if let overview = model.overview {
                        BudgetOverviewCard(overview: overview)
                        ForEach(model.alerts) { alert in
                            OverBudgetAlert(categoryName: alert.categoryName, overAmount: alert.overAmount)
                        }
                        categoryRows
                    } else {
                        EmptyStateView(title: "No budgets yet", symbol: "chart.pie",
                                       message: "Set a monthly limit for a category to see what is left to spend.",
                                       actionTitle: "Set a budget") {
                            router.present(.editBudget)
                        }
                        .padding(.top, Spacing.stackDefault)
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.stackDefault)
            }
            .onChange(of: transactions, initial: true) { refresh() }
            .onChange(of: budgets) { refresh() }
            .onChange(of: model.month) { refresh() }
            .onChange(of: currencyCode) { refresh() }
            // An edit keeps the transaction's identity, so the query's results compare equal; a save says when.
            .onChange(of: router.lastSave) { refresh() }
            .background(Color(.appBackground))
            .navigationTitle(Text(AppTab.budget.title))
        }
    }

    /// Totals use the active currency (ADR 005); before first launch picks one, the locale's.
    private var currencyCode: String {
        preferences.activeCurrencyCode ?? Currency.defaultCode(for: .autoupdatingCurrent)
    }

    private func refresh() {
        model.update(transactions: transactions, budgets: budgets, currencyCode: currencyCode)
    }

    /// The mockup's rows sit straight on the background, 2 pt apart, highest usage first.
    private var categoryRows: some View {
        VStack(spacing: 2) {
            ForEach(model.rows) { row in
                CategoryBudgetRow(name: row.name, symbol: row.symbol, line: row.line)
                    .padding(.horizontal, 2)
            }
        }
    }

    /// "‹ September 2026 ›": chevrons in `TextSecondary` at the edges, the month centered. Next stops at
    /// next month and fades to 40 %, the disabled style of the primary button.
    private var monthSwitcher: some View {
        HStack(spacing: 0) {
            monthButton("Previous month", symbol: "chevron.left", alignment: .leading) {
                model.showPreviousMonth()
            }
            Text(verbatim: model.monthTitle)
                .textRole(.cardTitle)
                .foregroundStyle(Color(.textPrimary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            monthButton("Next month", symbol: "chevron.right", alignment: .trailing) {
                model.showNextMonth()
            }
            .disabled(!model.canShowNextMonth)
            .opacity(model.canShowNextMonth ? 1 : 0.4)
        }
    }

    private func monthButton(_ title: LocalizedStringKey, symbol: String, alignment: Alignment,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(.textSecondary))
                .frame(width: Size.touchTargetMin, height: Size.touchTargetMin, alignment: alignment)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    PreviewEnvironment { BudgetView() }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewEnvironment { BudgetView() }
        .preferredColorScheme(.dark)
}
#endif

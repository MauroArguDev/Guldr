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
/// budgeted category's row. A month without budgets shows the empty state. Edit opens the month's
/// limits in a sheet.
struct BudgetView: View {

    @Environment(AppRouter.self) private var router
    @Environment(Preferences.self) private var preferences
    @Environment(\.modelContext) private var context
    @Environment(\.dataChangeNotifier) private var notifier
    @Environment(BudgetAlertCenter.self) private var alerts
    @Query private var transactions: [Transaction]
    @Query private var budgets: [Budget]
    @State private var model = BudgetModel()
    @State private var failedToCopy = false

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
                        emptyState
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        router.present(.editBudget(model.month))
                    }
                    .tint(Color(.gold))
                    .accessibilityHint(Text("Edits this month's budgets"))
                }
            }
        }
        .alert("Couldn't copy last month's budgets", isPresented: $failedToCopy) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try again in a moment.")
        }
    }

    /// Totals use the active currency (ADR 005); before first launch picks one, the locale's.
    private var currencyCode: String {
        preferences.activeCurrencyCode ?? Currency.defaultCode(for: .autoupdatingCurrent)
    }

    private func refresh() {
        model.update(transactions: transactions, budgets: budgets, currencyCode: currencyCode)
    }

    /// A month without budgets (author's call, 2026-10-20): copying last month's is the primary action
    /// when it has any, with setting them by hand as the secondary one; otherwise only the latter.
    @ViewBuilder
    private var emptyState: some View {
        if model.canCopyLastMonth {
            EmptyStateView(title: "No budgets this month", symbol: "chart.pie",
                           message: "Start from last month's limits, or set new ones.",
                           actionTitle: "Copy last month's budgets", action: copyLastMonth,
                           secondaryActionTitle: "Set budgets", secondaryAction: editBudgets)
        } else {
            EmptyStateView(title: "No budgets yet", symbol: "chart.pie",
                           message: "Set a monthly limit for a category to see what is left to spend.",
                           actionTitle: "Set budgets", action: editBudgets)
        }
    }

    private func editBudgets() {
        router.present(.editBudget(model.month))
    }

    /// Copies and saves at once: the user already chose last month's limits, so there is nothing to review.
    /// It goes through the edit sheet's model, so both paths save the same way.
    private func copyLastMonth() {
        do {
            let editor = try EditBudgetModel(month: model.month, context: context, currencyCode: currencyCode,
                                             notifier: notifier)
            editor.copyLastMonth()
            try editor.save()
            router.finishSave(.saved)
            // No sheet closes on this path, so the budget alerts offer comes from here.
            Task { await alerts.offerIfNeeded() }
        } catch {
            failedToCopy = true
        }
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

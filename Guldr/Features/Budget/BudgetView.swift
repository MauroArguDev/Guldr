//
//  BudgetView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftUI

/// The Budget tab: the Budget mockup. A native large title, then the month with previous and next
/// buttons as the first row of the content. Until the rest of the screen is built (v1 plan, Phase 20),
/// the body is the empty state a new user sees.
struct BudgetView: View {

    @Environment(AppRouter.self) private var router
    @State private var model = BudgetModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.stackCompact) {
                    monthSwitcher
                    EmptyStateView(title: "No budgets yet", symbol: "chart.pie",
                                   message: "Set a monthly limit for a category to see what is left to spend.",
                                   actionTitle: "Set a budget") {
                        router.present(.editBudget)
                    }
                    .padding(.top, Spacing.stackDefault)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.stackDefault)
            }
            .background(Color(.appBackground))
            .navigationTitle(Text(AppTab.budget.title))
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

#Preview("Light") {
    BudgetView()
        .environment(AppRouter())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    BudgetView()
        .environment(AppRouter())
        .preferredColorScheme(.dark)
}

//
//  BudgetView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI

/// The Budget tab's root. Until the budget screen (v1 plan, Phase 20) is built, it shows the empty state
/// a new user sees.
struct BudgetView: View {

    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack {
            EmptyStateView(title: "No budgets yet", symbol: "chart.pie",
                           message: "Set a monthly limit for a category to see what is left to spend.",
                           actionTitle: "Set a budget") {
                router.present(.editBudget)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.appBackground))
            .navigationTitle(Text(AppTab.budget.title))
        }
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

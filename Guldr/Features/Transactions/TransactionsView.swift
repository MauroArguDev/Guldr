//
//  TransactionsView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI

/// The Transactions tab's root. Until the transactions list (v1 plan, Phase 18) builds the screen, it
/// shows the empty state a new user sees.
struct TransactionsView: View {

    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack {
            EmptyStateView(title: "No transactions yet", symbol: "list.bullet",
                           message: "Add your first expense or income to see it here.",
                           actionTitle: "Add transaction") {
                router.present(.addTransaction)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.appBackground))
            .navigationTitle(Text(AppTab.transactions.title))
        }
    }
}

#Preview("Light") {
    TransactionsView()
        .environment(AppRouter())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    TransactionsView()
        .environment(AppRouter())
        .preferredColorScheme(.dark)
}

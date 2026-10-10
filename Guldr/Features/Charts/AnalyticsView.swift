//
//  AnalyticsView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI

/// The Analytics tab's root. Until the charts (v1 plan, Phase 21) are built, it shows the empty state a
/// new user sees.
struct AnalyticsView: View {

    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack {
            EmptyStateView(title: "Nothing to chart yet", symbol: "chart.bar",
                           message: "Your income and spending show up here once you add transactions.",
                           actionTitle: "Add transaction") {
                router.present(.addTransaction)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.appBackground))
            .navigationTitle(Text(AppTab.analytics.title))
        }
    }
}

#Preview("Light") {
    AnalyticsView()
        .environment(AppRouter())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    AnalyticsView()
        .environment(AppRouter())
        .preferredColorScheme(.dark)
}

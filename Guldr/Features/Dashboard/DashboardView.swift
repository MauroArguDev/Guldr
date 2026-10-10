//
//  DashboardView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI

/// The Home tab's root. Until the dashboard (v1 plan, Phase 19) builds the screen, it shows the empty
/// state a new user sees. Debug builds link to the design system gallery from here.
struct DashboardView: View {

    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack {
            EmptyStateView(title: "Your month starts here", symbol: "house",
                           message: "Add your first expense or income to see your balance.",
                           actionTitle: "Add transaction") {
                router.present(.addTransaction)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.appBackground))
            .navigationTitle(Text(AppTab.home.title))
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        DesignSystemGallery()
                    } label: {
                        Label {
                            Text(verbatim: "Design system gallery")
                        } icon: {
                            Image(systemName: "swatchpalette")
                        }
                    }
                }
            }
            #endif
        }
    }
}

#Preview("Light") {
    DashboardView()
        .environment(AppRouter())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    DashboardView()
        .environment(AppRouter())
        .preferredColorScheme(.dark)
}

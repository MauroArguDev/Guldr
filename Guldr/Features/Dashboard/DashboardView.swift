//
//  DashboardView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftUI

/// The Home tab: the Dashboard mockup. The header is the wordmark and the current month as the first
/// row of the content, with no large title, and Settings as a native toolbar button (author's call,
/// 2026-10-16). The balance card, budget summary and recent transactions arrive in the next steps of
/// the v1 plan's Phase 19; until then the body is the empty state a new user sees.
struct DashboardView: View {

    @Environment(AppRouter.self) private var router
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.stackDefault) {
                    header
                    EmptyStateView(title: "Your month starts here", symbol: "house",
                                   message: "Add your first expense or income to see your balance.",
                                   actionTitle: "Add transaction") {
                        router.present(.addTransaction)
                    }
                    .padding(.top, Spacing.stackDefault)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
            }
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

    /// "guldr" over "October 2026".
    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Wordmark()
            Text(verbatim: YearMonth(containing: .now).title(locale: locale))
                .textRole(.meta)
                .foregroundStyle(Color(.textSecondary))
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
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

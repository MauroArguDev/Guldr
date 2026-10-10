//
//  RootView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI

/// The app shell: the native iOS 26 tab bar with one `NavigationStack` per tab.
///
/// The Add button is a tab with the `.search` role, which iOS 26 draws as a separate circle next to the
/// tab bar, where DESIGN.md › Components places it. Selecting it never switches tabs: the selection
/// binding swallows `.add` and opens the add sheet, so the user stays where they were.
struct RootView: View {

    @State private var selectedTab: AppTab = .home
    @State private var isAddPresented = false

    var body: some View {
        TabView(selection: tabSelection) {
            Tab(value: AppTab.home) {
                DashboardView()
            } label: {
                label(for: .home)
            }
            Tab(value: AppTab.transactions) {
                TransactionsView()
            } label: {
                label(for: .transactions)
            }
            Tab(value: AppTab.budget) {
                BudgetView()
            } label: {
                label(for: .budget)
            }
            Tab(value: AppTab.analytics) {
                AnalyticsView()
            } label: {
                label(for: .analytics)
            }
            Tab(value: AppTab.add, role: .search) {
                // Never shown: selecting this tab opens the sheet instead.
                Color(.appBackground)
            } label: {
                Label {
                    Text(AppTab.add.title)
                } icon: {
                    addSymbol
                }
            }
        }
        .tint(Color(.gold))
        .sheet(isPresented: $isAddPresented) {
            // Placeholder until the add sheet (v1 plan, Phase 17).
            NavigationStack {
                Color(.appBackground)
                    .ignoresSafeArea()
                    .navigationTitle(Text(AppTab.add.title))
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private var tabSelection: Binding<AppTab> {
        Binding {
            selectedTab
        } set: { newValue in
            if newValue == .add {
                isAddPresented = true
            } else {
                selectedTab = newValue
            }
        }
    }

    /// The tab bar draws unselected symbols in its own neutral color and ignores `foregroundStyle`, so the
    /// plus is pre-tinted with `Gold` (DESIGN.md › Color: gold marks the brand's primary action). The asset
    /// color is dynamic, so it still follows light and dark mode.
    private var addSymbol: Image {
        let symbol = UIImage(systemName: AppTab.add.symbol)?
            .withTintColor(UIColor(resource: .gold), renderingMode: .alwaysOriginal)
        return symbol.map(Image.init(uiImage:)) ?? Image(systemName: AppTab.add.symbol)
    }

    private func label(for tab: AppTab) -> some View {
        Label {
            Text(tab.title)
        } icon: {
            Image(systemName: tab.symbol)
        }
    }
}

#Preview("Light") {
    RootView().preferredColorScheme(.light)
}

#Preview("Dark") {
    RootView().preferredColorScheme(.dark)
}

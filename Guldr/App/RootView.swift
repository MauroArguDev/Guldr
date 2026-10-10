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
/// binding routes through `AppRouter.select(_:)`, which opens the add sheet instead.
struct RootView: View {

    @State private var router = AppRouter()

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
        .sheet(item: $router.sheet) { sheet in
            SheetPlaceholder(sheet: sheet)
        }
        .onOpenURL { url in
            router.open(url)
        }
        .environment(router)
    }

    private var tabSelection: Binding<AppTab> {
        Binding {
            router.selectedTab
        } set: { newValue in
            router.select(newValue)
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

/// Stands in for the real sheets until their phases build them (add and edit transaction in Phase 17,
/// edit budget in Phase 20).
private struct SheetPlaceholder: View {

    let sheet: AppSheet

    var body: some View {
        NavigationStack {
            Color(.appBackground)
                .ignoresSafeArea()
                .navigationTitle(Text(verbatim: title))
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var title: String {
        switch sheet {
        case .addTransaction: "Add transaction"
        case .editTransaction: "Edit transaction"
        case .editBudget: "Edit budget"
        }
    }
}

#Preview("Light") {
    RootView().preferredColorScheme(.light)
}

#Preview("Dark") {
    RootView().preferredColorScheme(.dark)
}

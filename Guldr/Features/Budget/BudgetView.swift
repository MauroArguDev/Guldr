//
//  BudgetView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI

/// The Budget tab's root. Placeholder until its phase builds the screen.
struct BudgetView: View {
    var body: some View {
        NavigationStack {
            Color(.appBackground)
                .ignoresSafeArea()
                .navigationTitle(Text(AppTab.budget.title))
        }
    }
}

#Preview("Light") {
    BudgetView().preferredColorScheme(.light)
}

#Preview("Dark") {
    BudgetView().preferredColorScheme(.dark)
}

//
//  TransactionsView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI

/// The Transactions tab's root. Placeholder until its phase builds the screen.
struct TransactionsView: View {
    var body: some View {
        NavigationStack {
            Color(.appBackground)
                .ignoresSafeArea()
                .navigationTitle(Text(AppTab.transactions.title))
        }
    }
}

#Preview("Light") {
    TransactionsView().preferredColorScheme(.light)
}

#Preview("Dark") {
    TransactionsView().preferredColorScheme(.dark)
}

//
//  EmptyStateView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI

/// The empty state for a list or chart with nothing to show: native `ContentUnavailableView` with the
/// app's colors and an optional primary action. No mockup exists; native first (DESIGN.md › Principles).
struct EmptyStateView: View {

    let title: LocalizedStringKey
    let symbol: String
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
                .foregroundStyle(Color(.textPrimary))
        } description: {
            Text(message).foregroundStyle(Color(.textSecondary))
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.primary)
                    .fixedSize()
            }
        }
    }
}

#Preview("Light") {
    EmptyStateView(title: "No transactions yet", symbol: "list.bullet",
                   message: "Add your first expense or income to see it here.",
                   actionTitle: "Add transaction", action: {})
        .background(Color(.appBackground))
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    EmptyStateView(title: "No results", symbol: "magnifyingglass", message: "Try another search or filter.")
        .background(Color(.appBackground))
        .preferredColorScheme(.dark)
}

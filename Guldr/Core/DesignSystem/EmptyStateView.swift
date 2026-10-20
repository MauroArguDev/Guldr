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
    /// A second, quieter choice under the primary button, in `Gold`.
    var secondaryActionTitle: LocalizedStringKey?
    var secondaryAction: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At the largest text sizes the content is taller than the screen, so it scrolls instead of
        // being clipped; otherwise it stays centered like the system's empty states.
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
    }

    private var content: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
                .foregroundStyle(Color(.textPrimary))
        } description: {
            Text(message).foregroundStyle(Color(.textSecondary))
        } actions: {
            if let actionTitle, let action {
                // The button hugs its title, except at accessibility sizes, where a fixed width would
                // push the whole view wider than the screen.
                Button(actionTitle, action: action)
                    .buttonStyle(.primary)
                    .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: false)
            }
            if let secondaryActionTitle, let secondaryAction {
                Button(secondaryActionTitle, action: secondaryAction)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color(.gold))
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

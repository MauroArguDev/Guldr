//
//  AppTab.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI

/// The root tab bar's items. `add` is not a destination: it is drawn as the separate circular button
/// next to the tab bar and opens the add sheet instead of becoming the selected tab.
enum AppTab: Hashable, CaseIterable {
    case home
    case transactions
    case budget
    case analytics
    case add

    var title: LocalizedStringResource {
        switch self {
        case .home: "Home"
        case .transactions: "Transactions"
        case .budget: "Budget"
        case .analytics: "Analytics"
        case .add: "Add transaction"
        }
    }

    /// SF Symbols matching the mockups' tab icons (DESIGN.md › Components).
    var symbol: String {
        switch self {
        case .home: "house"
        case .transactions: "list.bullet"
        case .budget: "chart.pie"
        case .analytics: "chart.bar"
        case .add: "plus"
        }
    }
}

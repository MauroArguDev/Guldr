//
//  AppRouter.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import GuldrCore
import Observation
import SwiftData

/// A sheet presented over the whole app, whichever tab is selected.
enum AppSheet: Identifiable, Hashable {
    case addTransaction
    /// The transaction is passed by identifier, not as a model: identifiers are `Sendable` and stay valid
    /// across contexts, and the sheet fetches the model it edits.
    case editTransaction(PersistentIdentifier)
    case editBudget

    var id: Self { self }
}

/// App-wide navigation state: the selected tab and the presented sheet. Owned by `RootView` and shared
/// through the environment, so any screen can open a sheet and deep links have one place to land.
@Observable
final class AppRouter {

    private(set) var selectedTab: AppTab = .home
    var sheet: AppSheet?

    /// The tab bar's selection. `.add` is the Add button, not a destination: it opens the add sheet and
    /// leaves the selected tab as it was.
    func select(_ tab: AppTab) {
        if tab == .add {
            present(.addTransaction)
        } else {
            selectedTab = tab
        }
    }

    func present(_ sheet: AppSheet) {
        self.sheet = sheet
    }

    func dismissSheet() {
        sheet = nil
    }

    /// Handles a `guldr://` URL. Returns `false` for a URL that is not a known deep link, which is ignored.
    @discardableResult
    func open(_ url: URL) -> Bool {
        guard let link = DeepLink(url: url) else { return false }
        switch link {
        case .add:
            present(.addTransaction)
        case .budget:
            // The user asked to see their budget, so whatever sheet was open is closed first.
            dismissSheet()
            selectedTab = .budget
        }
        return true
    }
}

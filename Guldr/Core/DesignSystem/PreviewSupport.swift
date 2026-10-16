//
//  PreviewSupport.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

#if DEBUG
import Foundation
import GuldrCore
import SwiftData
import SwiftUI

extension Money {
    /// Previews only, compiled out of release builds. USD is a valid ISO 4217 code, so this cannot fail.
    static func previewUSD(_ cents: Int64) -> Money {
        // swiftlint:disable:next force_try
        try! Money(minorUnits: cents, currencyCode: "USD") // Valid code, debug-only previews.
    }
}

extension BudgetStatus.Line {
    /// Previews only: a USD budget line with `spent` of `limit` cents.
    static func preview(_ spent: Int64, of limit: Int64) -> BudgetStatus.Line {
        BudgetStatus.Line(budgetID: UUID(), categoryID: UUID(), spent: .previewUSD(spent), limit: .previewUSD(limit))
    }
}

/// Previews only: wraps a screen in what the app provides above it, the mockups' data in memory, an
/// onboarded user in US dollars and a router. Shows nothing if the in-memory store can't be built.
struct PreviewEnvironment<Content: View>: View {

    @State private var container: ModelContainer?
    @State private var router = AppRouter()
    private let content: () -> Content

    /// `seeded: false` keeps only the default categories, for empty states.
    init(seeded: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        let controller = seeded ? try? PreviewData.makeController() : try? PersistenceController(mode: .inMemory)
        _container = State(initialValue: controller?.container)
        self.content = content
    }

    var body: some View {
        if let container {
            content()
                .modelContainer(container)
                .environment(Preferences.preview(onboarded: true))
                .environment(router)
        }
    }
}
#endif

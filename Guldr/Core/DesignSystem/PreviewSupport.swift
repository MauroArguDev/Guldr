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

extension AmountInput {
    /// Previews only: `cents` typed in `currencyCode`, empty at zero. The codes previews pass are valid.
    static func preview(_ cents: Int64 = 0, _ currencyCode: String = "USD") -> AmountInput {
        // swiftlint:disable:next force_try
        try! AmountInput(money: Money(minorUnits: cents, currencyCode: currencyCode)) // Valid code, debug-only previews.
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
    @State private var lock = AppLock.preview(locked: false)
    @State private var alerts: BudgetAlertCenter?
    @State private var reminder: DailyReminderCenter?
    @State private var streak: StreakCenter?
    @State private var achievements: AchievementCenter?
    @State private var inbox = NotificationInbox()
    private let content: () -> Content

    /// `seeded: false` keeps only the default categories, for empty states.
    init(seeded: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        let controller = seeded ? try? PreviewData.makeController() : try? PersistenceController(mode: .inMemory)
        _container = State(initialValue: controller?.container)
        _alerts = State(initialValue: controller.map { BudgetAlertCenter.preview(container: $0.container) })
        _reminder = State(initialValue: controller.map { DailyReminderCenter.preview(container: $0.container) })
        _streak = State(initialValue: controller.map { StreakCenter.preview(container: $0.container) })
        _achievements = State(initialValue: controller.map { AchievementCenter.preview(container: $0.container) })
        self.content = content
    }

    var body: some View {
        if let container, let alerts, let reminder, let streak, let achievements {
            content()
                .modelContainer(container)
                .environment(Preferences.preview(onboarded: true))
                .environment(router)
                .environment(lock)
                .environment(alerts)
                .environment(reminder)
                .environment(streak)
                .environment(achievements)
                .environment(inbox)
        }
    }
}
#endif

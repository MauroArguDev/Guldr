//
//  RootView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftUI

/// The app shell: the native iOS 26 tab bar with one `NavigationStack` per tab.
///
/// The Add button is a tab that the system draws as a separate circle next to the tab bar, where
/// DESIGN.md › Components places it (see `addTabRole`). Selecting it never switches tabs: the selection
/// binding routes through `AppRouter.select(_:)`, which opens the add sheet instead.
struct RootView: View {

    @State private var router = AppRouter()
    @Environment(BudgetAlertCenter.self) private var alerts
    @Environment(DailyReminderCenter.self) private var reminder
    @Environment(NotificationInbox.self) private var inbox
    @Environment(StreakCenter.self) private var streak
    @Environment(AchievementCenter.self) private var achievements
    @Environment(\.dataChangeNotifier) private var notifier

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
            Tab(value: AppTab.add, role: Self.addTabRole) {
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
        // Offered once a sheet is fully gone, so the alert never meets a sheet on its way out.
        .sheet(item: $router.sheet, onDismiss: offerNotifications) { sheet in
            switch sheet {
            case .addTransaction:
                AddTransactionSheet()
            case .editTransaction(let id):
                AddTransactionSheet(transactionID: id)
            case .editBudget(let month):
                EditBudgetSheet(month: month)
            case .streak:
                StreakSheet()
            case .shareAchievement(let id):
                if let progress = achievements.progress.first(where: { $0.id == id }), let tier = progress.tier {
                    ShareCardSheet(content: .achievement(progress.achievement, tier))
                }
            case .recap(let month):
                RecapSheet(month: month)
            }
        }
        // Moments wait for any sheet to close, so they never show behind one, and come one at a time: a
        // streak milestone first, then each achievement unlocked.
        .overlay(alignment: .top) {
            if router.sheet == nil {
                if let milestone = streak.celebration {
                    MomentBanner(milestone: milestone) { streak.celebrationDidEnd() }
                        .id("streak-\(milestone)")
                } else if let unlock = achievements.currentUnlock {
                    MomentBanner(unlock: unlock) {
                        achievements.unlockDidEnd()
                    } onShare: {
                        // The card leaves with the sheet; it isn't shown again afterwards.
                        achievements.unlockDidEnd()
                        router.present(.shareAchievement(unlock.id))
                    }
                    .id("\(unlock.id.rawValue)-\(unlock.tier.rawValue)")
                }
            }
        }
        // The sheet is already closing when a save finishes, so its haptic plays here.
        .sensoryFeedback(trigger: router.lastSave) { _, event in
            event.map { $0.outcome == .crossedBudget ? Haptics.budgetExceeded : Haptics.saved }
        }
        .onOpenURL { url in
            router.open(url)
        }
        // `initial`: a tap that launched Guldr was recorded before this view existed.
        .onChange(of: inbox.lastOpened, initial: true) { _, opened in
            guard let opened else { return }
            switch opened.action {
            case .open(let link):
                router.open(link.url)
            case .markNoSpending(let day):
                // A day that can no longer be marked (an old notification) is left as it is.
                guard (try? streak.markNoSpending(day)) != nil else { return }
                notifier.dataDidChange()
            }
        }
        .alert("Get budget alerts?", isPresented: alertOffer) {
            Button("Turn on") {
                Task { await alerts.acceptOffer() }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Guldr can tell you when a category reaches 80% and 100% of its monthly budget.")
        }
        .alert("Get a daily reminder?", isPresented: reminderOffer) {
            Button("Turn on") {
                Task { await reminder.acceptOffer() }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Guldr can remind you once a day to log what you spent. You can change the time in Settings.")
        }
        .environment(router)
    }

    /// The pre-prompt (author's call, 2026-10-21); iOS's own dialog only follows "Turn on".
    private var alertOffer: Binding<Bool> {
        Binding { alerts.isOfferingAlerts } set: { alerts.isOfferingAlerts = $0 }
    }

    /// The reminder's pre-prompt (author's call, 2026-10-23), after the first transaction is saved.
    private var reminderOffer: Binding<Bool> {
        Binding { reminder.isOfferingReminder } set: { reminder.isOfferingReminder = $0 }
    }

    /// One offer at a time: budget alerts after a budget is saved, otherwise the daily reminder.
    private func offerNotifications() {
        Task {
            await alerts.offerIfNeeded()
            guard !alerts.isOfferingAlerts else { return }
            await reminder.offerIfNeeded()
        }
    }

    /// iOS 27 adds `.prominent`, the role meant for a primary action beside the tab bar; from iOS 27 on,
    /// only that role is drawn separately (a `.search` tab moves into the bar). iOS 26 draws `.search`
    /// separately. The compiler check lets Xcode 26 (CI) build without the iOS 27 SDK.
    private static var addTabRole: TabRole {
        #if compiler(>=6.4)
        if #available(iOS 27, *) {
            return .prominent
        }
        #endif
        return .search
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

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    PreviewEnvironment { RootView() }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewEnvironment { RootView() }
        .preferredColorScheme(.dark)
}
#endif

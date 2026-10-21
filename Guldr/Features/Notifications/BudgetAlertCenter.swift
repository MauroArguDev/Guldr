//
//  BudgetAlertCenter.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation
import GuldrCore
import Observation
import SwiftData

/// Budget notifications (v1 plan, Phase 25): after every data change it checks this month's budgets in
/// the active currency and sends each 80 % and 100 % alert once (`BudgetAlertLedger`). It owns the
/// "Budget alerts" preference and the one-time pre-prompt, and asks iOS for permission only when the
/// user says yes to it (author's call, 2026-10-21).
@Observable
final class BudgetAlertCenter {

    /// The Settings toggle: on only while the preference is on and iOS allows notifications.
    var isOn: Bool { isEnabled && permission == .allowed }
    private(set) var isEnabled: Bool
    private(set) var permission: NotificationPermission = .notDetermined
    /// Drives the pre-prompt alert in `RootView`.
    var isOfferingAlerts = false
    /// Bumped when the user taps an alert; `RootView` opens Budget.
    private(set) var openRequests = 0

    init(container: ModelContainer, settings: AppSettings, service: any NotificationService,
         locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent,
         now: @escaping () -> Date = { .now }) {
        self.container = container
        self.settings = settings
        self.service = service
        self.locale = locale
        self.timeZone = timeZone
        self.now = now
        isEnabled = settings.budgetAlertsEnabled
        service.onOpen = { [weak self] in self?.openRequests += 1 }
    }

    func refreshPermission() async {
        permission = await service.permission()
    }

    // MARK: - Alerts

    /// Called after every save through `DataChangeNotifier`. Sends what the month's budgets call for and
    /// remembers it; does nothing while alerts are off or not allowed.
    func evaluate() async {
        await refreshPermission()
        guard isOn, let currencyCode = settings.activeCurrencyCode else { return }
        let context = container.mainContext
        let month = YearMonth(containing: now(), timeZone: timeZone)
        let budgets = (try? context.fetch(FetchDescriptor<Budget>())) ?? []
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        guard let status = try? BudgetStatus(budgets: budgets, transactions: transactions, month: month,
                                             currencyCode: currencyCode, now: now(), timeZone: timeZone) else { return }
        var ledger = settings.budgetAlertLedger
        let alerts = ledger.dueAlerts(for: status)
        settings.setBudgetAlertLedger(ledger)
        guard !alerts.isEmpty else { return }

        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let names = Dictionary(categories.map { ($0.id, $0.displayName) }, uniquingKeysWith: { first, _ in first })
        for alert in alerts {
            let content = content(for: alert, categoryName: names[alert.categoryID])
            await service.deliver(identifier: content.identifier, title: content.title, body: content.body)
        }
    }

    /// A notification's identifier and text.
    struct AlertContent: Equatable {
        let identifier: String
        let title: String
        let body: String
    }

    /// The notification's text. Amounts only while the Face ID lock is off, since alerts can show on the
    /// iPhone's lock screen (author's call, 2026-10-21).
    func content(for alert: BudgetAlert, categoryName: String?) -> AlertContent {
        var monthStyle = Date.FormatStyle(locale: locale, timeZone: timeZone).month(.wide)
        monthStyle.capitalizationContext = .middleOfSentence
        let month = alert.month.dateInterval(in: timeZone).start.formatted(monthStyle)
        let formatter = MoneyFormatter(locale: locale)
        let spent = formatter.string(from: alert.spent, sign: .never)
        let limit = formatter.string(from: alert.limit, sign: .never)
        let percent = (Double(alert.threshold.rawValue) / 100)
            .formatted(.percent.precision(.fractionLength(0)).locale(locale))
        let showsAmounts = !settings.isLockEnabled

        let body = switch (alert.threshold, showsAmounts) {
        case (.nearing, true):
            String(localized: "You've used \(percent) of your \(month) budget: \(spent) of \(limit).", locale: locale)
        case (.nearing, false):
            String(localized: "You've used \(percent) of your \(month) budget.", locale: locale)
        case (.reached, true):
            String(localized: "You've reached your \(month) budget: \(spent) of \(limit).", locale: locale)
        case (.reached, false):
            String(localized: "You've reached your \(month) budget.", locale: locale)
        }
        let title = categoryName ?? String(localized: "Uncategorized", locale: locale)
        let identifier = "budget-\(alert.month.rawValue)-\(alert.categoryID.uuidString)-\(alert.threshold.rawValue)"
        return AlertContent(identifier: identifier, title: title, body: body)
    }

    // MARK: - Permission

    /// After a budget is saved: offers alerts once, while iOS hasn't been asked yet and there are budgets.
    func offerIfNeeded() async {
        guard !settings.hasOfferedBudgetAlerts,
              let budgets = try? container.mainContext.fetchCount(FetchDescriptor<Budget>()),
              budgets > 0 else { return }
        await refreshPermission()
        guard permission == .notDetermined else { return }
        settings.setHasOfferedBudgetAlerts()
        isOfferingAlerts = true
    }

    /// "Turn on" in the pre-prompt: now iOS asks.
    func acceptOffer() async {
        _ = await setEnabled(true)
    }

    /// The Settings toggle. Turning on asks iOS when it hasn't been asked; returns `false` when iOS
    /// doesn't allow notifications, so Settings can point to the Settings app.
    @discardableResult
    func setEnabled(_ isOn: Bool) async -> Bool {
        guard isOn else {
            settings.setBudgetAlertsEnabled(false)
            isEnabled = false
            return true
        }
        await refreshPermission()
        if permission == .notDetermined {
            _ = await service.requestPermission()
            await refreshPermission()
        }
        guard permission == .allowed else { return false }
        settings.setBudgetAlertsEnabled(true)
        isEnabled = true
        // Budgets already past a threshold this month alert now, not at the next save.
        await evaluate()
        return true
    }

    /// After "Delete all data", which clears the preferences and the ledger.
    func settingsDidReset() {
        isEnabled = settings.budgetAlertsEnabled
        isOfferingAlerts = false
        service.removeAllDelivered()
    }

    // MARK: - Private

    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let service: any NotificationService
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let timeZone: TimeZone
    @ObservationIgnored private let now: () -> Date
}

#if DEBUG
extension BudgetAlertCenter {
    /// Alerts over a throwaway defaults suite and a fake service, for previews.
    static func preview(container: ModelContainer) -> BudgetAlertCenter {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "preview.\(UUID().uuidString)") ?? .standard)
        return BudgetAlertCenter(container: container, settings: settings, service: FakeNotificationService())
    }
}
#endif

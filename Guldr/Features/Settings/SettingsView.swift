//
//  SettingsView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 16/10/26.
//

import GuldrCore
import SwiftData
import SwiftUI

/// Settings, pushed from the Dashboard's toolbar: a native `Form` with the active currency, which can be
/// changed, the Face ID lock and its grace period (ADR 011), the daily reminder and budget alerts, the
/// widgets' privacy, the categories, the CSV export, About and "Delete all data". Settings never shows a
/// control that does nothing (author's call, 2026-10-20). Debug builds also link to the design system
/// gallery from here.
struct SettingsView: View {

    @Environment(Preferences.self) private var preferences
    @Environment(AppLock.self) private var lock
    @Environment(BudgetAlertCenter.self) private var alerts
    @Environment(DailyReminderCenter.self) private var reminder
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Environment(\.dataChangeNotifier) private var notifier
    @State private var failedToSave = false
    @State private var confirmingDelete = false
    @State private var confirmingDeleteAgain = false
    @State private var failedToDelete = false
    @State private var lockError: LockError?

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    CurrencyPickerView(selection: currencySelection)
                } label: {
                    LabeledContent("Currency") {
                        Text(verbatim: currencyText)
                    }
                }
            } footer: {
                Text("Totals, budgets and charts use this currency. Transactions keep the currency they were saved in.")
            }

            lockSection

            NotificationSettings()

            widgetsSection

            Section {
                NavigationLink {
                    CategoriesView()
                } label: {
                    Text("Categories")
                }
                NavigationLink {
                    ExportView()
                } label: {
                    Text("Export transactions")
                }
            }

            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    Text("About")
                }
            }

            Section {
                Button("Delete all data", role: .destructive) {
                    confirmingDelete = true
                }
            } footer: {
                Text("Deletes your transactions, budgets and custom categories, and starts Guldr over.")
            }

            #if DEBUG
            Section {
                NavigationLink {
                    DesignSystemGallery()
                } label: {
                    Label {
                        Text(verbatim: "Design system gallery")
                    } icon: {
                        Image(systemName: "swatchpalette")
                    }
                }
            } header: {
                Text(verbatim: "Debug")
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(Color(.appBackground))
        .navigationTitle(Text("Settings"))
        .navigationBarTitleDisplayMode(.inline)
        // Two confirmations, as the plan asks for: the dialog says what goes, the alert that it's final.
        .confirmationDialog("Delete all data?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete all data", role: .destructive) {
                confirmingDeleteAgain = true
            }
        } message: {
            Text("Every transaction, budget and custom category on this iPhone is deleted, and Guldr returns to the welcome screen.")
        }
        .alert("Are you sure?", isPresented: $confirmingDeleteAgain) {
            Button("Delete everything", role: .destructive, action: deleteAllData)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your data can't be recovered.")
        }
        .alert("Couldn't delete your data", isPresented: $failedToDelete) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Nothing was deleted. Try again in a moment.")
        }
        .alert("Couldn't change the lock", isPresented: isShowingLockError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lockError == .unavailable ? "Set a passcode in the Settings app first."
                                           : "Your iPhone couldn't confirm it's you. Try again.")
        }
        .onAppear { lock.refreshAvailability() }
        // Back from the Settings app, where notifications may have been turned on.
        .task(id: scenePhase) {
            await alerts.refreshPermission()
            await reminder.refreshPermission()
        }
        .alert("Couldn't save your currency", isPresented: $failedToSave) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Choose another currency and try again.")
        }
    }

    /// The data goes first: if it fails, the currency and first launch stay as they were.
    private func deleteAllData() {
        do {
            try DataReset.eraseAll(in: context)
        } catch {
            failedToDelete = true
            return
        }
        preferences.reset()
        lock.settingsDidReset()
        alerts.settingsDidReset()
        Task { await reminder.settingsDidReset() }
        // After the preferences are gone, so the widget reloads into its "Open Guldr" state.
        notifier.dataDidChange()
    }

    /// The lock and, while it's on, how long the app may stay in the background. Disabled with a reason
    /// on a device without a passcode, unless it's already on, so it can still be turned off.
    private var lockSection: some View {
        Section {
            Toggle(isOn: lockSelection) {
                Text(lock.availability.biometry.lockTitle)
            }
            .tint(Color(.goldFill))
            .disabled(lock.isAuthenticating || (!lock.availability.canAuthenticate && !lock.isEnabled))
            if lock.isEnabled {
                Picker("Require", selection: gracePeriodSelection) {
                    ForEach(LockGracePeriod.allCases, id: \.self) { period in
                        Text(period.title)
                    }
                }
            }
        } header: {
            Text("Security")
        } footer: {
            if lock.availability.canAuthenticate || lock.isEnabled {
                Text("Guldr asks when it opens and when you come back after the time you choose. Your iPhone passcode works too.")
            } else {
                Text("Set a passcode in the Settings app to lock Guldr.")
            }
        }
    }

    /// Turning the lock on or off asks first (ADR 011); the toggle moves once the answer is in.
    private var lockSelection: Binding<Bool> {
        Binding {
            lock.isEnabled
        } set: { isOn in
            Task {
                do throws(LockError) {
                    if isOn {
                        try await lock.enable()
                    } else {
                        try await lock.disable()
                    }
                    // While the lock is on, the widget hides amounts.
                    notifier.dataDidChange()
                } catch .canceled {
                    return
                } catch {
                    lockError = error
                }
            }
        }
    }

    /// On and fixed while the lock is on, which always hides them (author's call, 2026-10-21).
    private var widgetsSection: some View {
        Section {
            Toggle("Hide amounts in widgets", isOn: hidesWidgetAmountsSelection)
                .tint(Color(.goldFill))
                .disabled(lock.isEnabled)
        } header: {
            Text("Widgets")
        } footer: {
            if lock.isEnabled {
                Text("While Guldr is locked with \(Text(lock.availability.biometry.lockTitle)), widgets always hide amounts.")
            } else {
                Text("Widgets also hide amounts while your iPhone is locked.")
            }
        }
    }

    private var hidesWidgetAmountsSelection: Binding<Bool> {
        Binding {
            lock.isEnabled || preferences.hidesWidgetAmounts
        } set: { hides in
            preferences.setHidesWidgetAmounts(hides)
            notifier.dataDidChange()
        }
    }

    private var gracePeriodSelection: Binding<LockGracePeriod> {
        Binding { lock.gracePeriod } set: { lock.setGracePeriod($0) }
    }

    private var isShowingLockError: Binding<Bool> {
        Binding { lockError != nil } set: { if !$0 { lockError = nil } }
    }

    private var activeCurrencyCode: String {
        preferences.activeCurrencyCode ?? Currency.defaultCode(for: locale)
    }

    /// The picker writes straight through `Preferences`, so every screen and the widget see the change.
    private var currencySelection: Binding<String> {
        Binding {
            activeCurrencyCode
        } set: { code in
            do {
                try preferences.setActiveCurrency(code)
                // The widget totals the active currency.
                notifier.dataDidChange()
            } catch {
                failedToSave = true
            }
        }
    }

    /// "US Dollar (USD)", as on the welcome screen.
    private var currencyText: String {
        let option = CurrencyOption.option(for: activeCurrencyCode, locale: locale)
        return "\(option.name) (\(option.code))"
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    PreviewEnvironment { NavigationStack { SettingsView() } }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewEnvironment { NavigationStack { SettingsView() } }
        .preferredColorScheme(.dark)
}
#endif

extension LockGracePeriod {

    /// Settings' "Require" picker.
    var title: LocalizedStringKey {
        switch self {
        case .immediately: "Immediately"
        case .oneMinute: "After 1 minute"
        case .fiveMinutes: "After 5 minutes"
        case .fifteenMinutes: "After 15 minutes"
        }
    }
}

//
//  NotificationSettings.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import GuldrCore
import SwiftUI
import UIKit

/// Settings' notifications: the daily reminder and its time (v1 plan, Phase 28), then budget alerts at
/// 80 % and 100 % (Phase 25), each with its own footer. When notifications are off for Guldr in the
/// Settings app, the toggles can't help, so a button opens that page instead.
struct NotificationSettings: View {

    @Environment(BudgetAlertCenter.self) private var alerts
    @Environment(DailyReminderCenter.self) private var reminder
    @Environment(\.openURL) private var openURL

    var body: some View {
        let isDenied = alerts.permission == .denied || reminder.permission == .denied
        Section {
            Toggle("Daily reminder", isOn: dailyReminderSelection)
                .tint(Color(.goldFill))
                .disabled(isDenied)
            if reminder.isOn {
                DatePicker("Time", selection: reminderTimeSelection, displayedComponents: .hourAndMinute)
            }
            if isDenied {
                Button("Turn on notifications in Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        openURL(url)
                    }
                }
                .tint(Color(.gold))
            }
        } header: {
            Text("Notifications")
        } footer: {
            if isDenied {
                Text("Notifications are off for Guldr in the Settings app.")
            } else {
                Text("One notification a day, skipped once something dated that day is logged.")
            }
        }
        Section {
            Toggle("Budget alerts", isOn: budgetAlertsSelection)
                .tint(Color(.goldFill))
                .disabled(isDenied)
        } footer: {
            Text("A notification when a category reaches 80% and 100% of its monthly budget.")
        }
    }

    private var dailyReminderSelection: Binding<Bool> {
        Binding {
            reminder.isOn
        } set: { isOn in
            Task { await reminder.setEnabled(isOn) }
        }
    }

    /// The picker works with a `Date`: today at the reminder's time, read back as hour and minute.
    private var reminderTimeSelection: Binding<Date> {
        Binding {
            Calendar.autoupdatingCurrent.date(bySettingHour: reminder.time.hour, minute: reminder.time.minute,
                                              second: 0, of: .now) ?? .now
        } set: { date in
            let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
            guard let time = ReminderTime(hour: components.hour ?? 0, minute: components.minute ?? 0) else { return }
            Task { await reminder.setTime(time) }
        }
    }

    private var budgetAlertsSelection: Binding<Bool> {
        Binding {
            alerts.isOn
        } set: { isOn in
            Task { await alerts.setEnabled(isOn) }
        }
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    PreviewEnvironment {
        Form { NotificationSettings() }
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewEnvironment {
        Form { NotificationSettings() }
    }
    .preferredColorScheme(.dark)
}
#endif

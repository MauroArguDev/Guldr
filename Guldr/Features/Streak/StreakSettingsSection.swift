//
//  StreakSettingsSection.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import SwiftUI

/// Settings › "Show streak", on by default (author's call, 2026-10-23). Off hides the chip, the widget
/// line and the reminder's streak copy; days are still recorded, so turning it back on loses nothing.
struct StreakSettingsSection: View {

    @Environment(StreakCenter.self) private var streak
    @Environment(\.dataChangeNotifier) private var notifier

    var body: some View {
        Section {
            Toggle("Show streak", isOn: isShown)
                .tint(Color(.goldFill))
        } footer: {
            Text("Hides the streak on Home, in the widget and in the daily reminder. Your logged days are kept.")
        }
    }

    private var isShown: Binding<Bool> {
        Binding {
            streak.isShown
        } set: { isShown in
            streak.setShown(isShown)
            // The widget and the reminder's copy follow.
            notifier.dataDidChange()
        }
    }
}

//
//  LaunchGate.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftUI
import UIKit
import WidgetKit

/// Shows first launch until it is completed, then the app. Shares `Preferences` and `AppLock` with
/// everything below, and keeps the lock informed of the scene's phase: the grace period starts in the
/// background and is checked on the way back, before anything is visible (ADR 011). The lock screen and
/// the privacy cover live in a window above this one (`LockOverlayWindow`). The daily reminder is brought
/// and the streak are brought up to date whenever the data, the scene or the clock changes.
struct LaunchGate: View {

    @State var preferences: Preferences
    @State var lock: AppLock
    @State var alerts: BudgetAlertCenter
    @State var reminder: DailyReminderCenter
    @State var streak: StreakCenter
    @State var inbox: NotificationInbox
    @State private var overlay = LockOverlayWindow()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if preferences.hasCompletedOnboarding {
                RootView()
                    .motionTransition(.opacity)
            } else {
                WelcomeView()
                    .motionTransition(.opacity)
            }
        }
        .motion(.standard, value: preferences.hasCompletedOnboarding)
        .background {
            WindowSceneReader { scene in
                overlay.install(in: scene, lock: lock)
            }
        }
        .onChange(of: scenePhase, initial: true) { old, new in
            sceneChanged(from: old, to: new)
        }
        .onChange(of: lock.isOverlayVisible, initial: true) { _, isVisible in
            overlay.setVisible(isVisible)
        }
        // A new day at midnight, a clock change or travel: today's reminder may need to come back or go.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            streak.refresh()
            Task { await reminder.reschedule() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            streak.refresh()
            Task { await reminder.reschedule() }
        }
        // Imports the history once, before the first reminder is scheduled with the streak's copy.
        .task { streak.start() }
        .environment(preferences)
        .environment(lock)
        .environment(alerts)
        .environment(reminder)
        .environment(streak)
        .environment(inbox)
        .environment(\.dataChangeNotifier, dataChangeNotifier)
    }

    /// Every save refreshes the streak and the widgets, checks budget alerts (ADR 007) and reschedules the
    /// daily reminder, since a logged today removes today's.
    private var dataChangeNotifier: DataChangeNotifier {
        DataChangeNotifier { [alerts, reminder, streak] in
            streak.refresh()
            WidgetCenter.shared.reloadAllTimelines()
            Task { await alerts.evaluate() }
            Task { await reminder.reschedule() }
        }
    }

    private func sceneChanged(from old: ScenePhase, to new: ScenePhase) {
        switch new {
        case .background:
            lock.didEnterBackground()
        case .inactive:
            // On the way back from the background the scene is inactive first: lock now, so the app's
            // content never shows before the lock screen.
            if old == .background { lock.willEnterForeground() }
        case .active:
            if old == .background { lock.willEnterForeground() }
            Task { await lock.sceneDidBecomeActive() }
            streak.refresh()
            Task { await reminder.reschedule() }
        @unknown default:
            break
        }
        lock.isSceneActive = new == .active
    }
}

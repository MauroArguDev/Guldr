//
//  GuldrApp.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 29/9/26.
//

import SwiftData
import SwiftUI

@main
struct GuldrApp: App {

    @State private var loader = AppDataLoader()
    /// Created with the app, so a tap on a notification that launches Guldr reaches its delegate.
    @State private var notifications = UserNotificationService()

    var body: some Scene {
        WindowGroup {
            switch loader.state {
            case .ready(let container, let settings):
                LaunchGate(preferences: Preferences(settings: settings),
                           lock: AppLock(settings: settings, service: LocalAuthenticationLockService()),
                           alerts: BudgetAlertCenter(container: container, settings: settings, service: notifications),
                           reminder: DailyReminderCenter(container: container, settings: settings,
                                                         service: notifications),
                           streak: StreakCenter(container: container, settings: settings),
                           achievements: AchievementCenter(container: container, settings: settings),
                           inbox: notifications.inbox)
                    .modelContainer(container)
            case .failed(let error):
                StoreErrorView(error: error, retry: loader.retry)
            }
        }
    }
}

//
//  LaunchGate.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftUI

/// Shows first launch until it is completed, then the app. Shares `Preferences` with everything below.
struct LaunchGate: View {

    @State var preferences: Preferences

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
        .environment(preferences)
    }
}

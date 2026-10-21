//
//  LaunchGate.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftUI

/// Shows first launch until it is completed, then the app. Shares `Preferences` and `AppLock` with
/// everything below, and keeps the lock informed of the scene's phase: the grace period starts in the
/// background and is checked on the way back, before anything is visible (ADR 011). The lock screen and
/// the privacy cover live in a window above this one (`LockOverlayWindow`).
struct LaunchGate: View {

    @State var preferences: Preferences
    @State var lock: AppLock
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
        .environment(preferences)
        .environment(lock)
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
        @unknown default:
            break
        }
        lock.isSceneActive = new == .active
    }
}

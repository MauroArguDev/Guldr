//
//  AppLock.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation
import GuldrCore
import Observation

/// The lock's state machine (ADR 011). It locks on launch when the lock is on, and again when the app
/// comes back after the grace period; `unlock()` asks the `LockService` and only a success opens.
///
/// It owns the lock preferences in `AppSettings`, like `Preferences` owns the currency, so turning the
/// lock on or off always goes through an authentication. The clock is injectable for tests.
@Observable
final class AppLock {

    enum State: Equatable {
        case unlocked
        case locked
    }

    private(set) var state: State
    private(set) var isEnabled: Bool
    private(set) var gracePeriod: LockGracePeriod
    /// A prompt is on screen. It makes the scene inactive, so the privacy cover waits until it's gone.
    private(set) var isAuthenticating = false
    /// Counts failed attempts, so the lock screen can play the `.error` haptic on each one.
    private(set) var failureCount = 0
    private(set) var availability: LockAvailability
    /// Whether the scene is active; `LaunchGate` keeps it current.
    var isSceneActive = true

    init(settings: AppSettings, service: any LockService, now: @escaping () -> Date = { .now }) {
        self.settings = settings
        self.service = service
        self.now = now
        isEnabled = settings.isLockEnabled
        gracePeriod = settings.lockGracePeriod
        availability = service.availability()
        // Always locked on launch while the lock is on.
        state = settings.isLockEnabled ? .locked : .unlocked
        promptsWhenActive = settings.isLockEnabled
    }

    var isLocked: Bool { state == .locked }

    /// The blurred privacy cover (ADR 011): while the lock is on and the app isn't in front, except
    /// while a prompt is up, since the prompt itself makes the scene inactive.
    var showsCover: Bool {
        isEnabled && !isSceneActive && !isAuthenticating
    }

    /// Whether the window above the app has anything to show.
    var isOverlayVisible: Bool { isLocked || showsCover }

    /// Reads the device's abilities again: Face ID can be enrolled or the passcode removed meanwhile.
    func refreshAvailability() {
        availability = service.availability()
    }

    // MARK: - Scene phases

    /// The app went to the background: the grace period starts now.
    func didEnterBackground() {
        backgroundedAt = now()
    }

    /// The app is coming back. Locks if the grace period has passed, before anything is visible.
    func willEnterForeground() {
        defer { backgroundedAt = nil }
        guard isEnabled, let backgroundedAt else { return }
        if now().timeIntervalSince(backgroundedAt) >= gracePeriod.duration {
            state = .locked
            promptsWhenActive = true
        }
    }

    /// The scene is in front. Asks on its own once after launch or a lock on return (author's call,
    /// 2026-10-21); a dismissed prompt also makes the scene active again, and that must not ask again.
    func sceneDidBecomeActive() async {
        guard promptsWhenActive else { return }
        promptsWhenActive = false
        await unlock()
    }

    // MARK: - Unlocking

    /// Asks once; a second call while a prompt is up does nothing. A cancel leaves the app locked. A
    /// device that can no longer authenticate (the passcode was removed, which itself needs the
    /// passcode) unlocks, so nobody is ever locked out of their own data.
    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        do throws(LockError) {
            try await authenticate()
            state = .unlocked
        } catch {
            // One `switch`, so the compiler checks every case (separate `catch` patterns aren't).
            switch error {
            case .canceled: break
            case .unavailable: state = .unlocked
            case .failed: failureCount += 1
            }
        }
    }

    // MARK: - Settings

    /// Turns the lock on after a successful authentication, so a device that can't authenticate never
    /// locks. Throws the reason it couldn't.
    func enable() async throws(LockError) {
        guard !isEnabled else { return }
        refreshAvailability()
        guard availability.canAuthenticate else { throw .unavailable }
        try await authenticate()
        settings.setLockEnabled(true)
        isEnabled = true
    }

    /// Turning it off also asks, so whoever holds an unlocked phone can't simply switch it off.
    func disable() async throws(LockError) {
        guard isEnabled else { return }
        do throws(LockError) {
            try await authenticate()
        } catch .unavailable {
            // Nothing can authenticate any more, so nothing is protected either: let it go.
        }
        settings.setLockEnabled(false)
        isEnabled = false
        state = .unlocked
    }

    func setGracePeriod(_ period: LockGracePeriod) {
        settings.setLockGracePeriod(period)
        gracePeriod = period
    }

    /// After "Delete all data", which clears every preference.
    func settingsDidReset() {
        isEnabled = settings.isLockEnabled
        gracePeriod = settings.lockGracePeriod
        state = .unlocked
        backgroundedAt = nil
        promptsWhenActive = false
    }

    // MARK: - Private

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let service: any LockService
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var backgroundedAt: Date?
    @ObservationIgnored private var promptsWhenActive: Bool

    private func authenticate() async throws(LockError) {
        isAuthenticating = true
        defer { isAuthenticating = false }
        try await service.authenticate(reason: String(localized: "Unlock your finances in Guldr."))
    }
}

#if DEBUG
extension AppLock {
    /// A lock over a throwaway defaults suite and a fake service, for previews.
    static func preview(locked: Bool, biometry: Biometry = .faceID) -> AppLock {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "preview.\(UUID().uuidString)") ?? .standard)
        settings.setLockEnabled(locked)
        let service = FakeLockService(result: .failure(.canceled),
                                      deviceAvailability: LockAvailability(canAuthenticate: true, biometry: biometry))
        return AppLock(settings: settings, service: service)
    }
}
#endif

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

    init(settings: AppSettings, service: any LockService, now: @escaping () -> Date = { .now }) {
        self.settings = settings
        self.service = service
        self.now = now
        isEnabled = settings.isLockEnabled
        gracePeriod = settings.lockGracePeriod
        availability = service.availability()
        // Always locked on launch while the lock is on.
        state = settings.isLockEnabled ? .locked : .unlocked
    }

    var isLocked: Bool { state == .locked }

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
        }
    }

    // MARK: - Unlocking

    /// Asks once; a second call while a prompt is up does nothing. A cancel leaves the app locked. A
    /// device that can no longer authenticate (the passcode was removed, which itself needs the
    /// passcode) unlocks, so nobody is ever locked out of their own data.
    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        do {
            try await authenticate()
            state = .unlocked
        } catch .canceled {
            return
        } catch .unavailable {
            state = .unlocked
        } catch .failed {
            failureCount += 1
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
        do {
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
    }

    // MARK: - Private

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let service: any LockService
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var backgroundedAt: Date?

    private func authenticate() async throws(LockError) {
        isAuthenticating = true
        defer { isAuthenticating = false }
        try await service.authenticate(reason: String(localized: "Unlock your finances in Guldr."))
    }
}

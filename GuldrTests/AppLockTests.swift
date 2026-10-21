//
//  AppLockTests.swift
//  GuldrTests
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation
import GuldrCore
import Testing
@testable import Guldr

/// The lock's state machine (ADR 011) with a scripted service and a clock the tests move by hand.
struct AppLockTests {

    // MARK: - Launch

    @Test func locksOnLaunchOnlyWhileEnabled() {
        withFixture(enabled: false) { fixture in
            #expect(!fixture.lock().isLocked)
        }
        withFixture(enabled: true) { fixture in
            #expect(fixture.lock().isLocked)
        }
    }

    @Test func asksOnItsOwnOnceAfterLaunch() async {
        await withFixture(enabled: true) { fixture in
            fixture.service.results = [.failure(.canceled)]
            let lock = fixture.lock()
            await lock.sceneDidBecomeActive()
            #expect(fixture.service.calls == 1)
            #expect(lock.isLocked)
            // Dismissing the prompt makes the scene active again; that must not ask again.
            await lock.sceneDidBecomeActive()
            #expect(fixture.service.calls == 1)

            await lock.unlock()
            #expect(fixture.service.calls == 2)
            #expect(!lock.isLocked)
        }
    }

    // MARK: - Grace period

    @Test func locksAgainOnceTheGracePeriodHasPassed() async {
        await withFixture(enabled: true) { fixture in
            let lock = fixture.lock()
            await lock.unlock()
            #expect(lock.gracePeriod == .oneMinute)

            lock.didEnterBackground()
            fixture.clock.advance(59)
            lock.willEnterForeground()
            #expect(!lock.isLocked)

            lock.didEnterBackground()
            fixture.clock.advance(60)
            lock.willEnterForeground()
            #expect(lock.isLocked)

            // The relock asks on its own once more.
            await lock.sceneDidBecomeActive()
            #expect(fixture.service.calls == 2)
        }
    }

    @Test func immediatelyLocksOnEveryReturn() async {
        await withFixture(enabled: true) { fixture in
            let lock = fixture.lock()
            lock.setGracePeriod(.immediately)
            await lock.unlock()
            lock.didEnterBackground()
            lock.willEnterForeground()
            #expect(lock.isLocked)
            #expect(fixture.settings.lockGracePeriod == .immediately)
        }
    }

    @Test func returningWithoutGoingToTheBackgroundKeepsItOpen() async {
        await withFixture(enabled: true) { fixture in
            let lock = fixture.lock()
            await lock.unlock()
            fixture.clock.advance(3_600)
            lock.willEnterForeground()
            #expect(!lock.isLocked)
        }
    }

    @Test func aDisabledLockNeverLocks() {
        withFixture(enabled: false) { fixture in
            let lock = fixture.lock()
            lock.setGracePeriod(.immediately)
            lock.didEnterBackground()
            lock.willEnterForeground()
            #expect(!lock.isLocked)
            #expect(!lock.showsCover)
        }
    }

    // MARK: - Unlocking

    @Test func aCancelStaysLockedWithoutAFailure() async {
        await withFixture(enabled: true) { fixture in
            fixture.service.results = [.failure(.canceled)]
            let lock = fixture.lock()
            await lock.unlock()
            #expect(lock.isLocked)
            #expect(lock.failureCount == 0)
            #expect(!lock.isAuthenticating)
        }
    }

    @Test func aFailureStaysLockedAndCounts() async {
        await withFixture(enabled: true) { fixture in
            fixture.service.results = [.failure(.failed), .failure(.failed)]
            let lock = fixture.lock()
            await lock.unlock()
            await lock.unlock()
            #expect(lock.isLocked)
            #expect(lock.failureCount == 2)
        }
    }

    @Test func aDeviceThatCanNoLongerAuthenticateUnlocks() async {
        await withFixture(enabled: true) { fixture in
            fixture.service.results = [.failure(.unavailable)]
            let lock = fixture.lock()
            await lock.unlock()
            #expect(!lock.isLocked)
        }
    }

    @Test func unlockingWhileOpenAsksNothing() async {
        await withFixture(enabled: false) { fixture in
            await fixture.lock().unlock()
            #expect(fixture.service.calls == 0)
        }
    }

    // MARK: - Settings

    @Test func turningItOnAsksFirst() async throws {
        try await withFixture(enabled: false) { fixture in
            fixture.service.results = [.failure(.canceled), .success(())]
            let lock = fixture.lock()
            await #expect(throws: LockError.canceled) { try await lock.enable() }
            #expect(!lock.isEnabled)
            #expect(!fixture.settings.isLockEnabled)

            try await lock.enable()
            #expect(lock.isEnabled)
            #expect(fixture.settings.isLockEnabled)
            // Turning it on doesn't lock the app that's open.
            #expect(!lock.isLocked)
        }
    }

    @Test func withoutAPasscodeItCantBeTurnedOn() async {
        await withFixture(enabled: false) { fixture in
            fixture.service.deviceAvailability = LockAvailability(canAuthenticate: false, biometry: .none)
            let lock = fixture.lock()
            await #expect(throws: LockError.unavailable) { try await lock.enable() }
            #expect(fixture.service.calls == 0)
            #expect(!lock.isEnabled)
        }
    }

    @Test func turningItOffAsksToo() async throws {
        try await withFixture(enabled: true) { fixture in
            fixture.service.results = [.success(()), .failure(.failed), .success(())]
            let lock = fixture.lock()
            await lock.unlock()
            await #expect(throws: LockError.failed) { try await lock.disable() }
            #expect(lock.isEnabled)

            try await lock.disable()
            #expect(!lock.isEnabled)
            #expect(!fixture.settings.isLockEnabled)
        }
    }

    @Test func theCoverShowsWhileTheLockIsOnAndTheAppIsntInFront() async throws {
        try await withFixture(enabled: false) { fixture in
            let lock = fixture.lock()
            lock.isSceneActive = false
            #expect(!lock.showsCover)

            try await lock.enable()
            #expect(lock.showsCover)
            #expect(lock.isOverlayVisible)
            lock.isSceneActive = true
            #expect(!lock.showsCover)
            #expect(!lock.isOverlayVisible)
        }
    }

    @Test func aResetTurnsItOff() {
        withFixture(enabled: true) { fixture in
            let lock = fixture.lock()
            lock.setGracePeriod(.fifteenMinutes)
            fixture.settings.reset()
            lock.settingsDidReset()
            #expect(!lock.isEnabled)
            #expect(!lock.isLocked)
            #expect(lock.gracePeriod == .oneMinute)
        }
    }

    // MARK: - Helpers

    private func withFixture(enabled: Bool, _ body: (Fixture) throws -> Void) rethrows {
        let suiteName = "GuldrTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create the defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        settings.setLockEnabled(enabled)
        try body(Fixture(settings: settings))
    }

    private func withFixture(enabled: Bool, _ body: (Fixture) async throws -> Void) async rethrows {
        let suiteName = "GuldrTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create the defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        settings.setLockEnabled(enabled)
        try await body(Fixture(settings: settings))
    }
}

// MARK: - Fixture

/// Answers each `authenticate` with the next scripted result, or success once the script runs out.
private final class ScriptedLockService: LockService {

    var results: [Result<Void, LockError>] = []
    var deviceAvailability = LockAvailability(canAuthenticate: true, biometry: .faceID)
    private(set) var calls = 0

    func availability() -> LockAvailability {
        deviceAvailability
    }

    func authenticate(reason: String) async throws(LockError) {
        calls += 1
        let result = results.isEmpty ? .success(()) : results.removeFirst()
        try result.get()
    }
}

private final class TestClock {
    private(set) var now = Date(timeIntervalSince1970: 1_792_540_800)

    func advance(_ seconds: TimeInterval) {
        now += seconds
    }
}

private struct Fixture {

    let settings: AppSettings
    let service = ScriptedLockService()
    let clock = TestClock()

    func lock() -> AppLock {
        AppLock(settings: settings, service: service, now: { [clock] in clock.now })
    }
}

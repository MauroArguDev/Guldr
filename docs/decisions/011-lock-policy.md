# 011 — Face ID lock policy

- **Status:** Accepted
- **Date:** 2026-10-21

## Context

Guldr holds a person's whole financial life on their iPhone. Anyone who picks up an unlocked phone, or glances at the app switcher, can read balances and transactions. v1 adds an optional lock (v1 plan, Phase 23; the Lock mockup). It has to be strong enough to matter, quick enough that people leave it on, and never a way to lose access to one's own data.

## Decision

**An optional lock, off by default, that uses the device owner's authentication (`LAPolicy.deviceOwnerAuthentication`): Face ID (or Touch ID on an iPhone SE), falling back to the iPhone passcode.**

- **When it locks:** always on launch, and on returning from the background after a grace period chosen in Settings: Immediately, 1 minute (the default), 5 minutes or 15 minutes (author's call, 2026-10-21). Time is measured from the moment the app went to the background.
- **Unlocking:** the lock screen asks on its own when it appears and when the app returns to the foreground locked; after a cancel, "Unlock with Face ID" and "Use iPhone passcode" stay for retrying (author's call, 2026-10-21). Both use the same policy: iOS has no public passcode-only policy, and `.deviceOwnerAuthentication` already moves to the passcode after Face ID fails or when it is unavailable, locked out or not enrolled. A cancel leaves the app locked with no haptic; a failure plays `.error` (DESIGN.md › Haptics).
- **Turning it on** (Settings or the welcome screen's toggle) requires a successful authentication first, so nobody locks themselves out with a device that can't authenticate. If the device has no passcode, the toggle is disabled with a reason. Turning it off also asks, so a person holding an unlocked phone can't simply switch it off.
- **Never locked out:** if the device can no longer authenticate while the lock is on (the passcode was removed, which itself needs the passcode), unlocking opens the app instead of failing.
- **Privacy cover:** while the lock is on and the scene is not active, the app is drawn blurred under a material, so the app switcher snapshot shows no readable amount (author's call, 2026-10-21). The cover steps aside while an authentication prompt is up, since that prompt itself makes the scene inactive.
- **Where it lives:** the setting and the grace period are stored in `AppSettings` (ADR 010), so the widget can respect the lock in Phase 24. The state machine (`AppLock`) is an `@Observable` main-actor class with an injectable clock; it talks to LocalAuthentication through a `LockService` protocol with one LocalAuthentication implementation and a fake for tests and previews. Errors are typed (`LockError`).
- **Nothing is encrypted by the lock.** It guards the interface. The store relies on iOS Data Protection, as before (ADR 007).

## Alternatives considered

- **Biometrics only (`.deviceOwnerAuthenticationWithBiometrics`)** — a failed or unavailable Face ID would leave people out of their own data; the passcode fallback is what iOS users expect.
- **A custom in-app PIN** — another secret to forget and to store safely, weaker than the device passcode, and more code that handles credentials.
- **A fixed grace period** — simpler, but "Immediately" annoys people who switch apps for a second and a long fixed value is too lax for others.
- **A solid cover instead of a blur** — hides as much, but the author preferred keeping the app recognizable in the switcher.
- **Encrypting the store with a key behind biometrics** — real protection at rest, but the widget could no longer read the store (ADR 007) and a lost key would mean lost data. Out of scope for v1.

## Consequences

- The app needs `NSFaceIDUsageDescription` in `Info.plist`.
- Every full-screen path (launch, foreground, deep links) goes through the lock first: `LaunchGate` overlays the lock screen on the app instead of replacing it, so the app keeps its state underneath.
- The widget shows amounts on the home screen even when the app is locked unless Phase 24's "Hide amounts in widgets" is on; that phase decides how the two settings interact.
- Tests drive `AppLock` with a fake service and a fake clock: launch, grace period, cancel, failure and unavailable authentication.

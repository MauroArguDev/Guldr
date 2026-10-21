//
//  LockService.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation
import LocalAuthentication

/// Why an authentication didn't unlock (ADR 011).
enum LockError: Error, Equatable {
    /// The user, the app or the system dismissed the prompt. Not a failure: no haptic, no message.
    case canceled
    /// Face ID and the passcode were tried and didn't match.
    case failed
    /// The device can't authenticate its owner: no passcode is set.
    case unavailable
}

/// The biometry the device offers, for the lock screen's and Settings' wording.
enum Biometry: Equatable, Sendable {
    case faceID
    case touchID
    case opticID
    /// No biometry enrolled or available; the passcode still works if one is set.
    case none
}

/// What the device can do right now. Read again whenever a screen appears: the user can enroll Face ID
/// or remove the passcode while the app is in the background.
struct LockAvailability: Equatable, Sendable {
    /// Whether `.deviceOwnerAuthentication` can run: there is a passcode, with or without biometry.
    let canAuthenticate: Bool
    let biometry: Biometry
}

/// The app's only door to LocalAuthentication, so the lock's state machine can be tested with a fake.
protocol LockService {
    func availability() -> LockAvailability
    /// Asks for Face ID (or Touch ID), falling back to the passcode. Returns once the owner is
    /// authenticated; throws otherwise.
    func authenticate(reason: String) async throws(LockError)
}

/// `LAContext` with `.deviceOwnerAuthentication`. A fresh context per call: a context remembers a
/// successful evaluation, and a new one makes every unlock ask again.
struct LocalAuthenticationLockService: LockService {

    func availability() -> LockAvailability {
        let context = LAContext()
        let canAuthenticate = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        // `biometryType` is only set after a `canEvaluatePolicy` call, and is `.none` until the user
        // enrolls a face or finger.
        let biometry: Biometry = switch context.biometryType {
        case .faceID: .faceID
        case .touchID: .touchID
        case .opticID: .opticID
        case .none: .none
        @unknown default: .none
        }
        return LockAvailability(canAuthenticate: canAuthenticate, biometry: biometry)
    }

    func authenticate(reason: String) async throws(LockError) {
        // A local value handed to LocalAuthentication once and never touched again, so passing this
        // non-Sendable context out of the main actor can't race.
        let context = LAContext()
        do {
            _ = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch let error as LAError {
            switch error.code {
            // `.notInteractive` means the app wasn't in front to show a prompt: try again later, never
            // treat it as a device that can't authenticate.
            case .userCancel, .appCancel, .systemCancel, .userFallback, .notInteractive:
                throw .canceled
            case .passcodeNotSet:
                throw .unavailable
            default:
                throw .failed
            }
        } catch {
            throw .failed
        }
    }
}

#if DEBUG
/// Answers with a fixed result, for previews and tests.
struct FakeLockService: LockService {

    var result: Result<Void, LockError> = .success(())
    var deviceAvailability = LockAvailability(canAuthenticate: true, biometry: .faceID)

    func availability() -> LockAvailability {
        deviceAvailability
    }

    func authenticate(reason: String) async throws(LockError) {
        try result.get()
    }
}
#endif

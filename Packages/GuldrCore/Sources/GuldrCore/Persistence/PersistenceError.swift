//
//  PersistenceError.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 10/10/26.
//

/// Why the store could not be opened (ADR 007). The app shows a calm error screen with a retry for
/// either case; it never crashes and never falls back to an empty in-memory store.
public enum PersistenceError: Error {
    /// The App Group ID is missing from Info.plist, or the system returned no container for it
    /// (usually a signing or entitlement problem).
    case appGroupUnavailable(String)
    /// Widget only: the app has not created the store yet, because it was never opened. Not a failure;
    /// the widget shows its empty state. A read-only open cannot create the file.
    case storeNotFound
    /// The container exists, but SwiftData could not open or prepare the store in it.
    case storeCreationFailed(underlying: any Error)
}

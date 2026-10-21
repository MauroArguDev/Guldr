//
//  LockGracePeriod.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation

/// How long the app may stay in the background before it locks again (ADR 011). Stored as seconds.
public enum LockGracePeriod: Int, CaseIterable, Codable, Sendable {
    case immediately = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900

    /// The author's default (2026-10-21): switching apps for a moment doesn't ask again.
    public static let `default` = LockGracePeriod.oneMinute

    public var duration: TimeInterval { TimeInterval(rawValue) }
}

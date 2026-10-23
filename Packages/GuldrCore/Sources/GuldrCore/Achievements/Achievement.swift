//
//  Achievement.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation

/// The families the gallery groups achievements by (ADR 013).
public enum AchievementFamily: String, CaseIterable, Sendable {
    case consistency
    case ledger
    case budget
    case reserve
}

public enum AchievementTier: Int, CaseIterable, Comparable, Sendable {
    case bronze = 1
    case silver
    case gold

    public static func < (lhs: AchievementTier, rhs: AchievementTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Every achievement, by a stable identifier that is stored in `EarnedAchievement`. Never rename a case.
public enum AchievementID: String, CaseIterable, Sendable {
    case unbroken
    case daysLogged
    case completeMonth
    case bookkeeper
    case withinBudget
    case steadyHand
    case saver
    case inTheBlack
}

/// What an achievement's value counts, for its progress text.
public enum AchievementUnit: Sendable {
    case days
    case months
    case transactions
    case percent
}

/// One achievement of the catalog: what it measures and the value each tier needs.
public struct Achievement: Identifiable, Equatable, Sendable {

    public let id: AchievementID
    public let family: AchievementFamily
    public let unit: AchievementUnit
    /// Bronze, silver and gold, ascending.
    public let thresholds: [Int]
    /// The SF Symbol on its medal.
    public let symbol: String

    /// The highest tier `value` reaches, if any.
    public func tier(for value: Int) -> AchievementTier? {
        AchievementTier.allCases.last { value >= threshold(for: $0) }
    }

    public func threshold(for tier: AchievementTier) -> Int {
        thresholds[tier.rawValue - 1]
    }

    /// The tier after `tier` (bronze for none), or `nil` after gold.
    public func nextTier(after tier: AchievementTier?) -> AchievementTier? {
        guard let tier else { return .bronze }
        return AchievementTier(rawValue: tier.rawValue + 1)
    }
}

/// The catalog (author's call, 2026-10-23; ADR 013). Adding an achievement is one entry here, its
/// measure in `AchievementEvaluator` and its tests.
public enum AchievementCatalog {

    public static let all: [Achievement] = [
        Achievement(id: .unbroken, family: .consistency, unit: .days, thresholds: [7, 30, 100], symbol: "flame.fill"),
        Achievement(id: .daysLogged, family: .consistency, unit: .days, thresholds: [30, 100, 365],
                    symbol: "calendar"),
        Achievement(id: .completeMonth, family: .ledger, unit: .months, thresholds: [1, 3, 12],
                    symbol: "book.closed.fill"),
        Achievement(id: .bookkeeper, family: .ledger, unit: .transactions, thresholds: [100, 500, 1_000],
                    symbol: "tray.full.fill"),
        Achievement(id: .withinBudget, family: .budget, unit: .months, thresholds: [1, 3, 12],
                    symbol: "chart.pie.fill"),
        Achievement(id: .steadyHand, family: .budget, unit: .months, thresholds: [2, 3, 6], symbol: "scope"),
        Achievement(id: .saver, family: .reserve, unit: .percent, thresholds: [10, 20, 30], symbol: "banknote.fill"),
        Achievement(id: .inTheBlack, family: .reserve, unit: .months, thresholds: [3, 6, 12],
                    symbol: "arrow.up.right")
    ]

    public static func achievement(_ id: AchievementID) -> Achievement {
        // Every id has an entry (covered by AchievementTests); the fallback only satisfies the type system.
        all.first { $0.id == id } ?? all[0]
    }
}

/// An achievement with its current value and the tier shown: the higher of the stored one and the one
/// the data reaches now, so deleting data never takes a medal back (ADR 013).
public struct AchievementProgress: Identifiable, Equatable, Sendable {

    public let achievement: Achievement
    public let value: Int
    public let tier: AchievementTier?
    /// When the shown tier was earned; `nil` while the data reaches it but it isn't stored yet.
    public let earnedAt: Date?

    public var id: AchievementID { achievement.id }

    /// The next tier to reach and its threshold, or `nil` after gold.
    public var nextTier: AchievementTier? { achievement.nextTier(after: tier) }

    /// From 0 to 1 toward the next tier, for its progress bar; 1 after gold.
    public var fractionToNext: Double {
        guard let next = nextTier else { return 1 }
        return min(1, Double(value) / Double(achievement.threshold(for: next)))
    }
}

/// A tier stored for an achievement (`EarnedAchievement`), or one to store.
public struct EarnedTier: Equatable, Sendable {
    public let id: AchievementID
    public let tier: AchievementTier
    public let earnedAt: Date

    public init(id: AchievementID, tier: AchievementTier, earnedAt: Date) {
        self.id = id
        self.tier = tier
        self.earnedAt = earnedAt
    }
}

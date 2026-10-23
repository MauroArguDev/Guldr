//
//  EarnedAchievement.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import SwiftData

extension SchemaV3 {

    /// A tier earned for an achievement (ADR 013). Kept even when the data that earned it is deleted;
    /// "Delete all data" removes it.
    ///
    /// CloudKit rules (ADR 007): every stored property has a default and nothing is unique. Several
    /// records for one achievement (a higher tier later, or two devices in v1.1) collapse to the highest.
    @Model
    public final class EarnedAchievement {

        public var id = UUID()
        /// `AchievementID.rawValue`.
        public var achievementID = ""
        /// `AchievementTier.rawValue`.
        public var tierRawValue = AchievementTier.bronze.rawValue
        public var earnedAt = Date.now

        public init(_ tier: EarnedTier) {
            achievementID = tier.id.rawValue
            tierRawValue = tier.tier.rawValue
            earnedAt = tier.earnedAt
        }

        /// `nil` for an achievement or tier this version doesn't know (written by a newer one).
        public var earnedTier: EarnedTier? {
            guard let id = AchievementID(rawValue: achievementID),
                  let tier = AchievementTier(rawValue: tierRawValue) else { return nil }
            return EarnedTier(id: id, tier: tier, earnedAt: earnedAt)
        }
    }
}

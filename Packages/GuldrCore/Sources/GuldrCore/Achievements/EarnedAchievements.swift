//
//  EarnedAchievements.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import SwiftData

/// Reading the store for achievements and recording what it newly earns (ADR 013).
public enum EarnedAchievements {

    /// Every stored tier this version understands.
    public static func all(in context: ModelContext) throws -> [EarnedTier] {
        try context.fetch(FetchDescriptor<EarnedAchievement>()).compactMap(\.earnedTier)
    }

    /// The values for every achievement, from the whole store.
    public static func values(in context: ModelContext, currencyCode: String, now: Date,
                              timeZone: TimeZone) throws -> [AchievementID: Int] {
        let input = AchievementEvaluator.Input(transactions: try context.fetch(FetchDescriptor<Transaction>()),
                                               budgets: try context.fetch(FetchDescriptor<Budget>()),
                                               loggedDays: try LoggedDays.all(in: context),
                                               currencyCode: currencyCode)
        return AchievementEvaluator.values(for: input, now: now, timeZone: timeZone)
    }

    /// Evaluates the store, stores the tiers newly reached and saves. Returns them, highest first within
    /// the catalog's order, for the unlock moments.
    @discardableResult
    public static func record(in context: ModelContext, currencyCode: String, now: Date,
                              timeZone: TimeZone) throws -> [EarnedTier] {
        let values = try values(in: context, currencyCode: currencyCode, now: now, timeZone: timeZone)
        let new = AchievementEvaluator.newlyEarned(values: values, earned: try all(in: context), at: now)
        guard !new.isEmpty else { return [] }
        for tier in new { context.insert(EarnedAchievement(tier)) }
        try context.save()
        return new
    }
}

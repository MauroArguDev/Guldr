//
//  SchemaV3.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import SwiftData

/// The third version of the store schema: `SchemaV2` plus `EarnedAchievement` (ADR 013). The existing
/// models didn't change, so they're listed as they are; adding a model is a lightweight stage.
public enum SchemaV3: VersionedSchema {

    public static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [Transaction.self, Category.self, Budget.self, LoggedDay.self, EarnedAchievement.self]
    }
}

public typealias EarnedAchievement = SchemaV3.EarnedAchievement

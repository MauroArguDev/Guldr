//
//  GuldrMigrationPlan.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 9/10/26.
//

import SwiftData

/// Every schema version, oldest first, and the stages between them.
///
/// It existed from day one so that the first model change would ship as a planned migration instead of a
/// store that fails to open. V1 → V2 adds `LoggedDay` (ADR 012): a new model with defaults only, so the
/// stage is lightweight and every existing row is kept.
public enum GuldrMigrationPlan: SchemaMigrationPlan {

    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    public static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}

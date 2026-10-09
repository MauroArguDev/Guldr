//
//  GuldrMigrationPlan.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 9/10/26.
//

import SwiftData

/// Every schema version, oldest first, and the stages between them.
///
/// Empty in v1. It exists from day one so that the first model change ships as a planned migration
/// instead of a store that fails to open.
public enum GuldrMigrationPlan: SchemaMigrationPlan {

    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}

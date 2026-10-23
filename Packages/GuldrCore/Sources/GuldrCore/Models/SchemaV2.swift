//
//  SchemaV2.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import SwiftData

/// The second version of the store schema: `SchemaV1` plus `LoggedDay` for the logging streak (ADR 012).
///
/// The three existing models didn't change, so both versions list the same classes; only the new model
/// is declared here. Adding a model is a lightweight migration (`GuldrMigrationPlan`).
public enum SchemaV2: VersionedSchema {

    public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [Transaction.self, Category.self, Budget.self, LoggedDay.self]
    }
}

public typealias LoggedDay = SchemaV2.LoggedDay

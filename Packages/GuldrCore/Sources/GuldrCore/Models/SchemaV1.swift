//
//  SchemaV1.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 9/10/26.
//

import SwiftData

/// The first version of the store schema (ADR 007).
///
/// Models are declared inside the versioned schema so that a future `SchemaV2` can copy them and a
/// migration stage can map one to the other. The rest of the code uses the unversioned aliases below.
public enum SchemaV1: VersionedSchema {

    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [Transaction.self, Category.self, Budget.self]
    }
}

// The current version of each model. A new schema version only needs to repoint these aliases.
public typealias Transaction = SchemaV1.Transaction
public typealias Category = SchemaV1.Category
public typealias Budget = SchemaV1.Budget

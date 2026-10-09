//
//  ModelTestSupport.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 9/10/26.
//

import Foundation
import SwiftData
@testable import GuldrCore

// Foundation re-exports the Objective-C runtime's `Category` typedef, so outside GuldrCore the bare name
// is ambiguous. A module-level alias wins over imported names. The app declares the same alias.
typealias Category = GuldrCore.Category

/// A fresh in-memory store per test, built from the versioned schema and migration plan the app uses.
func makeInMemoryContext() throws -> ModelContext {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: Schema(versionedSchema: SchemaV1.self),
                                       migrationPlan: GuldrMigrationPlan.self,
                                       configurations: configuration)
    return ModelContext(container)
}

func usd(_ minorUnits: Int64) throws -> Money {
    try Money(minorUnits: minorUnits, currencyCode: "USD")
}

//
//  CategorySeeder.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 9/10/26.
//

import Foundation
import SwiftData

/// Inserts the default categories that are missing, matched by `systemKey` (ADR 008).
///
/// Safe to call on every launch: running it again inserts nothing. Archived or renamed defaults still
/// count as present, so the user's changes are never undone. Seeded categories cannot be deleted, so a
/// missing key only means it was never inserted.
public enum CategorySeeder {

    /// Returns how many categories were inserted. Saves only when something changed.
    @discardableResult
    public static func seedDefaults(in context: ModelContext) throws -> Int {
        let seeded = try context.fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.systemKey != nil }))
        let existingKeys = Set(seeded.compactMap(\.systemKey))

        var inserted = 0
        for (index, defaultCategory) in DefaultCategory.all.enumerated()
        where !existingKeys.contains(defaultCategory.systemKey) {
            context.insert(Category(name: defaultCategory.name, symbolName: defaultCategory.symbolName,
                                    color: defaultCategory.color, kind: defaultCategory.kind, sortOrder: index,
                                    systemKey: defaultCategory.systemKey))
            inserted += 1
        }
        if inserted > 0 {
            try context.save()
        }
        return inserted
    }
}

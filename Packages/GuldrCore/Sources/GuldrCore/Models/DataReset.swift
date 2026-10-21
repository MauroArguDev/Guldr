//
//  DataReset.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation
import SwiftData

/// Settings › "Delete all data": the store as a first launch leaves it (author's call, 2026-10-20).
///
/// Transactions, budgets and custom categories are deleted. The default categories are restored rather
/// than recreated, so their identity survives: names, symbols, colors and order go back to the seeded
/// ones and none stays archived. A default the store lacks is seeded again. Everything happens in one
/// save; on failure the context is rolled back and nothing changes.
public enum DataReset {

    public enum ResetError: Error, Equatable {
        case saveFailed
    }

    public static func eraseAll(in context: ModelContext) throws(ResetError) {
        do {
            for transaction in try context.fetch(FetchDescriptor<Transaction>()) {
                context.delete(transaction)
            }
            for budget in try context.fetch(FetchDescriptor<Budget>()) {
                context.delete(budget)
            }
            var restoredKeys = Set<String>()
            for category in try context.fetch(FetchDescriptor<Category>()) {
                // Custom categories, a key a newer version wrote, and a second copy of a default go.
                guard let key = category.systemKey,
                      let index = DefaultCategory.all.firstIndex(where: { $0.systemKey == key }),
                      restoredKeys.insert(key).inserted else {
                    context.delete(category)
                    continue
                }
                let defaultCategory = DefaultCategory.all[index]
                category.name = defaultCategory.name
                category.symbolName = defaultCategory.symbolName
                category.color = defaultCategory.color
                category.kind = defaultCategory.kind
                category.sortOrder = index
                category.isArchived = false
            }
            for (index, defaultCategory) in DefaultCategory.all.enumerated()
            where !restoredKeys.contains(defaultCategory.systemKey) {
                context.insert(Category(name: defaultCategory.name, symbolName: defaultCategory.symbolName,
                                        color: defaultCategory.color, kind: defaultCategory.kind, sortOrder: index,
                                        systemKey: defaultCategory.systemKey))
            }
            try context.save()
        } catch {
            context.rollback()
            throw .saveFailed
        }
    }
}

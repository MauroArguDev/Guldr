//
//  DataResetTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation
import SwiftData
import Testing
@testable import GuldrCore

/// "Delete all data" leaves the store as a first launch does, keeping the defaults' identity.
struct DataResetTests {

    @Test func deletesTransactionsBudgetsAndCustomCategories() throws {
        let context = try seededContext()
        let food = try category("food", in: context)
        let pets = Category(name: "Pets", symbolName: "pawprint", color: .olive, kind: .expense, sortOrder: 11)
        context.insert(pets)
        context.insert(Transaction(amount: try usd(1_250), kind: .expense, category: food))
        context.insert(Transaction(amount: try usd(800), kind: .expense, category: pets))
        context.insert(Budget(month: YearMonth(year: 2026, month: 10)!, limit: try usd(40_000), category: food))
        context.insert(LoggedDay(day: LocalDay(year: 2026, month: 10, day: 23)!, source: .transaction))
        context.insert(EarnedAchievement(EarnedTier(id: .unbroken, tier: .gold, earnedAt: .now)))
        try context.save()

        try DataReset.eraseAll(in: context)

        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Budget>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<LoggedDay>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<EarnedAchievement>()) == 0)
        let remaining = try context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder)]))
        #expect(remaining.compactMap(\.systemKey) == DefaultCategory.all.map(\.systemKey))
        #expect(remaining.count == DefaultCategory.all.count)
    }

    @Test func restoresTheDefaultsInPlace() throws {
        let context = try seededContext()
        let food = try category("food", in: context)
        let salary = try category("salary", in: context)
        let id = food.id
        food.name = "Groceries"
        food.symbolName = "cart"
        food.color = .blue
        food.sortOrder = 9
        salary.isArchived = true
        try context.save()

        try DataReset.eraseAll(in: context)

        let restored = try category("food", in: context)
        #expect(restored.id == id)
        #expect(restored.name == "Food")
        #expect(restored.usesDefaultName)
        #expect(restored.symbolName == "fork.knife")
        #expect(restored.color == .terracotta)
        #expect(restored.sortOrder == 0)
        #expect(!(try category("salary", in: context)).isArchived)
    }

    @Test func seedsMissingDefaultsAndDropsDuplicates() throws {
        let context = try makeInMemoryContext()
        context.insert(Category(name: "Food", symbolName: "fork.knife", color: .terracotta, kind: .expense,
                                systemKey: "food"))
        context.insert(Category(name: "Food", symbolName: "fork.knife", color: .terracotta, kind: .expense,
                                systemKey: "food"))
        context.insert(Category(name: "Future", symbolName: "star", color: .gold, kind: .expense,
                                systemKey: "from_a_newer_version"))
        try context.save()

        try DataReset.eraseAll(in: context)

        let keys = try context.fetch(FetchDescriptor<Category>()).compactMap(\.systemKey)
        #expect(keys.sorted() == DefaultCategory.all.map(\.systemKey).sorted())
    }

    @Test func anEmptyStoreGetsTheDefaults() throws {
        let context = try makeInMemoryContext()
        try DataReset.eraseAll(in: context)
        #expect(try context.fetchCount(FetchDescriptor<Category>()) == DefaultCategory.all.count)
        // Seeding afterwards finds nothing to add.
        #expect(try CategorySeeder.seedDefaults(in: context) == 0)
    }

    // MARK: - Helpers

    private func seededContext() throws -> ModelContext {
        let context = try makeInMemoryContext()
        try CategorySeeder.seedDefaults(in: context)
        return context
    }

    private func category(_ systemKey: String, in context: ModelContext) throws -> Category {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.systemKey == systemKey })
        return try #require(try context.fetch(descriptor).first)
    }
}

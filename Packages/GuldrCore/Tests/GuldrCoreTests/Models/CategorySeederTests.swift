//
//  CategorySeederTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 9/10/26.
//

import Foundation
import SwiftData
import Testing
@testable import GuldrCore

struct CategorySeederTests {

    private func categories(in context: ModelContext) throws -> [Category] {
        try context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    @Test func seedsTheDefaultSet() throws {
        let context = try makeInMemoryContext()
        #expect(try CategorySeeder.seedDefaults(in: context) == 11)

        let seeded = try categories(in: context)
        #expect(seeded.compactMap(\.systemKey) == DefaultCategory.all.map(\.systemKey))
        #expect(seeded.filter { $0.kind == .expense }.count == 8)
        #expect(seeded.filter { $0.kind == .income }.count == 3)
        #expect(seeded.allSatisfy { $0.usesDefaultName })
        #expect(seeded.allSatisfy { !$0.isArchived })
    }

    @Test func seedingTwiceIsANoOp() throws {
        let context = try makeInMemoryContext()
        try CategorySeeder.seedDefaults(in: context)
        #expect(try CategorySeeder.seedDefaults(in: context) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Category>()) == 11)
    }

    @Test func userChangesSurviveReseeding() throws {
        let context = try makeInMemoryContext()
        try CategorySeeder.seedDefaults(in: context)
        let seeded = try categories(in: context)
        let food = try #require(seeded.first { $0.systemKey == "food" })
        let health = try #require(seeded.first { $0.systemKey == "health" })
        food.name = "Groceries"
        health.isArchived = true
        try context.save()

        #expect(try CategorySeeder.seedDefaults(in: context) == 0)
        #expect(food.name == "Groceries")
        #expect(!food.usesDefaultName)
        #expect(health.isArchived)
    }

    @Test func onlyMissingDefaultsAreInserted() throws {
        let context = try makeInMemoryContext()
        context.insert(Category(name: "Food", symbolName: "fork.knife", color: .terracotta, kind: .expense, systemKey: "food"))
        context.insert(Category(name: "Pets", symbolName: "pawprint", color: .olive, kind: .expense))
        try context.save()

        #expect(try CategorySeeder.seedDefaults(in: context) == 10)
        #expect(try context.fetchCount(FetchDescriptor<Category>()) == 12)
    }

    @Test func expenseDefaultsHaveDistinctColorsAndKeys() {
        let expenses = DefaultCategory.all.filter { $0.kind == .expense }
        #expect(Set(expenses.map(\.color)).count == expenses.count)
        #expect(Set(DefaultCategory.all.map(\.systemKey)).count == DefaultCategory.all.count)
    }

    @Test func customCategoriesNeverUseTheDefaultName() {
        let custom = Category(name: "Food", symbolName: "fork.knife", color: .terracotta, kind: .expense)
        #expect(!custom.usesDefaultName)
    }

    @Test func archivedCategoriesLeaveThePickerButKeepTheirHistory() throws {
        let context = try makeInMemoryContext()
        try CategorySeeder.seedDefaults(in: context)
        let health = try #require(try categories(in: context).first { $0.systemKey == "health" })
        let pharmacy = Transaction(amount: try usd(1825), kind: .expense, title: "Pharmacy", category: health)
        context.insert(pharmacy)
        health.isArchived = true
        try context.save()

        let expensePicker = try context.fetch(Category.pickable(.expense))
        #expect(expensePicker.count == 7)
        #expect(!expensePicker.contains { $0.systemKey == "health" })
        #expect(expensePicker.map(\.sortOrder) == expensePicker.map(\.sortOrder).sorted())
        #expect(try context.fetch(Category.pickable(.income)).count == 3)

        #expect(pharmacy.category?.systemKey == "health")
        #expect(health.transactions?.count == 1)
    }

    #if canImport(AppKit)
    @Test(arguments: DefaultCategory.all)
    func defaultSymbolsExist(category: DefaultCategory) {
        // SF Symbol names are strings; a typo would show an empty chip. Checked on macOS, which ships
        // the same symbol set as iOS for these names.
        #expect(NSImage(systemSymbolName: category.symbolName, accessibilityDescription: nil) != nil)
    }
    #endif
}

#if canImport(AppKit)
import AppKit

extension DefaultCategory: CustomTestStringConvertible {
    public var testDescription: String { systemKey }
}
#endif

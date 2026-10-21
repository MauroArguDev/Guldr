//
//  CategoriesTests.swift
//  GuldrTests
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation
import GuldrCore
import SwiftData
import Testing
@testable import Guldr

// The app's aliases are internal to the app module; the test module needs its own (ARCHITECTURE.md › Data).
private typealias Category = GuldrCore.Category
private typealias Transaction = GuldrCore.Transaction
private typealias Budget = GuldrCore.Budget

/// Settings › Categories: the list's order and archive rules, against an in-memory store with the
/// default categories.
struct CategoriesModelTests {

    @Test func listsOneKindInOrderWithArchivedApart() throws {
        let fixture = try Fixture()
        let model = fixture.model()
        #expect(model.active.map(\.name) == ["Food", "Transport", "Housing", "Health", "Shopping",
                                             "Entertainment", "Education", "Other"])
        #expect(model.archived.isEmpty)

        try model.setArchived(try fixture.id("health"), true, in: fixture.context)
        #expect(model.active.count == 7)
        #expect(model.archived.map(\.name) == ["Health"])

        model.kind = .income
        #expect(model.active.map(\.name) == ["Salary", "Freelance", "Other income"])
        #expect(model.archived.isEmpty)
    }

    @Test func reorderingRenumbersTheKind() throws {
        let fixture = try Fixture()
        let model = fixture.model()
        // Food (0) dropped after Transport: List reports offset 2 in the list before the move.
        try model.move(fromOffsets: IndexSet(integer: 0), toOffset: 2, in: fixture.context)
        #expect(model.active.prefix(3).map(\.name) == ["Transport", "Food", "Housing"])
        #expect(try fixture.pickableNames(.expense).prefix(3) == ["Transport", "Food", "Housing"])

        try model.move(fromOffsets: IndexSet(integer: 0), toOffset: 8, in: fixture.context)
        #expect(model.active.last?.name == "Transport")
        #expect(try fixture.category("transport").sortOrder == 7)
        // The other kind keeps its order.
        #expect(try fixture.pickableNames(.income) == ["Salary", "Freelance", "Other income"])
    }

    @Test func restoringPutsTheCategoryLast() throws {
        let fixture = try Fixture()
        let model = fixture.model()
        try model.setArchived(try fixture.id("food"), true, in: fixture.context)
        #expect(!(try fixture.pickableNames(.expense)).contains("Food"))

        try model.setArchived(try fixture.id("food"), false, in: fixture.context)
        #expect(model.active.last?.name == "Food")
        #expect(model.archived.isEmpty)
        #expect(try fixture.pickableNames(.expense).last == "Food")
    }

    @Test func theLastActiveCategoryOfAKindStays() throws {
        let fixture = try Fixture()
        let model = fixture.model()
        model.kind = .income
        try model.setArchived(try fixture.id("salary"), true, in: fixture.context)
        try model.setArchived(try fixture.id("freelance"), true, in: fixture.context)
        #expect(!model.canArchive)

        try model.setArchived(try fixture.id("other_income"), true, in: fixture.context)
        #expect(model.active.map(\.name) == ["Other income"])
        #expect(!(try fixture.category("other_income")).isArchived)
    }
}

/// The category sheet: creating, renaming, the name rules and which categories can be deleted.
struct CategoryEditorModelTests {

    @Test func createsACategoryAtTheEndOfItsKind() throws {
        let fixture = try Fixture()
        let editor = fixture.newEditor(.expense)
        #expect(!editor.canSave)

        editor.name = "  Pets "
        editor.symbolName = "pawprint"
        editor.color = .olive
        #expect(editor.canSave)
        try editor.save()

        let pets = try #require(try fixture.context.fetch(Category.pickable(.expense)).last)
        #expect(pets.name == "Pets")
        #expect(pets.symbolName == "pawprint")
        #expect(pets.color == .olive)
        #expect(pets.sortOrder == 8)
        #expect(pets.systemKey == nil)
        #expect(fixture.changes.calls == 0)
    }

    @Test func namesMustBeUniqueWithinAKind() throws {
        let fixture = try Fixture()
        let editor = fixture.newEditor(.expense)
        for taken in ["food", "FOOD", "Fóod", " Transport "] {
            editor.name = taken
            #expect(editor.isNameTaken, "\(taken)")
            #expect(!editor.canSave)
        }
        #expect(throws: CategoryEditorModel.EditorError.invalidName) { try editor.save() }

        editor.name = "   "
        #expect(!editor.isNameTaken)
        #expect(!editor.canSave)

        // Another kind's name is fine, and so is a category's own name.
        let income = fixture.newEditor(.income)
        income.name = "Food"
        #expect(income.canSave)
        let food = try fixture.editor("food")
        food.name = "FOOD"
        #expect(!food.isNameTaken)
    }

    @Test func anUntouchedDefaultNameKeepsFollowingTheLanguage() throws {
        let fixture = try Fixture()
        let editor = try fixture.editor("food")
        #expect(editor.isSystem)
        #expect(!editor.hasChanges)
        editor.symbolName = "cart"
        try editor.save()

        let food = try fixture.category("food")
        #expect(food.symbolName == "cart")
        #expect(food.name == "Food")
        #expect(food.usesDefaultName)
    }

    @Test func renamingADefaultStoresTheName() throws {
        let fixture = try Fixture()
        let editor = try fixture.editor("food")
        editor.name = "Groceries"
        editor.color = .green
        try editor.save()

        let food = try fixture.category("food")
        #expect(food.name == "Groceries")
        #expect(!food.usesDefaultName)
        #expect(food.color == .green)
        #expect(food.systemKey == "food")
    }

    @Test func defaultsAndCategoriesInUseCannotBeDeleted() throws {
        let fixture = try Fixture()
        let food = try fixture.editor("food")
        #expect(!food.canDelete)
        #expect(throws: CategoryEditorModel.EditorError.cannotDelete) { try food.delete() }

        let pets = try fixture.addCustom("Pets")
        fixture.context.insert(Transaction(amount: try Money(minorUnits: 800, currencyCode: "USD"), kind: .expense,
                                           category: pets))
        try fixture.context.save()
        #expect(!(try fixture.editor(pets.persistentModelID)).canDelete)
    }

    @Test func deletingAnUnusedCategoryTakesItsBudgets() throws {
        let fixture = try Fixture()
        let pets = try fixture.addCustom("Pets")
        fixture.context.insert(Budget(month: YearMonth(year: 2026, month: 10)!,
                                      limit: try Money(minorUnits: 5_000, currencyCode: "USD"), category: pets))
        try fixture.context.save()

        let editor = try fixture.editor(pets.persistentModelID)
        #expect(editor.canDelete)
        try editor.delete()

        #expect(!(try fixture.context.fetch(FetchDescriptor<Category>())).contains { $0.name == "Pets" })
        #expect(try fixture.context.fetchCount(FetchDescriptor<Budget>()) == 0)
        #expect(fixture.changes.calls == 1)
    }

    @Test func aDeletedCategoryCannotBeOpened() throws {
        let fixture = try Fixture()
        let pets = try fixture.addCustom("Pets")
        let id = pets.persistentModelID
        fixture.context.delete(pets)
        try fixture.context.save()
        #expect(throws: CategoryEditorModel.EditorError.notFound) { try fixture.editor(id) }
    }
}

// MARK: - Fixture

private final class ChangeCounter {
    var calls = 0
}

private struct Fixture {

    let context: ModelContext
    let changes = ChangeCounter()

    var notifier: DataChangeNotifier {
        DataChangeNotifier { [changes] in changes.calls += 1 }
    }

    init() throws {
        context = ModelContext(try PersistenceController(mode: .inMemory).container)
    }

    /// A list model fed with every category, as the view does on appear.
    func model() -> CategoriesModel {
        let model = CategoriesModel()
        model.update(categories: (try? context.fetch(FetchDescriptor<Category>())) ?? [])
        return model
    }

    func newEditor(_ kind: TransactionKind) -> CategoryEditorModel {
        CategoryEditorModel(kind: kind, context: context, notifier: notifier)
    }

    func editor(_ systemKey: String) throws -> CategoryEditorModel {
        try editor(try id(systemKey))
    }

    func editor(_ id: PersistentIdentifier) throws -> CategoryEditorModel {
        try CategoryEditorModel(editing: id, context: context, notifier: notifier)
    }

    func category(_ systemKey: String) throws -> Category {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.systemKey == systemKey })
        return try #require(try context.fetch(descriptor).first)
    }

    func id(_ systemKey: String) throws -> PersistentIdentifier {
        try category(systemKey).persistentModelID
    }

    /// What the add sheet offers, in its order.
    func pickableNames(_ kind: TransactionKind) throws -> [String] {
        try context.fetch(Category.pickable(kind)).map(\.name)
    }

    func addCustom(_ name: String) throws -> Category {
        let category = Category(name: name, symbolName: "pawprint", color: .olive, kind: .expense, sortOrder: 8)
        context.insert(category)
        try context.save()
        return category
    }
}

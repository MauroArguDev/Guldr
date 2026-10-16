//
//  AddTransactionViewModelTests.swift
//  GuldrTests
//
//  Created by Mauricio Argumedo on 15/10/26.
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

/// The add sheet's logic against an in-memory store with the default categories. UTC and a fixed "now"
/// (Sept 20, 2026) keep month boundaries independent of the machine running the tests.
struct AddTransactionViewModelTests {

    private typealias Model = AddTransactionViewModel

    private let utc = TimeZone(identifier: "UTC")!
    private let september = YearMonth(year: 2026, month: 9)!

    // MARK: - Input

    @Test func startsEmptyWithExpenseCategories() throws {
        let fixture = try Fixture()
        let model = try fixture.newModel()
        #expect(model.kind == .expense)
        #expect(model.amount.isEmpty)
        #expect(model.issues == [.missingAmount, .missingCategory])
        #expect(!model.canSave)
        #expect(!model.hasChanges)
        #expect(!model.isEditing)
        #expect(model.titlePrompt == nil)
        #expect(model.categories.map(\.systemKey) == ["food", "transport", "housing", "health", "shopping",
                                                       "entertainment", "education", "other_expense"])
    }

    @Test func unknownCurrencyCannotOpen() throws {
        let fixture = try Fixture()
        #expect(throws: Model.EditorError.invalidCurrency) {
            try Model(context: fixture.context, currencyCode: "XYZ", notifier: fixture.notifier)
        }
    }

    @Test(arguments: [(false, false), (true, false), (false, true), (true, true)])
    func issuesListWhatIsMissing(hasAmount: Bool, hasCategory: Bool) throws {
        let fixture = try Fixture()
        let model = try fixture.newModel()
        if hasAmount { model.pressDigit(5) }
        if hasCategory { model.select(try fixture.category("food")) }
        var expected: Set<Model.Issue> = []
        if !hasAmount { expected.insert(.missingAmount) }
        if !hasCategory { expected.insert(.missingCategory) }
        #expect(model.issues == expected)
        #expect(model.canSave == (hasAmount && hasCategory))
    }

    @Test func keypadIgnoresLeadingZerosAndExtraDecimals() throws {
        let model = try Fixture().newModel()
        let leadingZeros = [model.pressDigit(0), model.pressDigit(0)]
        #expect(leadingZeros == [false, false])
        model.pressDigit(4)
        model.pressDigit(2)
        #expect(model.pressDecimalSeparator())
        #expect(!model.pressDecimalSeparator())
        model.pressDigit(8)
        model.pressDigit(0)
        #expect(!model.pressDigit(1))      // USD has two decimals
        #expect(model.amount.minorUnits == 4_280)
        #expect(model.pressDelete())
        #expect(model.amount.minorUnits == 4_280)   // "42.8" is still 4,280 cents
        #expect(model.amount.formattedText(locale: Locale(identifier: "en_US")) == "$42.8")
    }

    @Test func keypadStopsAtTenIntegerDigits() throws {
        let model = try Fixture().newModel()
        let accepted = (1...10).map { _ in model.pressDigit(9) }
        #expect(accepted.allSatisfy { $0 })
        #expect(!model.pressDigit(9))
        #expect(model.amount.minorUnits == 999_999_999_900)
    }

    @Test func currenciesWithoutCentsHaveNoDecimalKey() throws {
        let model = try Fixture().newModel(currencyCode: "JPY")
        #expect(!model.acceptsDecimals)
        #expect(!model.pressDecimalSeparator())
        model.pressDigit(5)
        #expect(model.amount.minorUnits == 5)
    }

    @Test func switchingKindKeepsTheAmountAndDropsTheCategory() throws {
        let fixture = try Fixture()
        let model = try fixture.newModel()
        model.pressDigit(7)
        model.select(try fixture.category("food"))
        model.setKind(.income)
        #expect(model.amount.minorUnits == 700)
        #expect(model.category == nil)
        #expect(model.categories.map(\.systemKey) == ["salary", "freelance", "other_income"])
        // A category of the other kind is ignored.
        model.select(try fixture.category("food"))
        #expect(model.category == nil)
    }

    // MARK: - Save

    @Test func savesANewTransaction() throws {
        let fixture = try Fixture()
        let model = try fixture.newModel()
        let food = try fixture.category("food")
        model.pressDigit(1)
        model.pressDigit(2)
        model.select(food)
        model.title = "  Groceries \n"
        model.date = fixture.now

        #expect(model.hasChanges)
        #expect(try model.save() == .saved)

        let saved = try #require(try fixture.transactions().first)
        #expect(try fixture.transactions().count == 1)
        #expect(saved.amount == (try Money(minorUnits: 1_200, currencyCode: "USD")))
        #expect(saved.kind == .expense)
        #expect(saved.title == "Groceries")
        #expect(saved.category == food)
        #expect(saved.date == fixture.now)
        #expect(fixture.changes.calls == 1)
    }

    @Test func anEmptyDescriptionIsStoredEmptyAndShownAsTheCategory() throws {
        let fixture = try Fixture()
        let model = try fixture.newModel()
        model.pressDigit(3)
        model.select(try fixture.category("transport"))
        #expect(model.titlePrompt == "Transport")
        try model.save()
        #expect(try fixture.transactions().first?.title == "")
    }

    @Test func anIncompleteSaveChangesNothing() throws {
        let fixture = try Fixture()
        let model = try fixture.newModel()
        model.pressDigit(3)
        #expect(throws: Model.EditorError.incomplete) {
            try model.save()
        }
        #expect(try fixture.transactions().isEmpty)
        #expect(fixture.changes.calls == .zero)
    }

    // MARK: - Budget warning

    @Test func crossingABudgetIsReported() throws {
        let fixture = try Fixture()
        let food = try fixture.category("food")
        try fixture.addBudget(10_000, for: food, month: september)
        try fixture.addExpense(9_000, food, on: fixture.now)

        let model = try fixture.newModel()
        model.pressDigit(1)
        model.pressDigit(0)
        model.pressDecimalSeparator()
        model.pressDigit(0)
        model.pressDigit(1)          // $10.01 takes Food to $100.01 of $100.00
        model.select(food)
        #expect(try model.save() == .crossedBudget)
    }

    @Test(arguments: [
        (9_000, 1_000, Model.SaveOutcome.saved),    // exactly the limit is not over
        (11_000, 500, .saved),                       // already over before this save
        (0, 500, .saved)                             // well within
    ])
    func onlyANewCrossingIsReported(existing: Int64, added: Int, expected: AddTransactionViewModel.SaveOutcome) throws {
        let fixture = try Fixture()
        let food = try fixture.category("food")
        try fixture.addBudget(10_000, for: food, month: september)
        if existing > 0 { try fixture.addExpense(existing, food, on: fixture.now) }

        let model = try fixture.newModel()
        for digit in String(added / 100) { model.pressDigit(Int(String(digit)) ?? 0) }
        model.select(food)
        #expect(try model.save() == expected)
    }

    @Test func incomeOtherMonthsAndUnbudgetedCategoriesNeverWarn() throws {
        let fixture = try Fixture()
        let food = try fixture.category("food")
        try fixture.addBudget(1_000, for: food, month: september)

        let unbudgeted = try fixture.newModel()
        unbudgeted.pressDigit(9)
        unbudgeted.pressDigit(9)
        unbudgeted.select(try fixture.category("shopping"))
        #expect(try unbudgeted.save() == .saved)

        let otherMonth = try fixture.newModel()
        otherMonth.pressDigit(9)
        otherMonth.pressDigit(9)
        otherMonth.select(food)
        otherMonth.date = try fixture.date("2026-08-15T12:00:00Z")
        #expect(try otherMonth.save() == .saved)

        let income = try fixture.newModel(kind: .income)
        income.pressDigit(9)
        income.pressDigit(9)
        income.select(try fixture.category("salary"))
        #expect(try income.save() == .saved)
    }

    // MARK: - Edit and delete

    @Test func editingPrefillsAndUpdatesInPlace() throws {
        let fixture = try Fixture()
        let food = try fixture.category("food")
        let original = try fixture.addExpense(4_280, food, on: fixture.now, title: "Groceries")
        let createdAt = original.updatedAt

        let model = try fixture.editModel(original)
        #expect(model.isEditing)
        #expect(!model.hasChanges)
        #expect(model.amount.formattedText(locale: Locale(identifier: "en_US")) == "$42.80")
        #expect(model.category == food)
        #expect(model.title == "Groceries")
        #expect(model.date == fixture.now)

        model.pressDelete()
        model.pressDigit(5)
        model.select(try fixture.category("shopping"))
        #expect(model.hasChanges)
        try model.save()

        #expect(try fixture.transactions().count == 1)
        #expect(original.amount.minorUnits == 4_285)
        #expect(original.category?.systemKey == "shopping")
        #expect(original.updatedAt >= createdAt)
        #expect(fixture.changes.calls == 1)
    }

    @Test func editingKeepsItsCurrencyAndArchivedCategory() throws {
        let fixture = try Fixture()
        let food = try fixture.category("food")
        let original = try fixture.addExpense(500, food, on: fixture.now, currency: "EUR")
        food.isArchived = true
        try fixture.context.save()

        let model = try fixture.editModel(original)
        #expect(model.amount.currencyCode == "EUR")
        #expect(model.categories.contains(food))
        #expect(model.category == food)
        #expect(try fixture.newModel().categories.contains(food) == false)
    }

    @Test func deleteRemovesTheTransaction() throws {
        let fixture = try Fixture()
        let original = try fixture.addExpense(500, try fixture.category("food"), on: fixture.now)
        let model = try fixture.editModel(original)
        try model.delete()
        #expect(try fixture.transactions().isEmpty)
        #expect(fixture.changes.calls == 1)
    }

    @Test func aDeletedTransactionCannotBeOpened() throws {
        let fixture = try Fixture()
        let original = try fixture.addExpense(500, try fixture.category("food"), on: fixture.now)
        let id = original.persistentModelID
        fixture.context.delete(original)
        try fixture.context.save()
        #expect(throws: Model.EditorError.transactionNotFound) {
            try Model(editing: id, context: fixture.context, notifier: fixture.notifier)
        }
    }

    @Test func deleteDoesNothingWhileAdding() throws {
        let fixture = try Fixture()
        try fixture.addExpense(500, try fixture.category("food"), on: fixture.now)
        try fixture.newModel().delete()
        #expect(try fixture.transactions().count == 1)
        #expect(fixture.changes.calls == .zero)
    }

    // MARK: - Router

    @Test func finishingASaveClosesTheSheetAndRecordsEachSave() {
        let router = AppRouter()
        router.present(.addTransaction)
        router.finishSave(.crossedBudget)
        #expect(router.sheet == nil)
        let first = router.lastSave
        #expect(first?.outcome == .crossedBudget)
        router.finishSave(.crossedBudget)
        #expect(router.lastSave != first)   // a repeated outcome still triggers the haptic
    }
}

// MARK: - Fixture

/// Counts data-change notifications. A class, so the notifier's closure and the test share it.
private final class ChangeCounter {
    var calls = 0
}

private struct Fixture {

    let context: ModelContext
    let changes = ChangeCounter()
    let timeZone = TimeZone(identifier: "UTC")!
    let now: Date

    var notifier: DataChangeNotifier {
        DataChangeNotifier { [changes] in changes.calls += 1 }
    }

    init() throws {
        context = ModelContext(try PersistenceController(mode: .inMemory).container)
        now = try #require(ISO8601DateFormatter().date(from: "2026-09-20T12:00:00Z"))
    }

    func newModel(currencyCode: String = "USD", kind: TransactionKind = .expense) throws -> AddTransactionViewModel {
        try AddTransactionViewModel(context: context, currencyCode: currencyCode, kind: kind, notifier: notifier,
                                    now: now, timeZone: timeZone)
    }

    func editModel(_ transaction: Transaction) throws -> AddTransactionViewModel {
        try AddTransactionViewModel(editing: transaction.persistentModelID, context: context, notifier: notifier,
                                    timeZone: timeZone)
    }

    func category(_ systemKey: String) throws -> Category {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.systemKey == systemKey })
        return try #require(try context.fetch(descriptor).first)
    }

    func transactions() throws -> [Transaction] {
        try context.fetch(FetchDescriptor<Transaction>())
    }

    func date(_ iso: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: iso))
    }

    @discardableResult
    func addExpense(_ cents: Int64, _ category: Category, on date: Date, title: String = "",
                    currency: String = "USD") throws -> Transaction {
        let transaction = Transaction(amount: try Money(minorUnits: cents, currencyCode: currency), kind: .expense,
                                      title: title, date: date, category: category)
        context.insert(transaction)
        try context.save()
        return transaction
    }

    func addBudget(_ cents: Int64, for category: Category, month: YearMonth) throws {
        context.insert(Budget(month: month, limit: try Money(minorUnits: cents, currencyCode: "USD"), category: category))
        try context.save()
    }
}

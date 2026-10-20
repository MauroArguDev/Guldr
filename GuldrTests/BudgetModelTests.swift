//
//  BudgetModelTests.swift
//  GuldrTests
//
//  Created by Mauricio Argumedo on 20/10/26.
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

/// The Budget screen's mapping and the edit sheet against an in-memory store with the default categories.
/// UTC, US English and a fixed "now" (Oct 16, 2026, noon: 15 days left in the month) keep months and
/// texts stable.
struct BudgetModelTests {

    private let october = YearMonth(year: 2026, month: 10)!

    // MARK: - Month navigation

    @Test func startsAtTheCurrentMonthAndStopsAtNextMonth() throws {
        let model = try Fixture().model()
        #expect(model.month == october)
        #expect(model.monthTitle == "October 2026")
        #expect(model.canShowNextMonth)

        model.showNextMonth()
        #expect(model.month == october.next)
        #expect(!model.canShowNextMonth)
        model.showNextMonth()
        #expect(model.month == october.next)
    }

    @Test func goesBackWithoutLimit() throws {
        let model = try Fixture().model()
        for _ in 0..<24 { model.showPreviousMonth() }
        #expect(model.month == YearMonth(year: 2024, month: 10))
        #expect(model.canShowNextMonth)
    }

    // MARK: - Status mapping

    @Test func overviewAddsUpTheMonthsBudgets() throws {
        let fixture = try Fixture()
        try fixture.add(10_000, "food", "2026-10-15T09:00:00Z")
        try fixture.add(9_999, "food", "2026-09-15T09:00:00Z")      // last month
        try fixture.addBudget(40_000, "food")
        try fixture.addBudget(20_000, "transport")
        let model = try fixture.model(refreshed: true)

        let overview = try #require(model.overview)
        #expect(overview.spent.minorUnits == 10_000)
        #expect(overview.limit.minorUnits == 60_000)
        #expect(overview.remaining.minorUnits == 50_000)
        #expect(abs(overview.usage - 1.0 / 6) < 0.000_1)
        #expect(overview.detail == "17% used · 15 days left")
        #expect(model.alerts.isEmpty)
        #expect(model.rows.map(\.name) == ["Food", "Transport"])
        #expect(model.rows.first?.symbol == (try fixture.category("food")).symbolName)
    }

    @Test func overBudgetCategoriesGetAnAlert() throws {
        let fixture = try Fixture()
        try fixture.add(50_000, "food", "2026-10-15T09:00:00Z")
        try fixture.add(21_000, "transport", "2026-10-15T10:00:00Z")
        try fixture.addBudget(40_000, "food")
        try fixture.addBudget(20_000, "transport")
        try fixture.addBudget(30_000, "housing")
        let model = try fixture.model(refreshed: true)

        // Highest usage first: food 125 %, transport 105 %.
        #expect(model.alerts.map(\.categoryName) == ["Food", "Transport"])
        #expect(model.alerts.map(\.overAmount.minorUnits) == [10_000, 1_000])
        #expect(model.rows.map(\.name) == ["Food", "Transport", "Housing"])
        #expect(model.overview?.detail == "79% used · 15 days left")
    }

    @Test func pastMonthsShowOnlyTheUsageAndNextMonthCountsAllItsDays() throws {
        let fixture = try Fixture()
        try fixture.add(20_000, "food", "2026-09-15T09:00:00Z")
        try fixture.addBudget(40_000, "food", month: october.previous)
        try fixture.addBudget(40_000, "food", month: october.next)
        let model = try fixture.model()

        model.showPreviousMonth()
        fixture.refresh(model)
        #expect(model.overview?.detail == "50% used")

        model.showNextMonth()
        model.showNextMonth()
        fixture.refresh(model)
        #expect(model.overview?.detail == "0% used · 30 days left")
    }

    @Test func otherCurrenciesAreLeftOut() throws {
        let fixture = try Fixture()
        try fixture.addBudget(40_000, "food", currency: "EUR")
        let model = try fixture.model(refreshed: true)
        #expect(model.overview == nil)
        #expect(model.rows.isEmpty)
    }

    @Test func anEmptyMonthOffersToCopyLastMonth() throws {
        let fixture = try Fixture()
        let model = try fixture.model(refreshed: true)
        #expect(model.overview == nil)
        #expect(!model.canCopyLastMonth)

        try fixture.addBudget(40_000, "food", month: october.previous)
        fixture.refresh(model)
        #expect(model.overview == nil)
        #expect(model.canCopyLastMonth)
    }

    // MARK: - Edit sheet

    @Test func editorListsExpenseCategoriesWithTheirLimits() throws {
        let fixture = try Fixture()
        try fixture.addBudget(40_000, "food")
        try fixture.addBudget(4_250, "transport")
        try fixture.addBudget(9_999, "health", month: october.previous)
        let editor = try fixture.editor()

        let expense = try fixture.context.fetch(Category.pickable(.expense)).map(\.id)
        #expect(editor.fields.map(\.id) == expense)
        #expect(try fixture.text(in: editor, for: "food") == "400")
        #expect(try fixture.text(in: editor, for: "transport") == "42.50")
        #expect(try fixture.text(in: editor, for: "health") == "")
        #expect(editor.total?.minorUnits == 44_250)
        #expect(editor.canCopyLastMonth)
        #expect(!editor.hasChanges)
        #expect(!editor.canSave)
    }

    @Test(arguments: ["0", "abc", "-5", "12.345", "12345678901"])
    func invalidAmountsBlockTheSave(text: String) throws {
        let fixture = try Fixture()
        let editor = try fixture.editor()
        try fixture.setText(text, in: editor, for: "food")
        #expect(editor.invalidFieldIDs == [try fixture.category("food").id])
        #expect(!editor.canSave)
        #expect(throws: EditBudgetModel.EditorError.invalidAmounts) { try editor.save() }
    }

    @Test func amountsAreReadInTheUsersLocale() throws {
        let fixture = try Fixture()
        let editor = try fixture.editor(locale: Locale(identifier: "es_ES"))
        try fixture.setText("1.250,5", in: editor, for: "food")
        try editor.save()
        #expect(try fixture.budgets().map(\.limitMinorUnits) == [125_050])
    }

    @Test func savingInsertsUpdatesAndRemoves() throws {
        let fixture = try Fixture()
        try fixture.addBudget(40_000, "food")
        try fixture.addBudget(20_000, "transport")
        let editor = try fixture.editor()

        try fixture.setText("450", in: editor, for: "food")         // update
        try fixture.setText("", in: editor, for: "transport")       // remove
        try fixture.setText("1,200.75", in: editor, for: "housing") // insert
        #expect(editor.canSave)
        try editor.save()

        let limits = try fixture.budgets().reduce(into: [String: Int64]()) { result, budget in
            result[budget.category?.systemKey ?? ""] = budget.limitMinorUnits
        }
        #expect(limits == ["food": 45_000, "housing": 120_075])
        #expect(try fixture.budgets().allSatisfy { $0.yearMonth == october.rawValue && $0.currencyCode == "USD" })
        #expect(fixture.changes.calls == 1)
    }

    @Test func savingRemovesDuplicateBudgets() throws {
        let fixture = try Fixture()
        try fixture.addBudget(40_000, "food")
        try fixture.addBudget(30_000, "food")
        let editor = try fixture.editor()
        try fixture.setText("500", in: editor, for: "food")
        try editor.save()
        #expect(try fixture.budgets().map(\.limitMinorUnits) == [50_000])
    }

    @Test func copyingLastMonthReplacesTheFields() throws {
        let fixture = try Fixture()
        try fixture.addBudget(40_000, "food", month: october.previous)
        try fixture.addBudget(15_000, "health", month: october.previous)
        try fixture.addBudget(20_000, "transport")
        let editor = try fixture.editor()

        editor.copyLastMonth()
        #expect(try fixture.text(in: editor, for: "food") == "400")
        #expect(try fixture.text(in: editor, for: "health") == "150")
        #expect(try fixture.text(in: editor, for: "transport") == "")
        #expect(fixture.changes.calls == 0)

        try editor.save()
        let thisMonth = try fixture.budgets().filter { $0.yearMonth == october.rawValue }
        #expect(thisMonth.map(\.limitMinorUnits).sorted() == [15_000, 40_000])
        #expect(try fixture.budgets().count == 4)                   // last month's are untouched
    }

    @Test func anInvalidCurrencyFailsToOpen() throws {
        let fixture = try Fixture()
        #expect(throws: EditBudgetModel.EditorError.invalidCurrency) {
            try EditBudgetModel(month: october, context: fixture.context, currencyCode: "XYZ",
                                notifier: fixture.notifier)
        }
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
    let locale = Locale(identifier: "en_US")
    let now: Date

    var notifier: DataChangeNotifier {
        DataChangeNotifier { [changes] in changes.calls += 1 }
    }

    init(now iso: String = "2026-10-16T12:00:00Z") throws {
        context = ModelContext(try PersistenceController(mode: .inMemory).container)
        now = try #require(ISO8601DateFormatter().date(from: iso))
    }

    /// A Budget screen model at "now"; `refreshed` feeds it the store, as the view does on appear.
    func model(refreshed: Bool = false) throws -> BudgetModel {
        let model = BudgetModel(locale: locale, timeZone: timeZone, now: { [now] in now })
        if refreshed { refresh(model) }
        return model
    }

    /// What the view does when its queries' results, the month or a save change.
    func refresh(_ model: BudgetModel) {
        model.update(transactions: (try? context.fetch(FetchDescriptor<Transaction>())) ?? [],
                     budgets: (try? budgets()) ?? [], currencyCode: "USD")
    }

    func editor(locale: Locale? = nil) throws -> EditBudgetModel {
        try EditBudgetModel(month: YearMonth(year: 2026, month: 10)!, context: context, currencyCode: "USD",
                            notifier: notifier, locale: locale ?? self.locale)
    }

    func budgets() throws -> [Budget] {
        try context.fetch(FetchDescriptor<Budget>())
    }

    func category(_ systemKey: String) throws -> Category {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.systemKey == systemKey })
        return try #require(try context.fetch(descriptor).first)
    }

    func text(in editor: EditBudgetModel, for systemKey: String) throws -> String {
        let id = try category(systemKey).id
        return try #require(editor.fields.first { $0.id == id }).text
    }

    func setText(_ text: String, in editor: EditBudgetModel, for systemKey: String) throws {
        let id = try category(systemKey).id
        let index = try #require(editor.fields.firstIndex { $0.id == id })
        editor.fields[index].text = text
    }

    /// Inserts an expense in the category and saves.
    func add(_ cents: Int64, _ systemKey: String, _ iso: String) throws {
        let category = try category(systemKey)
        let date = try #require(ISO8601DateFormatter().date(from: iso))
        context.insert(Transaction(amount: try Money(minorUnits: cents, currencyCode: "USD"), kind: category.kind,
                                   date: date, category: category))
        try context.save()
    }

    func addBudget(_ cents: Int64, _ systemKey: String, month: YearMonth = YearMonth(year: 2026, month: 10)!,
                   currency: String = "USD") throws {
        context.insert(Budget(month: month, limit: try Money(minorUnits: cents, currencyCode: currency),
                              category: try category(systemKey)))
        try context.save()
    }
}

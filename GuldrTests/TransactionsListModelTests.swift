//
//  TransactionsListModelTests.swift
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

/// The Transactions list's filtering, grouping and deletion against an in-memory store with the default
/// categories. UTC, US English and a fixed "now" (Sept 20, 2026, noon) keep day titles and times stable.
struct TransactionsListModelTests {

    // MARK: - Filters

    @Test func kindFilterReachesTheQuery() throws {
        let fixture = try Fixture()
        try fixture.add(4_280, "food", "2026-09-20T09:41:00Z", title: "Groceries")
        try fixture.add(500_000, "salary", "2026-09-19T09:00:00Z", title: "Salary")
        let model = fixture.model()

        model.kindFilter = .income
        #expect(model.titles == ["Salary"])
        model.kindFilter = .expenses
        #expect(model.titles == ["Groceries"])
        model.kindFilter = .all
        #expect(model.titles == ["Groceries", "Salary"])
    }

    @Test func categoriesCombineAndClear() throws {
        let fixture = try Fixture()
        try fixture.add(4_280, "food", "2026-09-20T09:41:00Z", title: "Groceries")
        try fixture.add(3_500, "transport", "2026-09-20T07:50:00Z", title: "Gas")
        try fixture.add(1_825, "health", "2026-09-19T18:20:00Z", title: "Pharmacy")
        let model = fixture.model()

        model.toggleCategory(try fixture.category("food"))
        #expect(model.isFilteringByCategory)
        #expect(model.titles == ["Groceries"])
        model.toggleCategory(try fixture.category("transport"))
        #expect(model.titles == ["Groceries", "Gas"])
        model.toggleCategory(try fixture.category("food"))
        #expect(model.titles == ["Gas"])
        model.clearCategories()
        #expect(!model.isFilteringByCategory)
        #expect(model.titles == ["Groceries", "Gas", "Pharmacy"])
    }

    @Test func switchingKindDropsCategoriesOfTheOtherKind() throws {
        let fixture = try Fixture()
        let model = fixture.model()
        let food = try fixture.category("food")
        let salary = try fixture.category("salary")
        model.toggleCategory(food)
        model.toggleCategory(salary)

        model.kindFilter = .income
        #expect(model.selectedCategoryIDs == [salary.id])
        model.kindFilter = .all
        #expect(model.selectedCategoryIDs == [salary.id])     // "All" keeps what is left
    }

    @Test func menuOptionsFollowTheKind() throws {
        let fixture = try Fixture()
        let model = fixture.model()
        let categories = try fixture.context.fetch(FetchDescriptor<Category>())
        #expect(model.categoryOptions(from: categories).count == categories.count)
        model.kindFilter = .income
        #expect(model.categoryOptions(from: categories).allSatisfy { $0.kind == .income })
        model.kindFilter = .expenses
        #expect(model.categoryOptions(from: categories).allSatisfy { $0.kind == .expense })
    }

    @Test func searchMatchesTitlesNotesAndCategoryNames() throws {
        let fixture = try Fixture()
        try fixture.add(450, "food", "2026-09-20T08:15:00Z", title: "Café con leche")
        try fixture.add(3_500, "transport", "2026-09-20T07:50:00Z", title: "Gas")
        let model = fixture.model()

        model.searchText = "cafe"
        #expect(model.titles == ["Café con leche"])
        model.searchText = "transport"
        #expect(model.titles == ["Gas"])
        model.searchText = "rent"
        #expect(model.titles.isEmpty)
    }

    // MARK: - Sections

    @Test func groupsByDayWithRelativeTitles() throws {
        let fixture = try Fixture()
        try fixture.add(4_280, "food", "2026-09-20T09:41:00Z", title: "Groceries")
        try fixture.add(450, "food", "2026-09-20T08:15:00Z", title: "Coffee")
        try fixture.add(1_825, "health", "2026-09-19T18:20:00Z", title: "Pharmacy")
        try fixture.add(500_000, "salary", "2026-09-17T09:00:00Z", title: "Salary")
        let model = fixture.model()

        #expect(model.sections.map(\.title) == ["Today", "Yesterday", "Thursday, Sep 17"])
        #expect(model.sections.map { $0.rows.map(\.title) } == [["Groceries", "Coffee"], ["Pharmacy"], ["Salary"]])
        #expect(model.sections.map { $0.net?.minorUnits } == [-4_730, -1_825, 500_000])
    }

    @Test func dayNetUsesOnlyTheActiveCurrency() throws {
        let fixture = try Fixture()
        try fixture.add(1_000, "food", "2026-09-20T10:00:00Z")
        try fixture.add(5_000, "food", "2026-09-20T11:00:00Z", currency: "EUR")
        try fixture.add(2_000, "food", "2026-09-19T11:00:00Z", currency: "EUR")
        let model = fixture.model()

        #expect(model.sections.map { $0.net?.minorUnits } == [-1_000, nil])
        #expect(model.sections.map(\.rows.count) == [2, 1])  // the list still shows every currency
    }

    @Test func rowsShowTheCategoryAndTime() throws {
        let fixture = try Fixture()
        let date = try fixture.date("2026-09-20T09:41:00Z")
        try fixture.add(4_280, "food", "2026-09-20T09:41:00Z")
        let cash = Transaction(amount: try Money(minorUnits: 500, currencyCode: "USD"), kind: .expense,
                               title: "Cash", date: date.addingTimeInterval(-60))
        fixture.context.insert(cash)
        try fixture.context.save()
        let model = fixture.model()

        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: fixture.locale,
                                                   timeZone: fixture.timeZone))
        let rows = try #require(model.sections.first?.rows)
        #expect(rows.map(\.title) == ["Food", "Cash"])        // an empty description shows the category
        #expect(rows.first?.meta == "Food · " + time)
        #expect(rows.first?.symbol == "fork.knife")
        #expect(rows.first?.amount.minorUnits == 4_280)
        #expect(rows.last?.meta.hasPrefix("Uncategorized · ") == true)
        #expect(rows.last?.symbol == "questionmark")
    }

    @Test func emptyStatesTellNothingFromNoMatches() throws {
        let fixture = try Fixture()
        let model = fixture.model()
        #expect(model.emptyState == .noTransactions)

        model.searchText = "coffee"
        #expect(model.emptyState == .noResults)

        try fixture.add(450, "food", "2026-09-20T08:15:00Z", title: "Coffee")
        fixture.refresh(model)
        #expect(model.emptyState == nil)
        model.kindFilter = .income
        #expect(model.emptyState == .noResults)
    }

    @Test func updateShowsEdits() throws {
        let fixture = try Fixture()
        let groceries = try fixture.add(4_280, "food", "2026-09-20T09:41:00Z", title: "Groceries")
        let model = fixture.model()

        groceries.title = "Market"
        groceries.category = try fixture.category("shopping")
        try fixture.context.save()
        #expect(model.titles == ["Groceries"])                // kept until told the data changed
        fixture.refresh(model)
        #expect(model.titles == ["Market"])
        #expect(model.sections.first?.rows.first?.symbol == "bag")
    }

    // MARK: - Delete

    @Test func deleteRemovesTheTransactionAndNotifies() throws {
        let fixture = try Fixture()
        let groceries = try fixture.add(4_280, "food", "2026-09-20T09:41:00Z", title: "Groceries")
        try fixture.add(450, "food", "2026-09-20T08:15:00Z", title: "Coffee")
        let model = fixture.model()

        try model.delete(groceries.persistentModelID, in: fixture.context, notifier: fixture.notifier)
        #expect(try fixture.transactions().map(\.title) == ["Coffee"])
        #expect(fixture.changes.calls == 1)
        fixture.refresh(model)
        #expect(model.titles == ["Coffee"])
    }

    @Test func deletingAMissingTransactionDoesNothing() throws {
        let fixture = try Fixture()
        let groceries = try fixture.add(4_280, "food", "2026-09-20T09:41:00Z")
        let id = groceries.persistentModelID
        let model = fixture.model()
        fixture.context.delete(groceries)
        try fixture.context.save()

        try model.delete(id, in: fixture.context, notifier: fixture.notifier)
        #expect(fixture.changes.calls == .zero)
    }
}

// MARK: - Fixture

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

    init() throws {
        context = ModelContext(try PersistenceController(mode: .inMemory).container)
        now = try #require(ISO8601DateFormatter().date(from: "2026-09-20T12:00:00Z"))
    }

    /// A model already fed with the store's transactions, as the view does on appear.
    func model() -> TransactionsListModel {
        let model = TransactionsListModel(locale: locale, timeZone: timeZone, now: { [now] in now })
        refresh(model)
        return model
    }

    /// What the view does when its query's results change or after a save.
    func refresh(_ model: TransactionsListModel) {
        let all = (try? context.fetch(FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])))
        model.update(transactions: all ?? [], currencyCode: "USD")
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

    /// Inserts a transaction of the category's kind and saves.
    @discardableResult
    func add(_ cents: Int64, _ systemKey: String, _ iso: String, title: String = "",
             currency: String = "USD") throws -> Transaction {
        let category = try category(systemKey)
        let transaction = Transaction(amount: try Money(minorUnits: cents, currencyCode: currency), kind: category.kind,
                                      title: title, date: try date(iso), category: category)
        context.insert(transaction)
        try context.save()
        return transaction
    }
}

private extension TransactionsListModel {
    /// Every row's title, in list order.
    var titles: [String] {
        sections.flatMap { $0.rows.map(\.title) }
    }
}

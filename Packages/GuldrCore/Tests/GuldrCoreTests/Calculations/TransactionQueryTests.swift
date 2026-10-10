//
//  TransactionQueryTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import SwiftData
import Testing
@testable import GuldrCore

struct TransactionQueryTests {

    private let utc = TimeZone(identifier: "UTC")!

    private func previewTransactions() throws -> (all: [Transaction], categories: [Category]) {
        let controller = try PreviewData.makeController(timeZone: utc)
        let context = ModelContext(controller.container)
        return (try context.fetch(FetchDescriptor<Transaction>()), try context.fetch(FetchDescriptor<Category>()))
    }

    private func transaction(_ title: String, note: String = "", _ kind: TransactionKind = .expense,
                             category: Category? = nil, iso: String = "2026-09-10T12:00:00Z",
                             cents: Int64 = 100, currency: String = "USD") throws -> Transaction {
        Transaction(amount: try Money(minorUnits: cents, currencyCode: currency), kind: kind, title: title, note: note,
                    date: try #require(ISO8601DateFormatter().date(from: iso)), category: category)
    }

    @Test func noFiltersReturnsEverythingNewestFirst() throws {
        let (all, _) = try previewTransactions()
        let result = TransactionQuery().apply(to: all)
        #expect(result.count == all.count)
        #expect(result.first?.title == "Groceries")          // Sept 28, 9:41
        #expect(zip(result, result.dropFirst()).allSatisfy { $0.date >= $1.date })
        #expect(!TransactionQuery().isFiltering)
    }

    @Test func filtersByKind() throws {
        let (all, _) = try previewTransactions()
        let income = TransactionQuery(kind: .income).apply(to: all)
        #expect(income.allSatisfy { $0.kind == .income })
        #expect(income.count == 8)                           // six salaries, two freelance jobs
    }

    @Test func filtersByCategory() throws {
        let (all, categories) = try previewTransactions()
        let food = try #require(categories.first { $0.systemKey == "food" })
        let result = TransactionQuery(categoryIDs: [food.id]).apply(to: all)
        #expect(!result.isEmpty && result.allSatisfy { $0.category?.id == food.id })

        let uncategorized = try transaction("Cash")
        #expect(TransactionQuery(categoryIDs: [food.id]).apply(to: [uncategorized]).isEmpty)
        #expect(TransactionQuery().apply(to: [uncategorized]).count == 1)
    }

    @Test func searchIgnoresCaseAndAccents() throws {
        let cafe = try transaction("Café con leche")
        let other = try transaction("Rent")
        for text in ["cafe", "CAFÉ", "  café  ", "Leche"] {
            #expect(TransactionQuery(searchText: text).apply(to: [cafe, other]).map(\.title) == ["Café con leche"])
        }
    }

    @Test func everyWordMustMatchSomeField() throws {
        let food = Category(name: "Food", symbolName: "fork.knife", color: .terracotta, kind: .expense)
        let coffee = try transaction("Coffee", note: "with Ana", category: food)
        #expect(TransactionQuery(searchText: "coffee food").apply(to: [coffee]).count == 1)
        #expect(TransactionQuery(searchText: "ana coffee").apply(to: [coffee]).count == 1)
        #expect(TransactionQuery(searchText: "coffee rent").apply(to: [coffee]).isEmpty)
    }

    @Test func searchUsesTheDisplayedCategoryName() throws {
        let food = Category(name: "Food", symbolName: "fork.knife", color: .terracotta, kind: .expense, systemKey: "food")
        let groceries = try transaction("Groceries", category: food)
        let spanish: (Category) -> String = { $0.systemKey == "food" ? "Comida" : $0.name }
        #expect(TransactionQuery(searchText: "comida").apply(to: [groceries], categoryName: spanish).count == 1)
        #expect(TransactionQuery(searchText: "comida").apply(to: [groceries]).isEmpty)
    }

    @Test func filtersCombine() throws {
        let (all, categories) = try previewTransactions()
        let food = try #require(categories.first { $0.systemKey == "food" })
        let query = TransactionQuery(kind: .expense, categoryIDs: [food.id], searchText: "coffee")
        #expect(query.apply(to: all).map(\.title) == ["Coffee"])
        #expect(query.isFiltering)
    }

    @Test func groupsByDayLikeTheTransactionsMockup() throws {
        let (all, _) = try previewTransactions()
        // The mockup shows Sept 24 to 28.
        let sept24 = try #require(ISO8601DateFormatter().date(from: "2026-09-24T00:00:00Z"))
        let recent = TransactionQuery().apply(to: all.filter { $0.date >= sept24 })
        let sections = TransactionQuery.groupedByDay(recent, timeZone: utc)

        #expect(sections.map { YearMonth.calendar(utc).component(.day, from: $0.day) } == [28, 27, 25, 24])
        #expect(sections.map { $0.transactions.map(\.title) } == [
            ["Groceries", "Coffee"], ["Pharmacy", "Streaming subscription"], ["Salary"], ["Gas"]
        ])
        // "Today −$47.30", "Yesterday −$34.24", "+$5,000.00", "−$35.00"
        #expect(try sections.map { try $0.net(currencyCode: "USD").minorUnits } == [-4_730, -3_424, 500_000, -3_500])
    }

    @Test func dayBoundariesFollowTheTimeZone() throws {
        let lateNight = try transaction("Late", iso: "2026-09-28T03:00:00Z")   // Sept 27, 21:00 in Mexico City
        let morning = try transaction("Morning", iso: "2026-09-28T15:00:00Z")
        let mexico = TimeZone(identifier: "America/Mexico_City")!
        #expect(TransactionQuery.groupedByDay([morning, lateNight], timeZone: mexico).count == 2)
        #expect(TransactionQuery.groupedByDay([morning, lateNight], timeZone: utc).count == 1)
    }

    @Test func dayNetLeavesOtherCurrenciesOut() throws {
        let sections = TransactionQuery.groupedByDay([
            try transaction("A", cents: 1_000),
            try transaction("B", cents: 5_000, currency: "EUR")
        ], timeZone: utc)
        #expect(try sections.first?.net(currencyCode: "USD").minorUnits == -1_000)
        #expect(sections.first?.transactions.count == 2)     // the list still shows both
    }

    @Test func equalDatesKeepAStableOrder() throws {
        let first = try transaction("First")
        let second = try transaction("Second")
        let forward = TransactionQuery().apply(to: [first, second]).map(\.id)
        let backward = TransactionQuery().apply(to: [second, first]).map(\.id)
        #expect(forward == backward)
    }
}

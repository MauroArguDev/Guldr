//
//  ModelTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 9/10/26.
//

import Foundation
import SwiftData
import Testing
@testable import GuldrCore

struct ModelTests {

    @Test func schemaContainsEveryModel() {
        let names = SchemaV1.models.map { String(describing: $0) }
        #expect(Set(names) == ["Transaction", "Category", "Budget"])
        #expect(SchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(GuldrMigrationPlan.stages.isEmpty)
    }

    @Test func transactionStoresMoneyAsMinorUnitsAndCode() throws {
        let transaction = Transaction(amount: try usd(4280), kind: .expense, title: "Groceries")
        #expect(transaction.amountMinorUnits == 4280)
        #expect(transaction.currencyCode == "USD")
        #expect(transaction.amount == (try usd(4280)))
        #expect(transaction.category == nil)
        #expect(transaction.note.isEmpty)

        transaction.amount = try Money(minorUnits: 1500, currencyCode: "JPY")
        #expect(transaction.amountMinorUnits == 1500)
        #expect(transaction.currencyCode == "JPY")
    }

    @Test func enumsAreStoredAsRawValues() throws {
        let transaction = Transaction(amount: try usd(100), kind: .income)
        #expect(transaction.kindRawValue == "income")
        transaction.kind = .expense
        #expect(transaction.kindRawValue == "expense")

        let category = Category(name: "Food", symbolName: "fork.knife", color: .amber, kind: .expense)
        #expect(category.colorKey == "amber")
        category.color = .teal
        #expect(category.colorKey == "teal")
    }

    @Test func unknownRawValuesFallBack() throws {
        // Values a newer app version could write must not break an older one.
        let transaction = Transaction(amount: try usd(100), kind: .income)
        transaction.kindRawValue = "transfer"
        #expect(transaction.kind == .expense)

        let category = Category(name: "Pets", symbolName: "pawprint", color: .olive, kind: .expense)
        category.colorKey = "ultraviolet"
        #expect(category.color == .graphite)
    }

    @Test func budgetStoresTheMonthAsAnInteger() throws {
        let october = try #require(YearMonth(year: 2026, month: 10))
        let budget = Budget(month: october, limit: try usd(50_000))
        #expect(budget.yearMonth == 202_610)
        #expect(budget.month == october)
        #expect(budget.limit == (try usd(50_000)))
        budget.yearMonth = 202_613
        #expect(budget.month == nil)
    }

    @Test func modelsSaveWithoutRelationships() throws {
        // CloudKit requires every relationship to be optional: each model must save on its own.
        let context = try makeInMemoryContext()
        context.insert(Transaction(amount: try usd(100), kind: .expense))
        context.insert(Category(name: "Pets", symbolName: "pawprint", color: .olive, kind: .expense))
        context.insert(Budget(month: try #require(YearMonth(year: 2026, month: 10)), limit: try usd(100)))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Category>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Budget>()) == 1)
    }

    @Test func relationshipsHaveInverses() throws {
        let context = try makeInMemoryContext()
        let food = Category(name: "Food", symbolName: "fork.knife", color: .amber, kind: .expense)
        let transaction = Transaction(amount: try usd(4280), kind: .expense, category: food)
        let budget = Budget(month: try #require(YearMonth(year: 2026, month: 10)), limit: try usd(40_000), category: food)
        context.insert(transaction)
        context.insert(budget)
        try context.save()

        #expect(food.transactions?.map(\.id) == [transaction.id])
        #expect(food.budgets?.map(\.id) == [budget.id])
    }

    @Test func deletingACategoryKeepsTransactionsAndDeletesBudgets() throws {
        let context = try makeInMemoryContext()
        let food = Category(name: "Food", symbolName: "fork.knife", color: .amber, kind: .expense)
        let transaction = Transaction(amount: try usd(4280), kind: .expense, category: food)
        context.insert(transaction)
        context.insert(Budget(month: try #require(YearMonth(year: 2026, month: 10)), limit: try usd(40_000), category: food))
        try context.save()

        context.delete(food)
        try context.save()

        #expect(transaction.category == nil)
        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Budget>()) == 0)
    }

    @Test func deletingATransactionKeepsItsCategory() throws {
        let context = try makeInMemoryContext()
        let food = Category(name: "Food", symbolName: "fork.knife", color: .amber, kind: .expense)
        let transaction = Transaction(amount: try usd(4280), kind: .expense, category: food)
        context.insert(transaction)
        try context.save()

        context.delete(transaction)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Category>()) == 1)
        #expect(food.transactions?.isEmpty == true)
    }
}

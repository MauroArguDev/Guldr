//
//  ExportModelTests.swift
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

/// What the export includes, on an in-memory store in UTC on Oct 21, 2026.
struct ExportModelTests {

    private let utc = TimeZone(identifier: "UTC")!

    @Test func allTimeIncludesEveryTransactionAndCurrency() throws {
        let fixture = try Fixture()
        try fixture.add("2025-03-02T10:00:00Z")
        try fixture.add("2026-10-20T10:00:00Z", currency: "EUR")
        let model = fixture.model(utc)
        #expect(model.includedCount == 2)
        #expect(model.file?.name == "Guldr-2026-10-21.csv")
        #expect(Set(model.file?.rows.map(\.amount.currencyCode) ?? []) == ["USD", "EUR"])
    }

    @Test func aRangeIncludesWholeDays() throws {
        let fixture = try Fixture()
        try fixture.add("2026-09-30T23:59:59Z")
        try fixture.add("2026-10-01T00:00:00Z")
        try fixture.add("2026-10-10T23:59:59Z")
        try fixture.add("2026-10-11T00:00:00Z")
        let model = fixture.model(utc)
        model.range = .dates
        model.startDay = try fixture.date("2026-10-01T15:00:00Z")
        model.endDay = try fixture.date("2026-10-10T08:00:00Z")
        #expect(model.includedCount == 2)

        // Days picked the other way round mean the same range.
        model.startDay = try fixture.date("2026-10-10T08:00:00Z")
        model.endDay = try fixture.date("2026-10-01T15:00:00Z")
        #expect(model.includedCount == 2)
    }

    @Test func theRangeStartsOnTheFirstOfTheMonth() throws {
        let model = try Fixture().model(utc)
        #expect(model.startDay == (try Fixture().date("2026-10-01T00:00:00Z")))
    }

    @Test func nothingToExportHasNoFile() throws {
        let fixture = try Fixture()
        let model = fixture.model(utc)
        #expect(model.includedCount == 0)
        #expect(model.file == nil)

        try fixture.add("2026-05-01T10:00:00Z")
        model.update(transactions: try fixture.transactions())
        model.range = .dates
        #expect(model.includedCount == 0)
        #expect(model.file == nil)
    }

    @Test func rowsNameTheirCategory() throws {
        let fixture = try Fixture()
        try fixture.add("2026-10-20T10:00:00Z")
        #expect(fixture.model(utc).file?.rows.first?.category == "Food")
    }
}

// MARK: - Fixture

private struct Fixture {

    let context: ModelContext

    init() throws {
        context = ModelContext(try PersistenceController(mode: .inMemory).container)
    }

    func date(_ iso: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: iso))
    }

    func transactions() throws -> [Transaction] {
        try context.fetch(FetchDescriptor<Transaction>())
    }

    func model(_ timeZone: TimeZone) -> ExportModel {
        let now = (try? date("2026-10-21T12:00:00Z")) ?? .now
        let model = ExportModel(timeZone: timeZone, now: { now })
        model.update(transactions: (try? transactions()) ?? [])
        return model
    }

    func add(_ iso: String, currency: String = "USD") throws {
        let food = try #require(try context.fetch(FetchDescriptor<Category>()).first { $0.systemKey == "food" })
        context.insert(Transaction(amount: try Money(minorUnits: 1_000, currencyCode: currency), kind: .expense,
                                   date: try date(iso), category: food))
        try context.save()
    }
}

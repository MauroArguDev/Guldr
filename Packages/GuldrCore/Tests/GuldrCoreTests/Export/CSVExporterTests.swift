//
//  CSVExporterTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation
import SwiftData
import Testing
@testable import GuldrCore

/// RFC 4180 output with the author's columns, in a fixed −06:00 time zone.
struct CSVExporterTests {

    private let mexico = TimeZone(secondsFromGMT: -6 * 3_600)!

    @Test func anEmptyExportIsTheHeaderAlone() {
        #expect(CSVExporter.text(for: [], timeZone: mexico) == "date,title,category,type,amount,currency,note\r\n")
    }

    @Test func recordsFollowTheColumns() throws {
        let rows = [
            try row("2026-10-21T14:00:00Z", "Groceries", "Food", .expense, 4_280),
            try row("2026-10-01T15:00:00Z", "Salary", "Salary", .income, 500_000, note: "October")
        ]
        let lines = CSVExporter.text(for: rows, timeZone: mexico).components(separatedBy: "\r\n")
        #expect(lines == [
            "date,title,category,type,amount,currency,note",
            "2026-10-01T09:00:00-06:00,Salary,Salary,income,5000.00,USD,October",
            "2026-10-21T08:00:00-06:00,Groceries,Food,expense,-42.80,USD,",
            ""
        ])
    }

    @Test func quotesCommasNewlinesAndEmojiAreEscaped() throws {
        let rows = [try row("2026-10-21T14:00:00Z", "Dinner, \"La Casa\"", "Food 🍕", .expense, 1_000,
                            note: "Line one\nline two\r\nend")]
        let text = CSVExporter.text(for: rows, timeZone: mexico)
        #expect(text.hasSuffix(",\"Dinner, \"\"La Casa\"\"\",Food 🍕,expense,-10.00,USD,\"Line one\nline two\r\nend\"\r\n"))
        // The emoji survives as UTF-8.
        #expect(String(bytes: Data(text.utf8), encoding: .utf8)?.contains("🍕") == true)
    }

    @Test func amountsIgnoreTheLocaleAndUseTheCurrencysDigits() throws {
        #expect(CSVExporter.amountText(try Money(minorUnits: 123_456, currencyCode: "EUR"), kind: .expense) == "-1234.56")
        #expect(CSVExporter.amountText(try Money(minorUnits: 1_200, currencyCode: "JPY"), kind: .expense) == "-1200")
        #expect(CSVExporter.amountText(try Money(minorUnits: 1_250, currencyCode: "BHD"), kind: .income) == "1.250")
        #expect(CSVExporter.amountText(try Money(minorUnits: 5, currencyCode: "USD"), kind: .income) == "0.05")
        #expect(CSVExporter.amountText(try Money(minorUnits: 0, currencyCode: "USD"), kind: .expense) == "0.00")
    }

    @Test func equalDatesKeepTheirOrder() throws {
        let rows = try ["First", "Second", "Third"].map { try row("2026-10-21T14:00:00Z", $0, "Food", .expense, 100) }
        let titles = CSVExporter.text(for: rows, timeZone: mexico).components(separatedBy: "\r\n").dropFirst().prefix(3)
            .map { $0.split(separator: ",")[1] }
        #expect(titles == ["First", "Second", "Third"])
    }

    @Test func dataIsTheTextInUTF8() async throws {
        let rows = [try row("2026-10-21T14:00:00Z", "Café", "Food", .expense, 350)]
        let data = await CSVExporter.data(for: rows, timeZone: mexico)
        #expect(data == Data(CSVExporter.text(for: rows, timeZone: mexico).utf8))
    }

    @Test func fileNameUsesTheLocalDay() throws {
        // 03:00 UTC on Oct 22 is still Oct 21 in Mexico City.
        let date = try #require(ISO8601DateFormatter().date(from: "2026-10-22T03:00:00Z"))
        #expect(CSVExporter.fileName(on: date, timeZone: mexico) == "Guldr-2026-10-21.csv")
    }

    @Test func rowsCopyTheTransaction() throws {
        let context = try makeInMemoryContext()
        try CategorySeeder.seedDefaults(in: context)
        let food = try #require(try context.fetch(FetchDescriptor<Category>()).first { $0.systemKey == "food" })
        let transaction = Transaction(amount: try usd(4_280), kind: .expense, title: "Groceries", note: "Weekly",
                                      category: food)
        let row = CSVExporter.Row(transaction) { $0?.name ?? "None" }
        #expect(row.title == "Groceries")
        #expect(row.category == "Food")
        #expect(row.note == "Weekly")
        #expect(row.amount == (try usd(4_280)))
        #expect(CSVExporter.Row(Transaction(amount: try usd(1), kind: .expense)) { $0?.name ?? "None" }.category == "None")
    }

    // MARK: - Helpers

    private func row(_ iso: String, _ title: String, _ category: String, _ kind: TransactionKind, _ cents: Int64,
                     note: String = "") throws -> CSVExporter.Row {
        CSVExporter.Row(date: try #require(ISO8601DateFormatter().date(from: iso)), title: title, category: category,
                        kind: kind, amount: try usd(cents), note: note)
    }
}

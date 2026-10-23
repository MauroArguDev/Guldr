//
//  ShareCardTests.swift
//  GuldrTests
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import GuldrCore
import SwiftData
import SwiftUI
import Testing
@testable import Guldr

// The app's aliases are internal to the app module; the test module needs its own (ARCHITECTURE.md › Data).
private typealias Category = GuldrCore.Category
private typealias Transaction = GuldrCore.Transaction
private typealias Budget = GuldrCore.Budget

/// The share cards (v1 plan, Phase 31): no amount ever, the right image sizes, and when the recap is offered.
struct ShareCardTests {

    private let mexico = TimeZone(identifier: "America/Mexico_City")!

    @Test(arguments: ["en_US", "es_MX", "es_ES"], ["USD", "MXN", "EUR"])
    func theRecapShowsNoAmount(localeID: String, currencyCode: String) throws {
        let fixture = try Fixture(currencyCode: currencyCode)
        let card = RecapLibrary.card(for: YearMonth(year: 2026, month: 9)!, in: fixture.context,
                                     currencyCode: currencyCode, locale: Locale(identifier: localeID), timeZone: mexico)
        let text = card.rows.map { String(localized: $0.label) + " " + $0.value }.joined(separator: "\n")
            + ShareCardContent.recap(card).message
        #expect(card.rows.count == 5, "\(text)")
        let locale = Locale(identifier: localeID)
        let symbol = 1.0.formatted(.currency(code: currencyCode).locale(locale))
            .filter { !$0.isNumber && !$0.isWhitespace && !".,".contains($0) }
        #expect(!symbol.isEmpty)
        #expect(!text.contains(symbol), "\(symbol) in \(text)")
        #expect(!text.contains(currencyCode))
        // None of the amounts the month had, in any form.
        for amount in ["5000", "5,000", "5.000", "1500", "1,500", "1.500", "500"] {
            #expect(!text.contains(amount), "\(amount) in \(text)")
        }
    }

    @Test func rowsWithoutDataAreLeftOut() throws {
        let fixture = try Fixture(currencyCode: "USD", withMoney: false)
        let card = RecapLibrary.card(for: YearMonth(year: 2026, month: 9)!, in: fixture.context, currencyCode: "USD",
                                     locale: Locale(identifier: "en_US"), timeZone: mexico)
        #expect(card.rows.map { String(localized: $0.label) } == ["Days logged", "Best streak"])
    }

    @Test(arguments: ShareCardFormat.allCases)
    func cardsRenderAtTheirPixelSize(format: ShareCardFormat) throws {
        let content = ShareCardContent.achievement(AchievementCatalog.achievement(.saver), .gold)
        let image = try #require(ShareCardRenderer.image(for: content, format: format, colorScheme: .dark,
                                                         locale: Locale(identifier: "es_MX")))
        #expect(image.size.width * image.scale == format.points.width * 3)
        #expect(image.size.height * image.scale == format.points.height * 3)
        #expect(image.pngData() != nil)
    }

    @Test func homeOffersLastMonthDuringTheFirstWeek() throws {
        let september = YearMonth(year: 2026, month: 9)!
        let available = [september]
        let firstWeek = try date("2026-10-07T23:00:00-06:00")
        let eighth = try date("2026-10-08T08:00:00-06:00")
        #expect(RecapLibrary.homeMonth(now: firstWeek, timeZone: mexico, dismissed: nil, available: available) == september)
        #expect(RecapLibrary.homeMonth(now: eighth, timeZone: mexico, dismissed: nil, available: available) == nil)
        #expect(RecapLibrary.homeMonth(now: firstWeek, timeZone: mexico, dismissed: september, available: available) == nil)
        #expect(RecapLibrary.homeMonth(now: firstWeek, timeZone: mexico, dismissed: nil, available: []) == nil)
    }

    @Test func availableMonthsArePastMonthsWithSomethingInThem() throws {
        let fixture = try Fixture(currencyCode: "USD")
        let now = try date("2026-10-03T12:00:00-06:00")
        let months = RecapLibrary.availableMonths(in: fixture.context, currencyCode: "USD", now: now, timeZone: mexico)
        #expect(months == [YearMonth(year: 2026, month: 9)!])
    }

    @Test func theSharedTextNamesTheMonthMidSentence() throws {
        let fixture = try Fixture(currencyCode: "USD")
        let card = RecapLibrary.card(for: YearMonth(year: 2026, month: 9)!, in: fixture.context, currencyCode: "USD",
                                     locale: Locale(identifier: "es_MX"), timeZone: mexico)
        #expect(card.monthName == "septiembre")
        #expect(card.monthTitle == "Septiembre de 2026")
    }

    private func date(_ text: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: text))
    }
}

// MARK: - Fixture

/// September 2026 fully logged, with a salary of 5,000, 1,500 spent on housing and a 2,000 budget.
private struct Fixture {

    let context: ModelContext

    init(currencyCode: String, withMoney: Bool = true) throws {
        context = ModelContext(try PersistenceController(mode: .inMemory).container)
        for day in 1...30 {
            context.insert(LoggedDay(day: LocalDay(year: 2026, month: 9, day: day)!, source: .transaction))
        }
        if withMoney {
            let categories = try context.fetch(FetchDescriptor<Category>())
            let salary = categories.first { $0.systemKey == "salary" }
            let housing = categories.first { $0.systemKey == "housing" }
            let formatter = ISO8601DateFormatter()
            context.insert(Transaction(amount: try Money(minorUnits: 500_000, currencyCode: currencyCode), kind: .income,
                                       date: try #require(formatter.date(from: "2026-09-01T12:00:00-06:00")),
                                       category: salary))
            context.insert(Transaction(amount: try Money(minorUnits: 150_000, currencyCode: currencyCode), kind: .expense,
                                       date: try #require(formatter.date(from: "2026-09-02T12:00:00-06:00")),
                                       category: housing))
            context.insert(Budget(month: YearMonth(year: 2026, month: 9)!,
                                  limit: try Money(minorUnits: 200_000, currencyCode: currencyCode), category: housing))
        }
        try context.save()
    }
}

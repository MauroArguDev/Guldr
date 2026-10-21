//
//  AnalyticsModelTests.swift
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

/// The Analytics mapping against the preview data set, which reproduces the Charts mockup, on its date
/// (Sept 28, 2026, 9:41). UTC and US English keep labels and month boundaries stable.
struct AnalyticsModelTests {

    // MARK: - Totals and bars

    @Test func sixMonthsMatchTheChartsMockup() throws {
        let fixture = try Fixture()
        let model = fixture.model(.sixMonths)

        let totals = try #require(model.totals)
        #expect(totals.income.minorUnits == 3_105_000)
        #expect(totals.expenses.minorUnits == 1_287_450)
        #expect(totals.net.minorUnits == 1_817_550)
        #expect(model.bars.map(\.label) == ["Apr", "May", "Jun", "Jul", "Aug", "Sep"])
        #expect(model.bars.map(\.title).last == "September 2026")
        #expect(model.bars.map(\.isCurrent) == [false, false, false, false, false, true])
        #expect(model.bars.last?.expenses.minorUnits == 175_950)
        #expect(model.hasData)
        #expect(model.hasTransactions)
    }

    @Test func oneMonthHasWeeklyBars() throws {
        let model = try Fixture().model(.oneMonth)
        // Sept 2026 starts on a Tuesday; US weeks start on Sunday and are clipped to the month.
        #expect(model.bars.map(\.label) == ["Sep 1", "Sep 6", "Sep 13", "Sep 20", "Sep 27"])
        #expect(plain(model.bars.first?.title) == "Sep 1 – 5")
        #expect(model.bars.map(\.isCurrent) == [false, false, false, false, true])
        #expect(model.totals?.expenses.minorUnits == 175_950)
    }

    @Test func oneYearUsesOneLetterAndUniqueKeys() throws {
        let model = try Fixture().model(.oneYear)
        #expect(model.bars.count == 12)
        #expect(model.bars.map(\.label) == ["O", "N", "D", "J", "F", "M", "A", "M", "J", "J", "A", "S"])
        #expect(Set(model.bars.map(\.key)).count == 12)
    }

    @Test func overspendingMakesTheNetNegative() throws {
        let fixture = try Fixture(seeded: false)
        try fixture.add(10_000, "food", "2026-09-10T09:00:00Z")
        try fixture.add(4_000, "salary", "2026-09-01T09:00:00Z")
        let totals = try #require(fixture.model(.oneMonth).totals)
        #expect(totals.net.minorUnits == -6_000)
        #expect(totals.net.isNegative)
    }

    @Test func otherCurrenciesAreLeftOut() throws {
        let fixture = try Fixture(seeded: false)
        try fixture.add(10_000, "food", "2026-09-10T09:00:00Z", currency: "EUR")
        let model = fixture.model(.sixMonths)
        #expect(!model.hasData)
        #expect(model.hasTransactions)
        #expect(model.slices.isEmpty)
    }

    // MARK: - Donut

    @Test func donutFollowsThePeriod() throws {
        let fixture = try Fixture()
        let september = fixture.model(.oneMonth)
        #expect(september.rangeTitle == "September")
        #expect(september.expenseTotal?.minorUnits == 175_950)
        #expect(september.slices.first?.name == "Housing")
        #expect(september.slices.last?.name == "Other")
        #expect(september.slices.map(\.percentage).reduce(0, +) == 100)

        let sixMonths = fixture.model(.sixMonths)
        #expect(plain(sixMonths.rangeTitle) == "Apr – Sep")
        #expect(sixMonths.expenseTotal?.minorUnits == 1_287_450)
        #expect(sixMonths.slices.map(\.percentage).reduce(0, +) == 100)

        #expect(plain(fixture.model(.oneYear).rangeTitle) == "Oct 2025 – Sep 2026")
    }

    @Test func slicesTakeTheirCategorysColor() throws {
        let fixture = try Fixture()
        let model = fixture.model(.oneMonth)
        let housing = try #require(model.slices.first)
        #expect(housing.color == (try fixture.category("housing")).color)
        #expect(model.slices.last?.color == .graphite)
    }

    // MARK: - Empty states

    @Test func aNewUserHasNoTransactions() throws {
        let model = try Fixture(seeded: false).model(.sixMonths)
        #expect(!model.hasTransactions)
        #expect(!model.hasData)
        #expect(model.slices.isEmpty)
        #expect(model.totals?.income.isZero == true)
    }

    @Test func anEmptyPeriodStillHasTransactions() throws {
        let fixture = try Fixture(seeded: false)
        try fixture.add(10_000, "food", "2026-05-10T09:00:00Z")
        let oneMonth = fixture.model(.oneMonth)
        #expect(oneMonth.hasTransactions)
        #expect(!oneMonth.hasData)
        #expect(fixture.model(.sixMonths).hasData)
    }

    /// Interval formats put thin spaces around the dash; compare with plain ones.
    private func plain(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "\u{2009}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
    }
}

// MARK: - Fixture

private struct Fixture {

    let context: ModelContext
    let timeZone = TimeZone(identifier: "UTC")!
    let locale = Locale(identifier: "en_US")

    /// `seeded` adds the preview data set (the Charts mockup); otherwise only the default categories.
    init(seeded: Bool = true) throws {
        let utc = TimeZone(identifier: "UTC")!
        let controller = seeded ? try PreviewData.makeController(timeZone: utc)
                                : try PersistenceController(mode: .inMemory)
        context = ModelContext(controller.container)
    }

    /// A model fed with the store for `period`, as the view does, on the preview data set's date.
    func model(_ period: CashFlowSeries.Period) -> AnalyticsModel {
        let now = PreviewData.referenceDate(in: timeZone)
        let model = AnalyticsModel(locale: locale, timeZone: timeZone, now: { now })
        model.update(transactions: (try? context.fetch(FetchDescriptor<Transaction>())) ?? [],
                     categories: (try? context.fetch(FetchDescriptor<Category>())) ?? [],
                     period: period, currencyCode: "USD")
        return model
    }

    func category(_ systemKey: String) throws -> Category {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.systemKey == systemKey })
        return try #require(try context.fetch(descriptor).first)
    }

    /// Inserts a transaction of the category's kind and saves.
    func add(_ cents: Int64, _ systemKey: String, _ iso: String, currency: String = "USD") throws {
        let category = try category(systemKey)
        let date = try #require(ISO8601DateFormatter().date(from: iso))
        context.insert(Transaction(amount: try Money(minorUnits: cents, currencyCode: currency), kind: category.kind,
                                   date: date, category: category))
        try context.save()
    }
}

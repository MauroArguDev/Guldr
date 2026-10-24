//
//  PreviewData.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import SwiftData

/// Six months of realistic data that reproduce the mockups' numbers, for previews and screenshots.
///
/// "Now" is fixed at Sept 28, 2026, 9:41, as in the mockups, so previews are deterministic: views
/// that show relative dates take `referenceDate` instead of `Date.now`. September matches the
/// Dashboard, Transactions, Budget and Charts mockups: $5,000.00 income, $1,759.50 expenses across
/// seven categories, five budgets with Entertainment over its limit. April to August match the
/// Charts mockup's monthly bars.
public enum PreviewData {

    public static let currencyCode = "USD"

    /// How the data reads in each App Store localization's screenshots (v1 plan, 34.6): the titles' language,
    /// the currency, and a scale that keeps the amounts realistic in it. Previews and tests use `mockups`.
    public struct Flavor: Sendable, Equatable {

        public enum Titles: Sendable {
            case english
            case mexicanSpanish
            case spainSpanish
        }

        public let currencyCode: String
        public let amountScale: Int64
        public let titles: Titles

        public static let mockups = Flavor(currencyCode: PreviewData.currencyCode, amountScale: 1, titles: .english)

        /// Titles follow the language and the currency follows the region (author's call, 2026-10-23):
        /// Mexico in pesos at ten times the amounts, so rent reads $8,500; Spain in euros at the same amounts;
        /// everywhere else in dollars.
        public static func matching(_ locale: Locale) -> Flavor {
            let spanish = locale.language.languageCode == .spanish
            if locale.region == .mexico {
                return Flavor(currencyCode: "MXN", amountScale: 10, titles: spanish ? .mexicanSpanish : .english)
            }
            if locale.region == .spain {
                return Flavor(currencyCode: "EUR", amountScale: 1, titles: spanish ? .spainSpanish : .english)
            }
            return Flavor(currencyCode: "USD", amountScale: 1, titles: spanish ? .mexicanSpanish : .english)
        }

        func title(_ english: String) -> String {
            switch titles {
            case .english: english
            case .mexicanSpanish: PreviewData.mexicanTitles[english] ?? english
            case .spainSpanish: PreviewData.spainTitles[english] ?? PreviewData.mexicanTitles[english] ?? english
            }
        }
    }

    /// Sept 28, 2026, 9:41 in `timeZone`.
    public static func referenceDate(in timeZone: TimeZone = .autoupdatingCurrent) -> Date {
        date(month: 9, day: 28, hour: 9, minute: 41, timeZone: timeZone)
    }

    /// An in-memory container with the default categories and the preview data.
    public static func makeController(timeZone: TimeZone = .autoupdatingCurrent) throws -> PersistenceController {
        let controller = try PersistenceController(mode: .inMemory)
        try populate(ModelContext(controller.container), timeZone: timeZone)
        return controller
    }

    /// Inserts the preview transactions, budgets and logged days. Expects the default categories to be seeded.
    public static func populate(_ context: ModelContext, timeZone: TimeZone = .autoupdatingCurrent) throws {
        let september = YearMonth(year: 2026, month: 9) ?? YearMonth(containing: referenceDate(in: timeZone))
        try insert(into: context, budgetMonth: september, now: .now, timeZone: timeZone) { entry in
            date(year: 2026, month: entry.month, day: entry.day, hour: entry.hour, minute: entry.minute,
                 timeZone: timeZone)
        }
    }

    /// The same data moved so September becomes the month containing `now`, for screenshots of the running
    /// app (Debug's `-demoData`). Earlier months keep their days, capped at the month's length. The current
    /// month's days are spread over the days so far, so its totals still match the mockups and nothing
    /// lands in the future. `flavor` sets the titles' language, the currency and the amounts' scale.
    public static func populate(_ context: ModelContext, endingAt now: Date,
                                timeZone: TimeZone = .autoupdatingCurrent, flavor: Flavor = .mockups) throws {
        let calendar = YearMonth.calendar(timeZone)
        let current = YearMonth(containing: now, timeZone: timeZone)
        let today = calendar.component(.day, from: now)
        try insert(into: context, budgetMonth: current, now: now, timeZone: timeZone, flavor: flavor) { entry in
            let month = current.adding(months: entry.month - 9)
            let day = if month == current {
                1 + (entry.day - 1) * (today - 1) / 27
            } else {
                min(entry.day, calendar.range(of: .day, in: .month,
                                              for: month.dateInterval(in: timeZone).start)?.count ?? 28)
            }
            let shifted = date(year: month.year, month: month.month, day: day, hour: entry.hour,
                               minute: entry.minute, timeZone: timeZone)
            return min(shifted, now.addingTimeInterval(-60))
        }
    }

    private static func insert(into context: ModelContext, budgetMonth: YearMonth, now: Date, timeZone: TimeZone,
                               flavor: Flavor = .mockups, dateFor: (Entry) -> Date) throws {
        let categories = try context.fetch(FetchDescriptor<Category>())
        let byKey = Dictionary(categories.compactMap { category in category.systemKey.map { ($0, category) } },
                               uniquingKeysWith: { first, _ in first })

        for entry in entries {
            let amount = try Money(minorUnits: entry.cents * flavor.amountScale, currencyCode: flavor.currencyCode)
            let category = byKey[entry.categoryKey]
            context.insert(Transaction(amount: amount, kind: category?.kind ?? .expense, title: flavor.title(entry.title),
                                       date: dateFor(entry), category: category))
        }
        for (key, cents) in septemberBudgets {
            let limit = try Money(minorUnits: cents * flavor.amountScale, currencyCode: flavor.currencyCode)
            context.insert(Budget(month: budgetMonth, limit: limit, category: byKey[key]))
        }
        for (offset, source) in streakDays {
            context.insert(LoggedDay(day: LocalDay(containing: now, timeZone: timeZone).adding(days: offset),
                                     source: source))
        }
        try context.save()
    }

    /// A streak relative to the real today, since the streak is always about today: 16 days with a freeze
    /// on day −6 and a "No spending" day, today logged.
    static var streakDays: [(Int, LoggedDaySource)] {
        (-16...0).filter { $0 != -6 }.map { ($0, $0 == -3 ? .noSpending : .transaction) }
    }

    // MARK: - Data

    private struct Entry {
        let month: Int
        let day: Int
        let hour: Int
        let minute: Int
        let title: String
        let cents: Int64
        let categoryKey: String
    }

    // swiftlint:disable comma
    // Column-aligned on purpose: each row reads as month, day, time, title, amount, category.
    private static let entries: [Entry] = [
        // September: the mockups' visible rows, then the rest of each category's total.
        Entry(month: 9, day: 28, hour: 9,  minute: 41, title: "Groceries",              cents: 4_280,   categoryKey: "food"),
        Entry(month: 9, day: 28, hour: 8,  minute: 15, title: "Coffee",                 cents: 450,     categoryKey: "food"),
        Entry(month: 9, day: 27, hour: 18, minute: 20, title: "Pharmacy",               cents: 1_825,   categoryKey: "health"),
        Entry(month: 9, day: 27, hour: 12, minute: 0,  title: "Streaming subscription", cents: 1_599,   categoryKey: "entertainment"),
        Entry(month: 9, day: 25, hour: 9,  minute: 0,  title: "Salary",                 cents: 500_000, categoryKey: "salary"),
        Entry(month: 9, day: 24, hour: 7,  minute: 50, title: "Gas",                    cents: 3_500,   categoryKey: "transport"),
        Entry(month: 9, day: 1,  hour: 9,  minute: 0,  title: "Rent",                   cents: 85_000,  categoryKey: "housing"),
        Entry(month: 9, day: 6,  hour: 11, minute: 30, title: "Supermarket",            cents: 13_420,  categoryKey: "food"),
        Entry(month: 9, day: 13, hour: 20, minute: 15, title: "Dinner out",             cents: 6_850,   categoryKey: "food"),
        Entry(month: 9, day: 20, hour: 10, minute: 45, title: "Farmers market",         cents: 6_200,   categoryKey: "food"),
        Entry(month: 9, day: 9,  hour: 16, minute: 10, title: "Running shoes",          cents: 12_900,  categoryKey: "shopping"),
        Entry(month: 9, day: 17, hour: 19, minute: 5,  title: "Books",                  cents: 8_750,   categoryKey: "shopping"),
        Entry(month: 9, day: 3,  hour: 8,  minute: 30, title: "Transit pass",           cents: 7_500,   categoryKey: "transport"),
        Entry(month: 9, day: 15, hour: 22, minute: 40, title: "Ride home",              cents: 3_500,   categoryKey: "transport"),
        Entry(month: 9, day: 11, hour: 21, minute: 0,  title: "Concert tickets",        cents: 8_001,   categoryKey: "entertainment"),
        Entry(month: 9, day: 8,  hour: 17, minute: 25, title: "Vitamins",               cents: 2_175,   categoryKey: "health"),
        Entry(month: 9, day: 19, hour: 14, minute: 0,  title: "Gift",                   cents: 10_000,  categoryKey: "other_expense"),

        // April to August: one row per category per month, matching the Charts mockup's totals.
        Entry(month: 4, day: 25, hour: 9,  minute: 0,  title: "Salary",                 cents: 500_000, categoryKey: "salary"),
        Entry(month: 4, day: 1,  hour: 9,  minute: 0,  title: "Rent",                   cents: 85_000,  categoryKey: "housing"),
        Entry(month: 4, day: 12, hour: 11, minute: 0,  title: "Groceries",              cents: 61_000,  categoryKey: "food"),
        Entry(month: 4, day: 18, hour: 15, minute: 0,  title: "Spring clothes",         cents: 52_000,  categoryKey: "shopping"),
        Entry(month: 4, day: 5,  hour: 8,  minute: 30, title: "Transit pass",           cents: 15_000,  categoryKey: "transport"),
        Entry(month: 4, day: 22, hour: 20, minute: 0,  title: "Movies and dinner",      cents: 18_000,  categoryKey: "entertainment"),

        Entry(month: 5, day: 25, hour: 9,  minute: 0,  title: "Salary",                 cents: 500_000, categoryKey: "salary"),
        Entry(month: 5, day: 14, hour: 16, minute: 0,  title: "Logo design",            cents: 40_000,  categoryKey: "freelance"),
        Entry(month: 5, day: 1,  hour: 9,  minute: 0,  title: "Rent",                   cents: 85_000,  categoryKey: "housing"),
        Entry(month: 5, day: 10, hour: 11, minute: 0,  title: "Groceries",              cents: 58_000,  categoryKey: "food"),
        Entry(month: 5, day: 20, hour: 18, minute: 0,  title: "Online course",          cents: 29_000,  categoryKey: "education"),
        Entry(month: 5, day: 5,  hour: 8,  minute: 30, title: "Transit pass",           cents: 15_000,  categoryKey: "transport"),
        Entry(month: 5, day: 16, hour: 10, minute: 0,  title: "Dentist",                cents: 27_000,  categoryKey: "health"),

        Entry(month: 6, day: 25, hour: 9,  minute: 0,  title: "Salary",                 cents: 500_000, categoryKey: "salary"),
        Entry(month: 6, day: 1,  hour: 9,  minute: 0,  title: "Rent",                   cents: 85_000,  categoryKey: "housing"),
        Entry(month: 6, day: 11, hour: 11, minute: 0,  title: "Groceries",              cents: 64_000,  categoryKey: "food"),
        Entry(month: 6, day: 21, hour: 7,  minute: 0,  title: "Weekend trip",           cents: 61_000,  categoryKey: "transport"),
        Entry(month: 6, day: 15, hour: 13, minute: 0,  title: "Headphones",             cents: 38_000,  categoryKey: "shopping"),

        Entry(month: 7, day: 25, hour: 9,  minute: 0,  title: "Salary",                 cents: 500_000, categoryKey: "salary"),
        Entry(month: 7, day: 9,  hour: 16, minute: 0,  title: "Website project",        cents: 65_000,  categoryKey: "freelance"),
        Entry(month: 7, day: 1,  hour: 9,  minute: 0,  title: "Rent",                   cents: 85_000,  categoryKey: "housing"),
        Entry(month: 7, day: 13, hour: 11, minute: 0,  title: "Groceries",              cents: 57_000,  categoryKey: "food"),
        Entry(month: 7, day: 5,  hour: 8,  minute: 30, title: "Transit pass",           cents: 15_000,  categoryKey: "transport"),
        Entry(month: 7, day: 19, hour: 21, minute: 0,  title: "Festival tickets",       cents: 41_000,  categoryKey: "entertainment"),

        Entry(month: 8, day: 25, hour: 9,  minute: 0,  title: "Salary",                 cents: 500_000, categoryKey: "salary"),
        Entry(month: 8, day: 1,  hour: 9,  minute: 0,  title: "Rent",                   cents: 85_000,  categoryKey: "housing"),
        Entry(month: 8, day: 10, hour: 11, minute: 0,  title: "Groceries",              cents: 60_500,  categoryKey: "food"),
        Entry(month: 8, day: 28, hour: 17, minute: 0,  title: "School supplies",        cents: 34_000,  categoryKey: "education"),
        Entry(month: 8, day: 5,  hour: 8,  minute: 30, title: "Transit pass",           cents: 15_000,  categoryKey: "transport"),
        Entry(month: 8, day: 17, hour: 12, minute: 0,  title: "Birthday present",       cents: 26_000,  categoryKey: "other_expense")
    ]
    // swiftlint:enable comma

    /// The Budget mockup: limits for September.
    private static let septemberBudgets: [(String, Int64)] = [
        ("entertainment", 8_000), ("food", 40_000), ("transport", 20_000), ("housing", 120_000), ("health", 15_000)
    ]

    /// Every title in Spanish as said in Mexico, which also serves Spanish outside Mexico and Spain.
    static let mexicanTitles: [String: String] = [
        "Groceries": "Despensa", "Coffee": "Café", "Pharmacy": "Farmacia",
        "Streaming subscription": "Suscripción de streaming", "Salary": "Sueldo", "Gas": "Gasolina",
        "Rent": "Renta", "Supermarket": "Supermercado", "Dinner out": "Cena fuera", "Farmers market": "Mercado",
        "Running shoes": "Tenis para correr", "Books": "Libros", "Transit pass": "Tarjeta de transporte",
        "Ride home": "Taxi a casa", "Concert tickets": "Boletos del concierto", "Vitamins": "Vitaminas",
        "Gift": "Regalo", "Spring clothes": "Ropa de primavera", "Movies and dinner": "Cine y cena",
        "Logo design": "Diseño de logo", "Online course": "Curso en línea", "Dentist": "Dentista",
        "Weekend trip": "Viaje de fin de semana", "Headphones": "Audífonos", "Website project": "Proyecto web",
        "Festival tickets": "Boletos del festival", "School supplies": "Útiles escolares",
        "Birthday present": "Regalo de cumpleaños"
    ]

    /// Only the titles said differently in Spain; the rest come from `mexicanTitles`.
    static let spainTitles: [String: String] = [
        "Groceries": "Compra", "Salary": "Nómina", "Rent": "Alquiler", "Running shoes": "Zapatillas de running",
        "Transit pass": "Abono de transporte", "Concert tickets": "Entradas del concierto",
        "Online course": "Curso online", "Headphones": "Auriculares", "Festival tickets": "Entradas del festival",
        "School supplies": "Material escolar"
    ]

    private static func date(year: Int = 2026, month: Int, day: Int, hour: Int, minute: Int,
                             timeZone: TimeZone) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return YearMonth.calendar(timeZone).date(from: components) ?? .distantPast
    }
}

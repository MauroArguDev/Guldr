//
//  RecapLibrary.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import GuldrCore
import SwiftData

/// Which months have a recap and what each says, read from the store (v1 plan, Phase 31).
enum RecapLibrary {

    /// Home offers last month's recap during the first days of a month (author's call, 2026-10-23).
    static let homeDays = 1...7

    /// Past months with anything in them (a logged day, or a transaction in the active currency), newest
    /// first, up to a year back.
    static func availableMonths(in context: ModelContext, currencyCode: String, now: Date,
                                timeZone: TimeZone) -> [YearMonth] {
        let current = YearMonth(containing: now, timeZone: timeZone)
        let oldest = current.adding(months: -12)
        var months = Set<YearMonth>()
        let days = (try? LoggedDays.all(in: context)) ?? [:]
        for day in days.keys {
            if let month = YearMonth(year: day.year, month: day.month) { months.insert(month) }
        }
        let start = oldest.dateInterval(in: timeZone).start
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.date >= start })
        for transaction in (try? context.fetch(descriptor)) ?? [] where transaction.currencyCode == currencyCode {
            months.insert(YearMonth(containing: transaction.date, timeZone: timeZone))
        }
        return months.filter { $0 < current && $0 >= oldest }.sorted(by: >)
    }

    /// Last month, while it's one of the first days of this one and the card wasn't closed.
    static func homeMonth(now: Date, timeZone: TimeZone, dismissed: YearMonth?, available: [YearMonth]) -> YearMonth? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard homeDays.contains(calendar.component(.day, from: now)) else { return nil }
        let last = YearMonth(containing: now, timeZone: timeZone).previous
        guard last != dismissed, available.contains(last) else { return nil }
        return last
    }

    /// As of now: the month's completeness and best streak depend on today.
    static func card(for month: YearMonth, in context: ModelContext, currencyCode: String, locale: Locale,
                     timeZone: TimeZone) -> RecapCard {
        let recap = MonthlyRecap(month: month,
                                 transactions: (try? context.fetch(FetchDescriptor<Transaction>())) ?? [],
                                 budgets: (try? context.fetch(FetchDescriptor<Budget>())) ?? [],
                                 loggedDays: (try? LoggedDays.all(in: context)) ?? [:],
                                 earned: (try? EarnedAchievements.all(in: context)) ?? [],
                                 currencyCode: currencyCode, now: .now, timeZone: timeZone)
        var name: String?
        if let id = recap.topCategory?.categoryID {
            let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.id == id })
            name = (try? context.fetch(descriptor))?.first?.displayName
        }
        return RecapCard(recap: recap, topCategoryName: name, locale: locale, timeZone: timeZone)
    }
}

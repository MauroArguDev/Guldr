//
//  TransactionQuery.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import SwiftData

/// The Transactions list's filters and its grouping by day.
///
/// Filtering runs in memory: a SwiftData predicate cannot do diacritic-insensitive matching, and
/// personal-finance volumes are small (5,000 transactions are measured in the tests). Reading a
/// model property goes through SwiftData's backing data, which is what made the list slow, so the
/// query works on `Item`s: plain copies of each transaction's values. Make them once when the data
/// changes (`Item(_:categoryName:)`) and filter, sort and group them as often as needed. The list shows
/// every currency, unlike totals (ADR 005).
public struct TransactionQuery: Equatable, Sendable {

    /// `nil` shows both kinds.
    public var kind: TransactionKind?
    /// Empty shows every category, including transactions without one.
    public var categoryIDs: Set<UUID>
    /// Every word must appear in the title, the note or the category's displayed name, ignoring case
    /// and accents: "cafe" finds "Café".
    public var searchText: String

    public init(kind: TransactionKind? = nil, categoryIDs: Set<UUID> = [], searchText: String = "") {
        self.kind = kind
        self.categoryIDs = categoryIDs
        self.searchText = searchText
    }

    /// Whether any filter is set; the list shows a "no results" state instead of "no transactions".
    public var isFiltering: Bool {
        kind != nil || !categoryIDs.isEmpty || !searchTerms.isEmpty
    }

    /// One transaction's values, copied out of SwiftData once so filtering and grouping never touch the store.
    public struct Item: Identifiable, Equatable, Sendable {
        /// The transaction's own ID.
        public let id: UUID
        /// For fetching the transaction again, e.g. to edit or delete it.
        public let modelID: PersistentIdentifier
        public let date: Date
        public let createdAt: Date
        public let kind: TransactionKind
        public let amount: Money
        public let title: String
        public let note: String
        public let categoryID: UUID?
        /// The name the user sees, or `nil` without a category.
        public let categoryName: String?
        public let categorySymbol: String?

        /// - Parameter categoryName: the name the user sees for a category, which for seeded categories is
        ///   the app's translation (`Category.usesDefaultName`). Search matches that name, not the stored one.
        public init(_ transaction: Transaction, categoryName: (Category) -> String = { $0.name }) {
            let category = transaction.category
            id = transaction.id
            modelID = transaction.persistentModelID
            date = transaction.date
            createdAt = transaction.createdAt
            kind = transaction.kind
            amount = transaction.amount
            title = transaction.title
            note = transaction.note
            categoryID = category?.id
            self.categoryName = category.map(categoryName)
            categorySymbol = category?.symbolName
        }
    }

    /// Matching items, newest first.
    public func apply(to items: some Sequence<Item>) -> [Item] {
        let terms = searchTerms
        return items
            .filter { matches($0, terms: terms) }
            .sorted(by: Self.newestFirst)
    }

    /// Matching transactions, newest first, as items. Reads every transaction; to filter the same data
    /// more than once, make the items once and use `apply(to:)` on them.
    public func apply(to transactions: some Sequence<Transaction>,
                      categoryName: (Category) -> String = { $0.name }) -> [Item] {
        apply(to: transactions.map { Item($0, categoryName: categoryName) })
    }

    /// Splits items into days in `timeZone`, newest day first. Within a day the order is kept, so pass
    /// the output of `apply(to:)`.
    public static func groupedByDay(_ items: [Item], timeZone: TimeZone = .autoupdatingCurrent) -> [DaySection] {
        let calendar = YearMonth.calendar(timeZone)
        var sections: [DaySection] = []
        var currentDay: DateInterval?
        for item in items {
            let date = item.date
            // Sorted input stays in the same day for many rows; ask the calendar only when it changes.
            if let day = currentDay, date >= day.start, date < day.end, let last = sections.indices.last {
                sections[last].items.append(item)
                continue
            }
            let day = calendar.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 0)
            currentDay = day
            if let index = sections.firstIndex(where: { $0.day == day.start }) {
                sections[index].items.append(item)
            } else {
                sections.append(DaySection(day: day.start, items: [item]))
            }
        }
        return sections.sorted { $0.day > $1.day }
    }

    /// One day of the list. Its header label comes from `DayLabelFormatter`.
    public struct DaySection: Identifiable, Sendable {
        /// Start of the day in the grouping time zone.
        public let day: Date
        public fileprivate(set) var items: [Item]

        public var id: Date { day }

        /// Income minus expenses of the day in `currencyCode`; other currencies are left out.
        public func net(currencyCode: String) throws(MoneyError) -> Money {
            let code = try Currency.validatedCode(currencyCode)
            var tally = Tally()
            for item in items where item.amount.currencyCode == code {
                switch item.kind {
                case .income: try tally.add(item.amount.minorUnits)
                case .expense: try tally.subtract(item.amount.minorUnits)
                }
            }
            return tally.money(code)
        }
    }

    // MARK: - Private

    private var searchTerms: [String] {
        searchText.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private func matches(_ item: Item, terms: [String]) -> Bool {
        if let kind, item.kind != kind { return false }
        if !categoryIDs.isEmpty {
            guard let id = item.categoryID, categoryIDs.contains(id) else { return false }
        }
        guard !terms.isEmpty else { return true }
        let fields = [item.title, item.note, item.categoryName ?? ""]
        return terms.allSatisfy { term in
            fields.contains { $0.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    /// Newest first; the creation time and then the ID break ties, so equal dates keep a stable order.
    private static func newestFirst(_ lhs: Item, _ rhs: Item) -> Bool {
        if lhs.date != rhs.date { return lhs.date > rhs.date }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

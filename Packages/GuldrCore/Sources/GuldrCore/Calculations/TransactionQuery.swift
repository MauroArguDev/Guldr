//
//  TransactionQuery.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation

/// The Transactions list's filters and its grouping by day.
///
/// Filtering runs in memory: a SwiftData predicate cannot do diacritic-insensitive matching, and
/// personal-finance volumes are small (5,000 transactions are measured in the tests). Reading a
/// model property goes through SwiftData's backing data, so each value is read once and the sort and
/// grouping work on those copies. The list shows every currency, unlike totals (ADR 005).
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

    /// Matching transactions, newest first.
    ///
    /// - Parameter categoryName: the name the user sees for a category, which for seeded categories is
    ///   the app's translation (`Category.usesDefaultName`). Search matches that name, not the stored one.
    public func apply(to transactions: some Sequence<Transaction>,
                      categoryName: (Category) -> String = { $0.name }) -> [Transaction] {
        let terms = searchTerms
        return transactions
            .filter { matches($0, terms: terms, categoryName: categoryName) }
            .map { SortKey(transaction: $0, date: $0.date, createdAt: $0.createdAt, id: $0.id) }
            .sorted(by: SortKey.newestFirst)
            .map(\.transaction)
    }

    /// Splits transactions into days in `timeZone`, newest day first. Within a day the order is kept,
    /// so pass the output of `apply(to:)`.
    public static func groupedByDay(_ transactions: [Transaction],
                                    timeZone: TimeZone = .autoupdatingCurrent) -> [DaySection] {
        let calendar = YearMonth.calendar(timeZone)
        var sections: [DaySection] = []
        var currentDay: DateInterval?
        for transaction in transactions {
            let date = transaction.date
            // Sorted input stays in the same day for many rows; ask the calendar only when it changes.
            if let day = currentDay, date >= day.start, date < day.end, let last = sections.indices.last {
                sections[last].transactions.append(transaction)
                continue
            }
            let day = calendar.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 0)
            currentDay = day
            if let index = sections.firstIndex(where: { $0.day == day.start }) {
                sections[index].transactions.append(transaction)
            } else {
                sections.append(DaySection(day: day.start, transactions: [transaction]))
            }
        }
        return sections.sorted { $0.day > $1.day }
    }

    /// One day of the list. Its header label comes from `DayLabelFormatter`.
    public struct DaySection: Identifiable {
        /// Start of the day in the grouping time zone.
        public let day: Date
        public fileprivate(set) var transactions: [Transaction]

        public var id: Date { day }

        /// Income minus expenses of the day in `currencyCode`; other currencies are left out.
        public func net(currencyCode: String) throws(MoneyError) -> Money {
            let code = try Currency.validatedCode(currencyCode)
            var tally = Tally()
            for transaction in transactions where transaction.currencyCode == code {
                switch transaction.kind {
                case .income: try tally.add(transaction.amountMinorUnits)
                case .expense: try tally.subtract(transaction.amountMinorUnits)
                }
            }
            return tally.money(code)
        }
    }

    // MARK: - Private

    private var searchTerms: [String] {
        searchText.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private func matches(_ transaction: Transaction, terms: [String], categoryName: (Category) -> String) -> Bool {
        if let kind, transaction.kind != kind { return false }
        if !categoryIDs.isEmpty {
            guard let id = transaction.category?.id, categoryIDs.contains(id) else { return false }
        }
        guard !terms.isEmpty else { return true }
        let fields = [transaction.title, transaction.note, transaction.category.map(categoryName) ?? ""]
        return terms.allSatisfy { term in
            fields.contains { $0.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    private struct SortKey {
        let transaction: Transaction
        let date: Date
        let createdAt: Date
        let id: UUID

        /// Newest first; the creation time and then the ID break ties, so equal dates keep a stable order.
        static func newestFirst(_ lhs: SortKey, _ rhs: SortKey) -> Bool {
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}

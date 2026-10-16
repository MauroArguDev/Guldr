//
//  TransactionsListModel.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 15/10/26.
//

import Foundation
import GuldrCore
import Observation
import SwiftData

/// The Transactions list's filters, its day sections and deletion.
///
/// The view owns the `@Query`s for transactions and categories and passes their results in, so SwiftData
/// keeps the list and the filter menu current; this model only filters, groups and turns models into
/// display values with `TransactionQuery`. The expensive parts, reading SwiftData properties and
/// formatting times and day titles, happen once per data change (`update`): the values are copied into
/// `TransactionQuery.Item`s and each row is built then. Filters and search only re-run the query on those
/// copies and regroup the prebuilt rows, a few milliseconds for 5,000 transactions. The sections are
/// kept, not recomputed on every render. It holds no context, so the view can create it before its environment
/// exists. Deleting saves the given context, rolls it back on failure and throws a typed
/// `ListError`, like the add sheet.
@Observable
final class TransactionsListModel {

    /// The segmented control above the list.
    enum KindFilter: Hashable, CaseIterable {
        case all
        case income
        case expenses

        var kind: TransactionKind? {
            switch self {
            case .all: nil
            case .income: .income
            case .expenses: .expense
            }
        }
    }

    enum ListError: Error, Equatable {
        case deleteFailed
    }

    /// What the list shows when it has no rows: a new user's invitation, or a hint that filters hide everything.
    enum EmptyState: Equatable {
        case noTransactions
        case noResults
    }

    /// One day of the list, ready to draw.
    struct Section: Identifiable, Equatable {
        /// Start of the day; also the section's identity.
        let id: Date
        /// "Today", "Yesterday", "Thursday, Sep 25".
        let title: String
        /// Income minus expenses in the active currency; `nil` when the day has nothing in it (ADR 005).
        let net: Money?
        let rows: [Row]
    }

    /// One transaction, as `TransactionRow` draws it.
    struct Row: Identifiable, Equatable {
        let id: PersistentIdentifier
        /// The description, or the category's name when it is empty, as in the add sheet.
        let title: String
        /// "Food · 9:41".
        let meta: String
        let symbol: String
        let amount: Money
        let kind: TransactionKind
    }

    // MARK: - Filters

    var searchText: String {
        get { query.searchText }
        set { query.searchText = newValue }
    }

    /// Switching kind drops selected categories of the other kind, which could only hide every row.
    var kindFilter: KindFilter = .all {
        didSet {
            query.kind = kindFilter.kind
            guard let kind = kindFilter.kind else { return }
            selectedCategoryKinds = selectedCategoryKinds.filter { $0.value == kind }
        }
    }

    /// Categories chosen in the toolbar's filter menu. Empty shows every category.
    var selectedCategoryIDs: Set<UUID> { query.categoryIDs }

    var isFilteringByCategory: Bool { !selectedCategoryKinds.isEmpty }

    /// The filter menu's options: the given categories narrowed to the selected kind.
    func categoryOptions(from categories: [Category]) -> [Category] {
        guard let kind = kindFilter.kind else { return categories }
        return categories.filter { $0.kind == kind }
    }

    func toggleCategory(_ category: Category) {
        if selectedCategoryKinds[category.id] == nil {
            selectedCategoryKinds[category.id] = category.kind
        } else {
            selectedCategoryKinds[category.id] = nil
        }
    }

    func clearCategories() {
        selectedCategoryKinds = [:]
    }

    // MARK: - Init

    init(locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent,
         now: @escaping () -> Date = { .now }) {
        self.locale = locale
        self.timeZone = timeZone
        self.now = now
    }

    // MARK: - Sections

    /// The transactions that pass the filters, newest first, in day sections.
    private(set) var sections: [Section] = []

    /// `nil` while the list has rows.
    var emptyState: EmptyState? {
        guard sections.isEmpty else { return nil }
        return query.isFiltering ? .noResults : .noTransactions
    }

    /// Takes the latest transactions and active currency and rebuilds the sections. The view calls it when
    /// its query's results change and after a save, since an edited transaction keeps its identity.
    func update(transactions: [Transaction], currencyCode: String) {
        // Seeded names are translated through the String Catalog on every read; a few categories cover
        // thousands of rows, so each name is looked up once.
        var names: [PersistentIdentifier: String] = [:]
        items = transactions.map { transaction in
            TransactionQuery.Item(transaction) { category in
                if let cached = names[category.persistentModelID] { return cached }
                let name = category.displayName
                names[category.persistentModelID] = name
                return name
            }
        }
        self.currencyCode = currencyCode
        let timeStyle = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone)
        let uncategorized = String(localized: "Uncategorized")
        rows = Dictionary(items.map { item in
            let categoryName = item.categoryName ?? uncategorized
            return (item.id, Row(id: item.modelID,
                                 title: item.title.isEmpty ? categoryName : item.title,
                                 meta: categoryName + " · " + item.date.formatted(timeStyle),
                                 symbol: item.categorySymbol ?? "questionmark",
                                 amount: item.amount,
                                 kind: item.kind))
        }, uniquingKeysWith: { first, _ in first })
        dayTitles = [:]
        rebuild()
    }

    // MARK: - Delete

    /// Deletes a transaction. One that no longer exists counts as deleted.
    func delete(_ id: PersistentIdentifier, in context: ModelContext,
                notifier: DataChangeNotifier) throws(ListError) {
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.persistentModelID == id })
        guard let transaction = (try? context.fetch(descriptor))?.first else { return }
        context.delete(transaction)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw .deleteFailed
        }
        notifier.dataDidChange()
    }

    // MARK: - Private

    private var query = TransactionQuery() {
        didSet {
            if query != oldValue { rebuild() }
        }
    }
    /// The selected categories with their kinds, so switching kind can drop the other kind's.
    private var selectedCategoryKinds: [UUID: TransactionKind] = [:] {
        didSet { query.categoryIDs = Set(selectedCategoryKinds.keys) }
    }

    @ObservationIgnored private var items: [TransactionQuery.Item] = []
    /// Each item's row, built once per data change and keyed by the transaction's ID.
    @ObservationIgnored private var rows: [UUID: Row] = [:]
    @ObservationIgnored private var dayTitles: [Date: String] = [:]
    @ObservationIgnored private var currencyCode = ""
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let timeZone: TimeZone
    @ObservationIgnored private let now: () -> Date

    private func rebuild() {
        let days = TransactionQuery.groupedByDay(query.apply(to: items), timeZone: timeZone)
        let labels = DayLabelFormatter(locale: locale, timeZone: timeZone)
        let reference = now()
        sections = days.map { day in
            Section(id: day.id,
                    title: dayTitle(for: day.day, labels: labels, reference: reference),
                    net: net(of: day),
                    rows: day.items.compactMap { rows[$0.id] })
        }
    }

    /// Day titles are kept until the next data change. "Today" stays right while the app is open across
    /// midnight only until then, which the next save or relaunch fixes.
    private func dayTitle(for day: Date, labels: DayLabelFormatter, reference: Date) -> String {
        if let title = dayTitles[day] { return title }
        let title = labels.label(for: day, relativeTo: reference)
        dayTitles[day] = title
        return title
    }

    private func net(of day: TransactionQuery.DaySection) -> Money? {
        guard day.items.contains(where: { $0.amount.currencyCode == currencyCode }) else { return nil }
        return try? day.net(currencyCode: currencyCode)
    }
}

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
/// display values with `TransactionQuery`. It holds no context, so the view can create it before its
/// environment exists. Deleting saves the given context, rolls it back on failure and throws a typed
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
    func sections(from transactions: [Transaction], currencyCode: String) -> [Section] {
        let filtered = query.apply(to: transactions, categoryName: \.displayName)
        let days = TransactionQuery.groupedByDay(filtered, timeZone: timeZone)
        let labels = DayLabelFormatter(locale: locale, timeZone: timeZone)
        let reference = now()
        return days.map { day in
            Section(id: day.id,
                    title: labels.label(for: day.day, relativeTo: reference),
                    net: net(of: day, currencyCode: currencyCode),
                    rows: day.transactions.map(row(for:)))
        }
    }

    /// `nil` while the list has rows.
    func emptyState(for sections: [Section]) -> EmptyState? {
        guard sections.isEmpty else { return nil }
        return query.isFiltering ? .noResults : .noTransactions
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

    private var query = TransactionQuery()
    /// The selected categories with their kinds, so switching kind can drop the other kind's.
    private var selectedCategoryKinds: [UUID: TransactionKind] = [:] {
        didSet { query.categoryIDs = Set(selectedCategoryKinds.keys) }
    }

    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let timeZone: TimeZone
    @ObservationIgnored private let now: () -> Date

    private func net(of day: TransactionQuery.DaySection, currencyCode: String) -> Money? {
        guard day.transactions.contains(where: { $0.currencyCode == currencyCode }) else { return nil }
        return try? day.net(currencyCode: currencyCode)
    }

    private func row(for transaction: Transaction) -> Row {
        let categoryName = transaction.category?.displayName ?? String(localized: "Uncategorized")
        let time = transaction.date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone)
        )
        return Row(id: transaction.persistentModelID,
                   title: transaction.title.isEmpty ? categoryName : transaction.title,
                   meta: categoryName + " · " + time,
                   symbol: transaction.category?.symbolName ?? "questionmark",
                   amount: transaction.amount,
                   kind: transaction.kind)
    }
}

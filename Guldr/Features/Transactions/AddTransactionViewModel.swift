//
//  AddTransactionViewModel.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 15/10/26.
//

import Foundation
import GuldrCore
import Observation
import SwiftData

/// The add sheet's state and actions, for a new transaction or an existing one.
///
/// Nothing touches the store until `save()`: the form edits plain values, so Cancel needs no undo.
/// `save()` and `delete()` save the context themselves, roll it back on failure and throw a typed
/// `EditorError`; the sheet shows it instead of crashing.
@Observable
final class AddTransactionViewModel {

    enum Issue: Hashable {
        case missingAmount
        case missingCategory
    }

    enum EditorError: Error, Equatable {
        /// The active currency is not a known ISO 4217 code.
        case invalidCurrency
        /// The transaction to edit no longer exists.
        case transactionNotFound
        /// `save()` was called while `issues` is not empty.
        case incomplete
        case saveFailed
        case deleteFailed
    }

    /// What the save did, so the app can play the right haptic (DESIGN.md › Motion).
    enum SaveOutcome: Equatable {
        case saved
        /// The save pushed at least one category over its budget for that month.
        case crossedBudget
    }

    // MARK: - Form state

    private(set) var kind: TransactionKind
    private(set) var amount: AmountInput
    private(set) var category: Category?
    var title: String
    var date: Date
    /// The pickable categories of the current kind, in display order.
    private(set) var categories: [Category] = []

    var isEditing: Bool { editedTransaction != nil }

    var issues: Set<Issue> {
        var issues: Set<Issue> = []
        if amount.minorUnits == 0 { issues.insert(.missingAmount) }
        if category == nil { issues.insert(.missingCategory) }
        return issues
    }

    var canSave: Bool { issues.isEmpty }

    /// Whether closing the sheet would lose input: anything typed or picked on a new transaction, any
    /// change on an edited one. The sheet blocks swipe-to-dismiss while this is true; Cancel still works.
    var hasChanges: Bool {
        guard let transaction = editedTransaction else {
            return !amount.isEmpty || category != nil || !title.isEmpty
        }
        return amount.money != transaction.amount || kind != transaction.kind || category != transaction.category
            || title != transaction.title || date != transaction.date
    }

    /// Shown in the empty description field: what the transaction will be called if left empty.
    var titlePrompt: String? { category?.displayName }

    // MARK: - Init

    /// A new transaction in the active currency, dated now.
    init(context: ModelContext, currencyCode: String, kind: TransactionKind = .expense,
         notifier: DataChangeNotifier, now: Date = .now, timeZone: TimeZone = .autoupdatingCurrent) throws(EditorError) {
        do {
            amount = try AmountInput(currencyCode: currencyCode)
        } catch {
            throw .invalidCurrency
        }
        self.context = context
        self.notifier = notifier
        self.timeZone = timeZone
        self.kind = kind
        title = ""
        date = now
        reloadCategories()
    }

    /// An existing transaction, prefilled. It keeps its own currency, which may differ from the active one.
    init(editing id: PersistentIdentifier, context: ModelContext, notifier: DataChangeNotifier,
         timeZone: TimeZone = .autoupdatingCurrent) throws(EditorError) {
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.persistentModelID == id })
        guard let transaction = (try? context.fetch(descriptor))?.first else { throw .transactionNotFound }
        do {
            amount = try AmountInput(money: transaction.amount)
        } catch {
            throw .invalidCurrency
        }
        self.context = context
        self.notifier = notifier
        self.timeZone = timeZone
        editedTransaction = transaction
        kind = transaction.kind
        category = transaction.category
        title = transaction.title
        date = transaction.date
        reloadCategories()
    }

    // MARK: - Input

    /// Switching kind keeps the amount and drops a category of the other kind.
    func setKind(_ newKind: TransactionKind) {
        guard newKind != kind else { return }
        kind = newKind
        if category?.kind != newKind { category = nil }
        reloadCategories()
    }

    func select(_ category: Category) {
        guard category.kind == kind else { return }
        self.category = category
    }

    /// Each returns whether the key was accepted, so the keypad can skip the haptic for a rejected one.
    @discardableResult
    func pressDigit(_ digit: Int) -> Bool { amount.appendDigit(digit) }

    @discardableResult
    func pressDecimalSeparator() -> Bool { amount.appendDecimalSeparator() }

    @discardableResult
    func pressDelete() -> Bool { amount.deleteBackward() }

    /// Currencies without minor units (JPY) have no decimal key.
    var acceptsDecimals: Bool { amount.fractionDigitLimit > 0 }

    // MARK: - Save and delete

    /// Inserts or updates the transaction. An empty description is stored empty and shown as the
    /// category's name, so it follows the category if it is renamed or translated.
    @discardableResult
    func save() throws(EditorError) -> SaveOutcome {
        guard canSave, let category else { throw .incomplete }
        let month = YearMonth(containing: date, timeZone: timeZone)
        let before = kind == .expense ? budgetStatus(for: month, currencyCode: amount.currencyCode) : nil

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let transaction = editedTransaction {
            transaction.amount = amount.money
            transaction.kind = kind
            transaction.title = trimmedTitle
            transaction.date = date
            transaction.category = category
            transaction.updatedAt = .now
        } else {
            context.insert(Transaction(amount: amount.money, kind: kind, title: trimmedTitle,
                                       date: date, category: category))
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw .saveFailed
        }
        notifier.dataDidChange()

        // The save already succeeded: if the budget can't be computed, it simply plays the normal haptic.
        guard let before, let after = budgetStatus(for: month, currencyCode: amount.currencyCode),
              !after.categoriesNewlyOver(since: before).isEmpty else { return .saved }
        return .crossedBudget
    }

    /// Deletes the edited transaction. Does nothing for a new one.
    func delete() throws(EditorError) {
        guard let transaction = editedTransaction else { return }
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

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let notifier: DataChangeNotifier
    @ObservationIgnored private let timeZone: TimeZone
    @ObservationIgnored private var editedTransaction: Transaction?

    /// Archived categories are hidden, except the one an edited transaction already uses, so editing
    /// never silently changes its category.
    private func reloadCategories() {
        var pickable = (try? context.fetch(Category.pickable(kind))) ?? []
        if let current = editedTransaction?.category, current.isArchived, current.kind == kind {
            pickable.append(current)
        }
        categories = pickable
    }

    /// The month's budgets as stored right now, or `nil` if they can't be read or summed.
    private func budgetStatus(for month: YearMonth, currencyCode: String) -> BudgetStatus? {
        let monthKey = month.rawValue
        let interval = month.dateInterval(in: timeZone)
        let start = interval.start
        let end = interval.end
        guard let budgets = try? context.fetch(FetchDescriptor<Budget>(predicate: #Predicate { $0.yearMonth == monthKey })),
              !budgets.isEmpty,
              let transactions = try? context.fetch(FetchDescriptor<Transaction>(
                  predicate: #Predicate { $0.date >= start && $0.date < end }
              )) else { return nil }
        return try? BudgetStatus(budgets: budgets, transactions: transactions, month: month,
                                 currencyCode: currencyCode, timeZone: timeZone)
    }
}

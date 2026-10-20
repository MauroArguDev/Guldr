//
//  EditBudgetModel.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 20/10/26.
//

import Foundation
import GuldrCore
import Observation
import SwiftData

/// The edit budgets sheet's state: one limit per expense category for one month, typed as text with the
/// system decimal keyboard (author's call, 2026-10-20). An empty field means no budget.
///
/// Like the add sheet, nothing touches the store until `save()`, so Cancel needs no undo; `save()` saves
/// the context itself, rolls it back on failure and throws a typed `EditorError`.
@Observable
final class EditBudgetModel {

    enum EditorError: Error, Equatable {
        /// The active currency is not a known ISO 4217 code.
        case invalidCurrency
        /// `save()` was called while a field holds something that is not a positive amount.
        case invalidAmounts
        case saveFailed
    }

    /// One expense category's limit as typed.
    struct Field: Identifiable, Equatable {
        /// The category's ID.
        let id: UUID
        let name: String
        let symbol: String
        var text: String
    }

    let month: YearMonth
    var fields: [Field]
    /// Whether last month has budgets in the active currency to copy.
    private(set) var canCopyLastMonth: Bool

    init(month: YearMonth, context: ModelContext, currencyCode: String, notifier: DataChangeNotifier,
         locale: Locale = .autoupdatingCurrent) throws(EditorError) {
        guard let code = try? Currency.validatedCode(currencyCode),
              let digits = try? Currency.minorUnitDigits(for: code) else { throw .invalidCurrency }
        self.month = month
        self.context = context
        self.currencyCode = code
        self.fractionDigits = digits
        self.notifier = notifier
        self.locale = locale

        categories = (try? context.fetch(Category.pickable(.expense))) ?? []
        existing = Self.budgetsByCategory(in: month, currencyCode: code, context: context)
        lastMonth = Self.budgetsByCategory(in: month.previous, currencyCode: code, context: context)
        canCopyLastMonth = !lastMonth.isEmpty
        fields = []
        fields = categories.map { category in
            Field(id: category.id, name: category.displayName, symbol: category.symbolName,
                  text: existing[category.id]?.first.map { text(for: $0.limit) } ?? "")
        }
        originalFields = fields
    }

    var hasChanges: Bool { fields != originalFields }

    /// Fields whose text is not empty and not a positive amount ("0", "abc", too many digits).
    var invalidFieldIDs: Set<UUID> {
        Set(fields.filter { !isBlank($0.text) && amount(from: $0.text) == nil }.map(\.id))
    }

    var canSave: Bool { hasChanges && invalidFieldIDs.isEmpty }

    /// The sum of every valid limit, for the form's total row; `nil` while none is set.
    var total: Money? {
        let minorUnits = fields.compactMap { amount(from: $0.text)?.minorUnits }
        guard !minorUnits.isEmpty else { return nil }
        return try? Money(minorUnits: minorUnits.reduce(0, +), currencyCode: currencyCode)
    }

    /// Replaces every field with last month's limits: a category without one last month is left empty.
    /// Nothing is saved until `save()`.
    func copyLastMonth() {
        for index in fields.indices {
            fields[index].text = lastMonth[fields[index].id]?.first.map { text(for: $0.limit) } ?? ""
        }
    }

    /// Inserts, updates and deletes the month's budgets so they match the fields. Extra budgets for one
    /// category (possible without unique constraints) are removed, keeping the one `BudgetStatus` reads.
    func save() throws(EditorError) {
        guard invalidFieldIDs.isEmpty else { throw .invalidAmounts }
        let categoriesByID = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for field in fields {
            let budgets = existing[field.id] ?? []
            guard let limit = amount(from: field.text) else {
                budgets.forEach { context.delete($0) }
                continue
            }
            if let budget = budgets.first {
                if budget.limit != limit { budget.limit = limit }
                budgets.dropFirst().forEach { context.delete($0) }
            } else {
                context.insert(Budget(month: month, limit: limit, category: categoriesByID[field.id]))
            }
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw .saveFailed
        }
        notifier.dataDidChange()
    }

    // MARK: - Private

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let currencyCode: String
    @ObservationIgnored private let fractionDigits: Int
    @ObservationIgnored private let notifier: DataChangeNotifier
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let categories: [Category]
    /// This month's budgets per category, the one `BudgetStatus` reads (smallest ID) first.
    @ObservationIgnored private let existing: [UUID: [Budget]]
    @ObservationIgnored private let lastMonth: [UUID: [Budget]]
    @ObservationIgnored private var originalFields: [Field] = []

    private static func budgetsByCategory(in month: YearMonth, currencyCode: String,
                                          context: ModelContext) -> [UUID: [Budget]] {
        let key = month.rawValue
        let descriptor = FetchDescriptor<Budget>(predicate: #Predicate { $0.yearMonth == key })
        let budgets = ((try? context.fetch(descriptor)) ?? []).filter { $0.currencyCode == currencyCode }
        var byCategory: [UUID: [Budget]] = [:]
        for budget in budgets {
            guard let categoryID = budget.category?.id else { continue }
            byCategory[categoryID, default: []].append(budget)
        }
        return byCategory.mapValues { $0.sorted { $0.id.uuidString < $1.id.uuidString } }
    }

    private func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// A positive amount in the active currency, read in the user's locale ("1,250.5" in en-US,
    /// "1.250,5" in es-ES). More fraction digits than the currency has, or more than
    /// `AmountInput.maxIntegerDigits` whole digits, are rejected rather than rounded.
    private func amount(from text: String) -> Money? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let value = try? Decimal(trimmed, format: Decimal.FormatStyle(locale: locale)),
              value > 0, value < Self.integerLimit,
              let money = try? Money(value, currencyCode: currencyCode),
              money.decimalValue == value else { return nil }
        return money
    }

    private static let integerLimit: Decimal = pow(10, AmountInput.maxIntegerDigits)

    /// How a stored limit reads in its field: "3000" for whole amounts, "42.80" otherwise, without
    /// grouping so it edits cleanly.
    private func text(for limit: Money) -> String {
        let style = Decimal.FormatStyle(locale: locale).grouping(.never)
        let isWhole = limit.minorUnits % Int64(pow(10, Double(fractionDigits))) == 0
        return limit.decimalValue.formatted(style.precision(.fractionLength(isWhole ? 0 : fractionDigits)))
    }
}

//
//  Category.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 9/10/26.
//

import Foundation
import SwiftData

extension SchemaV1 {

    /// A group of transactions for one kind, shown with an SF Symbol and a base color (ADR 008, 009).
    ///
    /// Seeded categories carry a stable `systemKey`; custom ones have `nil`. Categories are archived
    /// rather than deleted so past totals stay correct.
    @Model
    public final class Category {

        public var id = UUID()
        public var systemKey: String?
        public var name = ""
        public var symbolName = ""
        public var colorKey = CategoryColor.graphite.rawValue
        public var kindRawValue = TransactionKind.expense.rawValue
        public var sortOrder = 0
        public var isArchived = false

        // Deleting a category keeps its transactions, now without a category. In practice the app
        // archives instead, and only deletes categories that have no transactions.
        @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
        public var transactions: [Transaction]? = []

        // Budgets are per category in v1, so they have no meaning once the category is gone.
        @Relationship(deleteRule: .cascade, inverse: \Budget.category)
        public var budgets: [Budget]? = []

        public init(name: String, symbolName: String, color: CategoryColor, kind: TransactionKind,
                    sortOrder: Int = 0, systemKey: String? = nil) {
            self.name = name
            self.symbolName = symbolName
            self.colorKey = color.rawValue
            self.kindRawValue = kind.rawValue
            self.sortOrder = sortOrder
            self.systemKey = systemKey
        }

        /// Falls back to `.graphite` for a key written by a newer version of the app.
        public var color: CategoryColor {
            get { CategoryColor(rawValue: colorKey) ?? .graphite }
            set { colorKey = newValue.rawValue }
        }

        /// Falls back to `.expense` for a raw value written by a newer version of the app.
        public var kind: TransactionKind {
            get { TransactionKind(rawValue: kindRawValue) ?? .expense }
            set { kindRawValue = newValue.rawValue }
        }

        /// Whether the name is still the seeded English name, so the app should show its translation.
        /// `false` for custom categories and for seeded ones the user renamed.
        public var usesDefaultName: Bool {
            guard let systemKey else { return false }
            return DefaultCategory.named(systemKey)?.name == name
        }
    }
}

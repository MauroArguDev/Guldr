//
//  Transaction.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 9/10/26.
//

import Foundation
import SwiftData

extension SchemaV1 {

    /// One income or expense.
    ///
    /// CloudKit rules (ADR 007): every stored property has a default, nothing is unique and the
    /// relationship is optional. The amount is the absolute value in minor units; the sign comes from
    /// `kind` (ADR 005).
    @Model
    public final class Transaction {

        public var id = UUID()
        public var amountMinorUnits: Int64 = 0
        public var currencyCode = ""
        public var kindRawValue = TransactionKind.expense.rawValue
        public var title = ""
        public var note = ""
        public var date = Date.now
        public var createdAt = Date.now
        public var updatedAt = Date.now
        public var category: Category?

        public init(amount: Money, kind: TransactionKind, title: String = "", note: String = "",
                    date: Date = .now, category: Category? = nil) {
            self.amountMinorUnits = amount.minorUnits
            self.currencyCode = amount.currencyCode
            self.kindRawValue = kind.rawValue
            self.title = title
            self.note = note
            self.date = date
            self.category = category
        }

        /// Falls back to `.expense` for a raw value written by a newer version of the app.
        public var kind: TransactionKind {
            get { TransactionKind(rawValue: kindRawValue) ?? .expense }
            set { kindRawValue = newValue.rawValue }
        }

        /// The stored amount. Setting it replaces both the minor units and the currency.
        public var amount: Money {
            get { Money.unchecked(amountMinorUnits, currencyCode) }
            set {
                amountMinorUnits = newValue.minorUnits
                currencyCode = newValue.currencyCode
            }
        }
    }
}

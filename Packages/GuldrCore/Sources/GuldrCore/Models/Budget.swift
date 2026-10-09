//
//  Budget.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 9/10/26.
//

import Foundation
import SwiftData

extension SchemaV1 {

    /// A spending limit for one category in one month (ADR 008), in the active currency (ADR 005).
    @Model
    public final class Budget {

        public var id = UUID()
        /// `YearMonth.rawValue`, e.g. `202610`.
        public var yearMonth = 0
        public var limitMinorUnits: Int64 = 0
        public var currencyCode = ""
        public var category: Category?

        public init(month: YearMonth, limit: Money, category: Category? = nil) {
            self.yearMonth = month.rawValue
            self.limitMinorUnits = limit.minorUnits
            self.currencyCode = limit.currencyCode
            self.category = category
        }

        /// `nil` only if the stored value is corrupt.
        public var month: YearMonth? {
            YearMonth(rawValue: yearMonth)
        }

        /// Setting it replaces both the minor units and the currency.
        public var limit: Money {
            get { Money.unchecked(limitMinorUnits, currencyCode) }
            set {
                limitMinorUnits = newValue.minorUnits
                currencyCode = newValue.currencyCode
            }
        }
    }
}

//
//  PreviewSupport.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

#if DEBUG
import Foundation
import GuldrCore

extension Money {
    /// Previews only, compiled out of release builds. USD is a valid ISO 4217 code, so this cannot fail.
    static func previewUSD(_ cents: Int64) -> Money {
        // swiftlint:disable:next force_try
        try! Money(minorUnits: cents, currencyCode: "USD") // Valid code, debug-only previews.
    }
}

extension BudgetStatus.Line {
    /// Previews only: a USD budget line with `spent` of `limit` cents.
    static func preview(_ spent: Int64, of limit: Int64) -> BudgetStatus.Line {
        BudgetStatus.Line(budgetID: UUID(), categoryID: UUID(), spent: .previewUSD(spent), limit: .previewUSD(limit))
    }
}
#endif

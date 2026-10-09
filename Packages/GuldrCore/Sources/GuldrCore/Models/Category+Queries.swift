//
//  Category+Queries.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 9/10/26.
//

import Foundation
import SwiftData

extension SchemaV1.Category {

    /// Categories a user can pick for a new transaction or budget: one kind, not archived, in display
    /// order. Archived categories stay in the store, so history and totals that reference them still work.
    public static func pickable(_ kind: TransactionKind) -> FetchDescriptor<Category> {
        let kindRawValue = kind.rawValue
        return FetchDescriptor(
            predicate: #Predicate { $0.kindRawValue == kindRawValue && !$0.isArchived },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
    }
}

//
//  ModelAliases.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 15/10/26.
//

import GuldrCore

// Outside GuldrCore, `Transaction` collides with SwiftUI's and `Category` with the Objective-C runtime
// typedef that Foundation re-exports. Module-level aliases win over imported names (ARCHITECTURE.md › Data).
typealias Transaction = GuldrCore.Transaction
typealias Category = GuldrCore.Category
typealias Budget = GuldrCore.Budget

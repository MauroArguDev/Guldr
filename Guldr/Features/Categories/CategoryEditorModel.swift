//
//  CategoryEditorModel.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation
import GuldrCore
import Observation
import SwiftData

/// The category sheet's state: a name, an SF Symbol from a curated set and a color from the 13-swatch
/// palette (ADR 008, 009), for a new category of one kind or an existing one.
///
/// Like the other editors, nothing touches the store until `save()` or `delete()`, which save the
/// context themselves, roll it back on failure and throw a typed `EditorError`. Seeded categories can be
/// renamed and archived but never deleted; custom ones can be deleted only while no transaction uses them.
@Observable
final class CategoryEditorModel {

    enum EditorError: Error, Equatable {
        /// The category to edit is no longer in the store.
        case notFound
        /// `save()` was called while the name is empty or used by another category of the kind.
        case invalidName
        /// `delete()` was called for a seeded category or one with transactions.
        case cannotDelete
        case saveFailed
    }

    let kind: TransactionKind
    let isNew: Bool
    var name: String
    var symbolName: String
    var color: CategoryColor
    /// A seeded category: it can be renamed and archived, never deleted.
    let isSystem: Bool
    /// A custom category no transaction uses. Its budgets go with it.
    let canDelete: Bool

    /// A new category of `kind`.
    init(kind: TransactionKind, context: ModelContext, notifier: DataChangeNotifier) {
        self.kind = kind
        self.context = context
        self.notifier = notifier
        isNew = true
        isSystem = false
        canDelete = false
        category = nil
        name = ""
        symbolName = CategorySymbols.all[0]
        color = .graphite
        original = ("", CategorySymbols.all[0], .graphite)
    }

    /// The category with `id`. A seeded name shows translated; it is stored only if the user changes it,
    /// so an untouched seeded category keeps following the device's language.
    init(editing id: PersistentIdentifier, context: ModelContext, notifier: DataChangeNotifier)
        throws(EditorError) {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.persistentModelID == id })
        guard let category = (try? context.fetch(descriptor))?.first else { throw .notFound }
        self.context = context
        self.notifier = notifier
        self.category = category
        kind = category.kind
        isNew = false
        isSystem = category.systemKey != nil
        canDelete = category.systemKey == nil && (category.transactions ?? []).isEmpty
        name = category.displayName
        symbolName = category.symbolName
        color = category.color
        original = (category.displayName, category.symbolName, category.color)
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasChanges: Bool {
        name != original.name || symbolName != original.symbolName || color != original.color
    }

    /// Two categories of one kind with the same name couldn't be told apart in the add sheet.
    var isNameTaken: Bool {
        let candidate = trimmedName
        guard !candidate.isEmpty else { return false }
        let kindRawValue = kind.rawValue
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.kindRawValue == kindRawValue })
        let others = ((try? context.fetch(descriptor)) ?? []).filter { $0 !== category }
        return others.contains {
            $0.displayName.compare(candidate, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    var canSave: Bool {
        hasChanges && !trimmedName.isEmpty && !isNameTaken
    }

    /// The curated symbols, with the category's own first if it isn't one of them.
    var symbols: [String] {
        CategorySymbols.all.contains(original.symbolName)
            ? CategorySymbols.all
            : [original.symbolName] + CategorySymbols.all
    }

    func save() throws(EditorError) {
        guard !trimmedName.isEmpty, !isNameTaken else { throw .invalidName }
        if let category {
            if name != original.name { category.name = trimmedName }
            category.symbolName = symbolName
            category.color = color
        } else {
            let kindRawValue = kind.rawValue
            let descriptor = FetchDescriptor<Category>(predicate: #Predicate {
                $0.kindRawValue == kindRawValue && !$0.isArchived
            })
            let last = ((try? context.fetch(descriptor)) ?? []).map(\.sortOrder).max() ?? -1
            context.insert(Category(name: trimmedName, symbolName: symbolName, color: color, kind: kind,
                                    sortOrder: last + 1))
        }
        try saveContext()
    }

    /// Deletes a custom category without transactions, and its budgets (ADR 008).
    func delete() throws(EditorError) {
        guard canDelete, let category else { throw .cannotDelete }
        context.delete(category)
        try saveContext()
        // Its budgets are gone, so budget totals may have changed.
        notifier.dataDidChange()
    }

    // MARK: - Private

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let notifier: DataChangeNotifier
    @ObservationIgnored private let category: Category?
    @ObservationIgnored private let original: (name: String, symbolName: String, color: CategoryColor)

    private func saveContext() throws(EditorError) {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw .saveFailed
        }
    }
}

/// The symbols a category can use: the defaults' and common spending and income ones, grouped loosely
/// by topic so the grid reads in order. No free symbol search: every one here works at chip size.
enum CategorySymbols {
    static let all = [
        // Food and shopping
        "fork.knife", "cup.and.saucer", "cart", "basket", "bag", "gift", "tshirt", "scissors",
        // Getting around
        "car", "bus", "tram", "airplane", "fuelpump", "bicycle",
        // Home and bills
        "house", "building.2", "bolt", "drop", "flame", "wifi", "phone", "wrench.and.screwdriver",
        // Free time
        "play", "tv", "gamecontroller", "music.note", "film", "book", "globe", "sparkles",
        // Health and family
        "heart", "cross.case", "pills", "figure.run", "pawprint", "person.2", "graduationcap", "leaf",
        // Money
        "briefcase", "laptopcomputer", "banknote", "creditcard", "building.columns",
        "chart.line.uptrend.xyaxis", "percent", "doc.text", "umbrella", "ellipsis.circle"
    ]
}

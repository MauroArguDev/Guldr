//
//  CategoriesModel.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation
import GuldrCore
import Observation
import SwiftData

/// The categories screen's state: one kind at a time, its active categories in display order and its
/// archived ones (ADR 008). Like the other screen models, the view owns the `@Query` and calls `update`;
/// changes take the view's context, save it themselves and roll back on failure.
///
/// Reordering and archiving never change a total, so they don't notify `DataChangeNotifier`.
@Observable
final class CategoriesModel {

    enum CategoriesError: Error, Equatable {
        case saveFailed
    }

    struct Row: Identifiable, Equatable {
        let id: PersistentIdentifier
        let name: String
        let symbol: String
    }

    /// The segmented control's kind (author's call, 2026-10-20).
    var kind: TransactionKind = .expense {
        didSet {
            if kind != oldValue { rebuild() }
        }
    }
    /// The kind's categories a user can pick, in the add sheet's order.
    private(set) var active: [Row] = []
    /// Hidden from pickers and budgets; restored from here.
    private(set) var archived: [Row] = []

    /// A kind keeps at least one active category, so the add sheet always has one to pick.
    var canArchive: Bool { active.count > 1 }

    /// Takes every category, archived ones included. The view calls it when its query changes.
    func update(categories: [Category]) {
        self.categories = categories
        rebuild()
    }

    /// Moves active rows as `List.onMove` reports, then numbers the kind's active categories 0, 1, 2…
    func move(fromOffsets source: IndexSet, toOffset destination: Int, in context: ModelContext)
        throws(CategoriesError) {
        // `List` reports the destination as an offset in the list before the move.
        let moving = source.map { active[$0].id }
        var ids = active.enumerated().filter { !source.contains($0.offset) }.map(\.element.id)
        ids.insert(contentsOf: moving, at: destination - source.count(in: 0..<destination))
        let byID = Dictionary(categories.map { ($0.persistentModelID, $0) }, uniquingKeysWith: { first, _ in first })
        for (index, id) in ids.enumerated() {
            byID[id]?.sortOrder = index
        }
        try save(context)
    }

    /// Archiving keeps the category's transactions and budgets; restoring puts it at the end of the list.
    /// Archiving the kind's last active category does nothing (`canArchive`).
    func setArchived(_ id: PersistentIdentifier, _ isArchived: Bool, in context: ModelContext)
        throws(CategoriesError) {
        guard let category = categories.first(where: { $0.persistentModelID == id }),
              category.isArchived != isArchived else { return }
        if isArchived {
            guard canArchive else { return }
        } else {
            category.sortOrder = (activeCategories.map(\.sortOrder).max() ?? -1) + 1
        }
        category.isArchived = isArchived
        try save(context)
    }

    // MARK: - Private

    @ObservationIgnored private var categories: [Category] = []

    /// The kind's active categories in the order `Category.pickable` uses.
    private var activeCategories: [Category] {
        categories
            .filter { $0.kind == kind && !$0.isArchived }
            .sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
    }

    private func rebuild() {
        active = activeCategories.map(row)
        archived = categories
            .filter { $0.kind == kind && $0.isArchived }
            .map(row)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func row(_ category: Category) -> Row {
        Row(id: category.persistentModelID, name: category.displayName, symbol: category.symbolName)
    }

    private func save(_ context: ModelContext) throws(CategoriesError) {
        do {
            try context.save()
            // Shown at once, before the query delivers the new order.
            rebuild()
        } catch {
            context.rollback()
            rebuild()
            throw .saveFailed
        }
    }
}

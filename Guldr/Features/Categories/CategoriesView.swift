//
//  CategoriesView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import GuldrCore
import SwiftData
import SwiftUI

/// Settings › Categories. No mockup: a native list (DESIGN.md › Principles). A segmented Expenses/Income
/// control, the kind's categories in the add sheet's order, reordered by dragging and archived with a
/// swipe, then an "Archived" section where they are restored (author's call, 2026-10-20).
struct CategoriesView: View {

    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Category.sortOrder), SortDescriptor(\Category.name)])
    private var categories: [Category]
    @State private var model = CategoriesModel()
    @State private var failedToSave = false

    var body: some View {
        List {
            Section {
                kindPicker
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section {
                ForEach(model.active) { row in
                    rowLabel(row)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if model.canArchive {
                                Button {
                                    perform { try model.setArchived(row.id, true, in: context) }
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                .tint(Color(.textSecondary))
                            }
                        }
                }
                .onMove { source, destination in
                    perform { try model.move(fromOffsets: source, toOffset: destination, in: context) }
                }
                .listRowBackground(Color(.surface))
            } footer: {
                Text("Touch and hold a category to reorder it. Swipe left to archive it.")
            }

            if !model.archived.isEmpty {
                Section {
                    ForEach(model.archived) { row in
                        rowLabel(row)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    perform { try model.setArchived(row.id, false, in: context) }
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(Color(.gold))
                            }
                    }
                    .listRowBackground(Color(.surface))
                } header: {
                    Text("Archived")
                } footer: {
                    Text("Archived categories keep their transactions but no longer appear when you add a transaction or set budgets.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.appBackground))
        .navigationTitle(Text("Categories"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: categories, initial: true) { model.update(categories: categories) }
        .alert("Couldn't save your categories", isPresented: $failedToSave) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try again in a moment.")
        }
    }

    private var kindPicker: some View {
        Picker("Kind", selection: $model.kind) {
            Text("Expenses").tag(TransactionKind.expense)
            Text("Income").tag(TransactionKind.income)
        }
        .pickerStyle(.segmented)
        .sensoryFeedback(Haptics.selection, trigger: model.kind)
    }

    private func rowLabel(_ row: CategoriesModel.Row) -> some View {
        HStack(spacing: Spacing.rowGap) {
            IconChip(symbol: row.symbol, size: .compact)
            Text(verbatim: row.name)
                .foregroundStyle(Color(.textPrimary))
        }
    }

    /// Untyped: Swift infers `any Error` for a closure's `try`, so a typed parameter would not accept it.
    /// Every change throws `CategoriesError.saveFailed`, which is all the alert needs.
    private func perform(_ change: () throws -> Void) {
        do {
            try change()
        } catch {
            failedToSave = true
        }
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    PreviewEnvironment { NavigationStack { CategoriesView() } }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewEnvironment { NavigationStack { CategoriesView() } }
        .preferredColorScheme(.dark)
}
#endif

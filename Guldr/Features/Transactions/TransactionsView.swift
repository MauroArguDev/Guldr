//
//  TransactionsView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftData
import SwiftUI

/// The Transactions tab's root. The list's model needs nothing from the environment, so the list is
/// there from the first frame: swapping a placeholder for it left the large title collapsed.
struct TransactionsView: View {

    @State private var model = TransactionsListModel()

    var body: some View {
        NavigationStack {
            TransactionsList(model: model)
                .navigationTitle(Text(AppTab.transactions.title))
        }
    }
}

/// The Transactions mockup: native search under the title, a pinned All/Income/Expenses filter, a category menu in the
/// toolbar and day sections with their net. Tapping a row edits it; swiping deletes it after a confirmation.
private struct TransactionsList: View {

    @Bindable var model: TransactionsListModel

    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    /// The filter menu's options: archived categories are left out (their transactions still show with
    /// no filter set); expenses first, then income, each in display order.
    @Query(filter: #Predicate<Category> { !$0.isArchived },
           sort: [SortDescriptor(\Category.kindRawValue), SortDescriptor(\Category.sortOrder),
                  SortDescriptor(\Category.name)])
    private var categories: [Category]
    @Environment(\.modelContext) private var context
    @Environment(\.dataChangeNotifier) private var notifier
    @Environment(Preferences.self) private var preferences
    @Environment(AppRouter.self) private var router
    @Environment(\.locale) private var locale
    @State private var pendingDelete: TransactionsListModel.Row?
    @State private var failedToDelete = false

    var body: some View {
        let sections = model.sections(from: transactions, currencyCode: currencyCode)
        // The list stays in place even when empty, with the empty state over it: the navigation bar
        // tracks its scroll view, and swapping it for another view left the large title collapsed.
        list(sections)
            .overlay {
                if let emptyState = model.emptyState(for: sections) {
                    emptyView(emptyState)
                }
            }
            .background(Color(.appBackground))
        .safeAreaBar(edge: .top) {
            // A new user has nothing to filter; the picker appears with the first transaction.
            if !transactions.isEmpty {
                kindPicker
            }
        }
        // Revealed by pulling the list down, as in Mail: always showing it left the large title collapsed
        // whenever the tab opened on iOS 27 (author's call, 2026-10-15).
        .searchable(text: $model.searchText, placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: Text("Search transactions"))
        .toolbar { categoryMenu }
        .motion(.standard, value: model.kindFilter)
        .motion(.standard, value: model.selectedCategoryIDs)
        .alert("Couldn't delete this transaction", isPresented: $failedToDelete) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("It's still saved. Try again in a moment.")
        }
    }

    /// Day totals use the active currency (ADR 005); before first launch picks one, the locale's.
    private var currencyCode: String {
        preferences.activeCurrencyCode ?? Currency.defaultCode(for: .autoupdatingCurrent)
    }

    // MARK: - List

    private func list(_ sections: [TransactionsListModel.Section]) -> some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.rows) { row in
                        rowView(row)
                    }
                } header: {
                    header(section)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }

    private func rowView(_ row: TransactionsListModel.Row) -> some View {
        Button {
            router.present(.editTransaction(row.id))
        } label: {
            TransactionRow(title: row.title, meta: row.meta, symbol: row.symbol, amount: row.amount,
                           kind: row.kind, chipSize: .compact)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Opens the transaction to edit it"))
        .listRowInsets(EdgeInsets(top: 0, leading: Spacing.screenHorizontal,
                                  bottom: 0, trailing: Spacing.screenHorizontal))
        .listRowSeparator(.hidden)
        .listRowBackground(Color(.appBackground))
        // No destructive role: that role animates the row away before the user confirms.
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                pendingDelete = row
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(Color(.negative))
        }
        // On the row, so the confirmation points at the transaction it deletes.
        .confirmationDialog("Delete this transaction?", isPresented: isConfirmingDelete(row),
                            titleVisibility: .visible) {
            Button("Delete transaction", role: .destructive) { delete(row) }
        } message: {
            Text("This can't be undone.")
        }
    }

    /// "Today" on the left, the day's net on the right ("+" when positive, as in the mockup).
    private func header(_ section: TransactionsListModel.Section) -> some View {
        HStack {
            Text(verbatim: section.title)
                .fontWeight(.semibold)
            Spacer(minLength: 8)
            if let net = section.net {
                Text(verbatim: MoneyFormatter(locale: locale).string(from: net,
                                                                     sign: net.isNegative ? .automatic : .plus))
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
        }
        .font(.footnote)
        .foregroundStyle(Color(.textSecondary))
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Filters

    private var kindPicker: some View {
        Picker("Filter", selection: $model.kindFilter) {
            Text("All").tag(TransactionsListModel.KindFilter.all)
            Text("Income").tag(TransactionsListModel.KindFilter.income)
            Text("Expenses").tag(TransactionsListModel.KindFilter.expenses)
        }
        .pickerStyle(.segmented)
        .sensoryFeedback(Haptics.selection, trigger: model.kindFilter)
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.vertical, Spacing.rowVertical)
    }

    @ToolbarContentBuilder
    private var categoryMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                ForEach(model.categoryOptions(from: categories)) { category in
                    Toggle(isOn: Binding(get: { model.selectedCategoryIDs.contains(category.id) },
                                         set: { _ in model.toggleCategory(category) })) {
                        Label(category.displayName, systemImage: category.symbolName)
                    }
                }
                if model.isFilteringByCategory {
                    Section {
                        Button("Clear filter", systemImage: "xmark", action: model.clearCategories)
                    }
                }
            } label: {
                Label("Filter by category", systemImage: model.isFilteringByCategory
                      ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
            // Several categories can be picked without reopening the menu.
            .menuActionDismissBehavior(.disabled)
            .tint(model.isFilteringByCategory ? Color(.gold) : Color(.textPrimary))
            .disabled(transactions.isEmpty)
        }
    }

    // MARK: - Empty states

    @ViewBuilder
    private func emptyView(_ state: TransactionsListModel.EmptyState) -> some View {
        switch state {
        case .noTransactions:
            EmptyStateView(title: "No transactions yet", symbol: "list.bullet",
                           message: "Add your first expense or income to see it here.",
                           actionTitle: "Add transaction") {
                router.present(.addTransaction)
            }
        case .noResults:
            if model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptyStateView(title: "No matching transactions", symbol: "line.3.horizontal.decrease.circle",
                               message: "Try another filter.")
            } else {
                ContentUnavailableView.search(text: model.searchText)
            }
        }
    }

    // MARK: - Delete

    private func isConfirmingDelete(_ row: TransactionsListModel.Row) -> Binding<Bool> {
        Binding(get: { pendingDelete?.id == row.id }, set: { if !$0 { pendingDelete = nil } })
    }

    private func delete(_ row: TransactionsListModel.Row) {
        do {
            try withMotion(.standard) { try model.delete(row.id, in: context, notifier: notifier) }
        } catch {
            failedToDelete = true
        }
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
// MARK: - Previews

#Preview("Light") {
    PreviewEnvironment { TransactionsView() }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewEnvironment { TransactionsView() }
        .preferredColorScheme(.dark)
}

#Preview("Empty, dark") {
    PreviewEnvironment(seeded: false) { TransactionsView() }
        .preferredColorScheme(.dark)
}
#endif

//
//  EditBudgetView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 20/10/26.
//

import GuldrCore
import SwiftData
import SwiftUI

/// Opens the edit budgets model for a month from the environment, in the active currency. Shows an error
/// screen if it can't be opened.
struct EditBudgetSheet: View {

    let month: YearMonth

    @Environment(\.modelContext) private var context
    @Environment(\.dataChangeNotifier) private var notifier
    @Environment(Preferences.self) private var preferences
    @Environment(AppRouter.self) private var router
    @State private var model: EditBudgetModel?
    @State private var failedToOpen = false

    var body: some View {
        Group {
            if let model {
                EditBudgetView(model: model, onCancel: router.dismissSheet) {
                    router.finishSave(.saved)
                }
            } else if failedToOpen {
                NavigationStack {
                    ContentUnavailableView("Couldn't open your budgets", systemImage: "exclamationmark.triangle",
                                           description: Text("Try again in a moment."))
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close", action: router.dismissSheet)
                            }
                        }
                }
            } else {
                // A real view, so `onAppear` fires: an empty `Group` never appears.
                Color(.appBackground)
            }
        }
        .onAppear(perform: open)
    }

    private func open() {
        guard model == nil, !failedToOpen else { return }
        let currencyCode = preferences.activeCurrencyCode ?? Currency.defaultCode(for: .autoupdatingCurrent)
        do {
            model = try EditBudgetModel(month: month, context: context, currencyCode: currencyCode, notifier: notifier)
        } catch {
            failedToOpen = true
        }
    }
}

/// A native `Form` with one limit per expense category for the month (author's call, 2026-10-20): the
/// system decimal keyboard, an empty field for no budget, a swipe to remove one, and copying last
/// month's limits when there are any. Nothing is saved until Save.
struct EditBudgetView: View {

    @Bindable var model: EditBudgetModel
    let onCancel: () -> Void
    let onSaved: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    @FocusState private var focusedField: UUID?
    @State private var failedToSave = false

    var body: some View {
        NavigationStack {
            Form {
                if model.canCopyLastMonth {
                    Section {
                        Button("Copy last month's budgets", systemImage: "doc.on.doc") {
                            focusedField = nil
                            model.copyLastMonth()
                        }
                        .tint(Color(.gold))
                    }
                }
                Section {
                    ForEach($model.fields) { $field in
                        limitRow($field)
                    }
                } footer: {
                    Text("Leave a category empty to have no budget for it.")
                }
                if let total = model.total {
                    Section {
                        LabeledContent("Total") {
                            AmountText(total, sign: .never)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text("Budgets"))
            .navigationSubtitle(Text(verbatim: model.month.title(locale: locale, timeZone: timeZone)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .interactiveDismissDisabled(model.hasChanges)
        .alert("Couldn't save your budgets", isPresented: $failedToSave) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your changes are still here. Try again in a moment.")
        }
    }

    private func limitRow(_ field: Binding<EditBudgetModel.Field>) -> some View {
        let isInvalid = model.invalidFieldIDs.contains(field.wrappedValue.id)
        return LabeledContent {
            TextField("No limit", text: field.text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .foregroundStyle(isInvalid ? Color(.negative) : Color(.textPrimary))
                .focused($focusedField, equals: field.wrappedValue.id)
                .accessibilityLabel(Text(field.wrappedValue.name))
                .accessibilityHint(isInvalid ? Text("Enter an amount above zero, or leave it empty.") : Text(verbatim: ""))
        } label: {
            Label {
                Text(field.wrappedValue.name)
            } icon: {
                Image(systemName: field.wrappedValue.symbol)
                    .foregroundStyle(Color(.textSecondary))
            }
        }
        .swipeActions {
            if !field.wrappedValue.text.isEmpty {
                Button("Remove", role: .destructive) {
                    field.wrappedValue.text = ""
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: onCancel)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save", action: save)
                .tint(Color(.gold))
                .disabled(!model.canSave)
        }
        // The decimal keyboard has no return key.
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") { focusedField = nil }
        }
    }

    private func save() {
        do {
            try model.save()
            onSaved()
        } catch {
            failedToSave = true
        }
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    PreviewEnvironment { EditBudgetSheet(month: YearMonth(containing: .now)) }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewEnvironment { EditBudgetSheet(month: YearMonth(containing: .now)) }
        .preferredColorScheme(.dark)
}
#endif

//
//  AddTransactionView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 15/10/26.
//

import GuldrCore
import SwiftData
import SwiftUI

/// Opens the add sheet's model from the environment: a new transaction in the active currency, or an
/// existing one by identifier. Shows an error screen if the transaction can't be opened.
struct AddTransactionSheet: View {

    var transactionID: PersistentIdentifier?

    @Environment(\.modelContext) private var context
    @Environment(\.dataChangeNotifier) private var notifier
    @Environment(Preferences.self) private var preferences
    @Environment(AppRouter.self) private var router
    @State private var model: AddTransactionViewModel?
    @State private var failedToOpen = false

    var body: some View {
        Group {
            if let model {
                AddTransactionView(model: model, onCancel: router.dismissSheet, onSaved: router.finishSave)
            } else if failedToOpen {
                NavigationStack {
                    ContentUnavailableView("Couldn't open this transaction", systemImage: "exclamationmark.triangle",
                                           description: Text("It may have been deleted."))
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close", action: router.dismissSheet)
                            }
                        }
                }
            } else {
                // A real view, so `onAppear` fires: an empty `Group` never appears.
                Color(.sheetBackground)
            }
        }
        .onAppear(perform: open)
    }

    private func open() {
        guard model == nil, !failedToOpen else { return }
        do {
            if let transactionID {
                model = try AddTransactionViewModel(editing: transactionID, context: context, notifier: notifier)
            } else {
                let currencyCode = preferences.activeCurrencyCode ?? Currency.defaultCode(for: .autoupdatingCurrent)
                model = try AddTransactionViewModel(context: context, currencyCode: currencyCode, notifier: notifier)
            }
        } catch {
            failedToOpen = true
        }
    }
}

/// The add sheet from the AddTransaction mockup (DESIGN.md › Add sheet). The form scrolls and the keypad
/// stays pinned to the bottom, so the iPhone SE and the largest text sizes still fit.
struct AddTransactionView: View {

    @Bindable var model: AddTransactionViewModel
    let onCancel: () -> Void
    let onSaved: (AddTransactionViewModel.SaveOutcome) -> Void

    @Environment(\.locale) private var locale
    @FocusState private var isDescriptionFocused: Bool
    @State private var showsDatePicker = false
    @State private var failedToSave = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.sheetStack) {
                    kindPicker
                    amountLine
                    fieldGroup
                    categorySection
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.sheetStack)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                // The system keyboard replaces the keypad while the description is being typed.
                if !isDescriptionFocused {
                    keypad
                }
            }
            .background(Color(.sheetBackground))
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .presentationBackground(Color(.sheetBackground))
        .interactiveDismissDisabled(model.hasChanges)
        .alert("Couldn't save this transaction", isPresented: $failedToSave) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your changes are still here. Try again in a moment.")
        }
    }

    private var title: LocalizedStringResource {
        model.kind == .expense ? "New expense" : "New income"
    }

    // MARK: - Sections

    private var kindPicker: some View {
        Picker("Type", selection: Binding(get: { model.kind }, set: { model.setKind($0) })) {
            Text("Expense").tag(TransactionKind.expense)
            Text("Income").tag(TransactionKind.income)
        }
        .pickerStyle(.segmented)
        .sensoryFeedback(Haptics.selection, trigger: model.kind)
    }

    private var amountLine: some View {
        HStack(spacing: 4) {
            Text(verbatim: model.amount.formattedText(locale: locale))
                .displayFont(.addAmount)
                .foregroundStyle(model.amount.isEmpty ? Color(.textSecondary) : Color(.textPrimary))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText())
                .motion(.snappy, value: model.amount)
            RoundedRectangle(cornerRadius: Size.amountCaret.width / 2)
                .fill(Color(.goldFill))
                .frame(width: Size.amountCaret.width, height: Size.amountCaret.height)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: Size.amountRow)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Amount"))
        .accessibilityValue(Text(verbatim: model.amount.formattedText(locale: locale)))
    }

    private var fieldGroup: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.rowGap) {
                Text("Description")
                    .foregroundStyle(Color(.textSecondary))
                // The prompt is what an empty description shows as: the category's name, or nothing yet.
                TextField("Description", text: $model.title, prompt: Text(verbatim: model.titlePrompt ?? ""))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Color(.textPrimary))
                    .focused($isDescriptionFocused)
                    .submitLabel(.done)
            }
            .fieldRow()
            Rectangle()
                .fill(Color(.fieldAccent))
                .frame(height: 1)
            HStack(spacing: Spacing.rowGap) {
                Text("Date")
                    .foregroundStyle(Color(.textSecondary))
                Spacer(minLength: 0)
                dateChip
            }
            .fieldRow()
        }
        .font(.callout)
        .background(Color(.field), in: .rect(cornerRadius: Radius.field, style: .continuous))
    }

    private var dateChip: some View {
        Button {
            showsDatePicker = true
        } label: {
            Text(verbatim: DayLabelFormatter(locale: locale).chipLabel(for: model.date))
                .font(.subheadline)
                .foregroundStyle(Color(.textPrimary))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(.fieldAccent), in: .rect(cornerRadius: Radius.dateChip, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Date"))
        .accessibilityValue(Text(verbatim: DayLabelFormatter(locale: locale).chipLabel(for: model.date)))
        .popover(isPresented: $showsDatePicker) {
            DatePicker("Date", selection: $model.date, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Color(.gold))
                // A graphical picker has no width of its own in a popover; 320 pt is the system calendar's.
                .frame(width: 320)
                .padding()
                .presentationCompactAdaptation(.popover)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: Spacing.gridGap) {
            Text("Category")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.textSecondary))
                .padding(.horizontal, 2)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.gridGap), count: 4),
                      spacing: Spacing.gridGap) {
                ForEach(model.categories) { category in
                    CategoryChip(name: category.displayName, symbol: category.symbolName,
                                 isSelected: model.category == category) {
                        model.select(category)
                    }
                }
            }
        }
    }

    private var keypad: some View {
        AmountKeypad(acceptsDecimals: model.acceptsDecimals,
                     onDigit: { model.pressDigit($0) },
                     onDecimalSeparator: { model.pressDecimalSeparator() },
                     onDelete: { model.pressDelete() })
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.gridGap)
            .background(Color(.sheetBackground))
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
    }

    private func save() {
        do {
            onSaved(try model.save())
        } catch {
            failedToSave = true
        }
    }
}

private extension View {
    /// A 46 pt row inside the add sheet's field group.
    func fieldRow() -> some View {
        frame(minHeight: Size.fieldRow)
            .padding(.horizontal, Spacing.fieldRowHorizontal)
    }
}

// MARK: - Previews

#Preview("Light") {
    PreviewEnvironment { AddTransactionSheet() }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewEnvironment { AddTransactionSheet() }
        .preferredColorScheme(.dark)
}

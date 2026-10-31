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
                AddTransactionView(model: model, onCancel: router.dismissSheet, onSaved: router.finishSave,
                                   onDeleted: router.dismissSheet)
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
    var onDeleted: () -> Void = {}

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var isDescriptionFocused: Bool
    @State private var showsDatePicker = false
    @State private var failedToSave = false
    @State private var confirmsDelete = false
    @State private var failedToDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.sheetStack) {
                    kindPicker
                    amountLine
                    fieldGroup
                    categorySection
                    if model.isEditing {
                        deleteButton
                    }
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
        .alert("Couldn't delete this transaction", isPresented: $failedToDelete) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("It's still saved. Try again in a moment.")
        }
    }

    private var title: LocalizedStringResource {
        switch (model.isEditing, model.kind) {
        case (false, .expense): "New expense"
        case (false, .income): "New income"
        case (true, .expense): "Edit expense"
        case (true, .income): "Edit income"
        }
    }

    // MARK: - Sections

    private var kindPicker: some View {
        Picker("Type", selection: Binding(get: { model.kind }, set: { model.setKind($0) })) {
            Text("Expense").tag(TransactionKind.expense)
            // Its own key: "Income" elsewhere is a total or a filter, which Spanish says in the plural.
            Text(String(localized: "transaction.kind.income", defaultValue: "Income",
                        comment: "The add sheet's type picker: the transaction is an income."))
                .tag(TransactionKind.income)
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
                // The keypad types into the amount, so the caret blinks there, except while the system
                // keyboard is typing the description.
                .caretBlink(isActive: !isDescriptionFocused, restart: model.amount)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: Size.amountRow)
        // While the system keyboard types the description, tapping the amount brings the keypad back;
        // otherwise only the keyboard's Done key would.
        .contentShape(.rect)
        .onTapGesture { isDescriptionFocused = false }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Amount"))
        .accessibilityValue(Text(verbatim: model.amount.formattedText(locale: locale)))
        .accessibilityAddTraits(isDescriptionFocused ? .isButton : [])
    }

    private var fieldGroup: some View {
        VStack(spacing: 0) {
            fieldRowLayout {
                Text("Description")
                    .foregroundStyle(Color(.textSecondary))
                // The prompt is what an empty description shows as: the category's name, or nothing yet.
                TextField("Description", text: $model.title, prompt: Text(verbatim: model.titlePrompt ?? ""))
                    .multilineTextAlignment(stacksFieldRows ? .leading : .trailing)
                    .foregroundStyle(Color(.textPrimary))
                    .focused($isDescriptionFocused)
                    .submitLabel(.done)
            }
            .fieldRow(stacked: stacksFieldRows)
            Rectangle()
                .fill(Color(.fieldAccent))
                .frame(height: 1)
            fieldRowLayout {
                Text("Date")
                    .foregroundStyle(Color(.textSecondary))
                if !stacksFieldRows { Spacer(minLength: 0) }
                dateChip
            }
            .fieldRow(stacked: stacksFieldRows)
        }
        .font(.callout)
        .background(Color(.field), in: .rect(cornerRadius: Radius.field, style: .continuous))
    }

    /// At accessibility text sizes a label and its value no longer fit side by side, so each row stacks
    /// them, as Settings does.
    private var stacksFieldRows: Bool { dynamicTypeSize.isAccessibilitySize }

    private var fieldRowLayout: AnyLayout {
        stacksFieldRows
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.rowVertical))
            : AnyLayout(HStackLayout(spacing: Spacing.rowGap))
    }

    private var dateChip: some View {
        Button {
            // The popover only gets the space above the keyboard, which squeezes the calendar.
            isDescriptionFocused = false
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
            // Four columns as in the mockup; two at accessibility sizes, where names no longer fit.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.gridGap),
                                     count: dynamicTypeSize.isAccessibilitySize ? 2 : 4),
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

    /// Not in the mockup, which only shows adding: a plain destructive button after the categories,
    /// behind a confirmation, so it is never next to the keys.
    private var deleteButton: some View {
        Button("Delete transaction", role: .destructive) {
            confirmsDelete = true
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(Color(.negative))
        .frame(maxWidth: .infinity, minHeight: Size.touchTargetMin)
        .padding(.top, Spacing.sheetStack)
        .confirmationDialog("Delete this transaction?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete transaction", role: .destructive, action: delete)
        } message: {
            Text("This can't be undone.")
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

    private func delete() {
        do {
            try model.delete()
            onDeleted()
        } catch {
            failedToDelete = true
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
    /// A row of at least 46 pt inside the add sheet's field group; taller when the text is.
    /// `stacked` rows (accessibility text sizes) get vertical padding, since their height comes from the text.
    func fieldRow(stacked: Bool) -> some View {
        frame(maxWidth: .infinity, minHeight: Size.fieldRow, alignment: .leading)
            .padding(.horizontal, Spacing.fieldRowHorizontal)
            .padding(.vertical, stacked ? Spacing.rowVertical : 0)
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
// MARK: - Previews

#Preview("Light") {
    PreviewEnvironment { AddTransactionSheet() }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewEnvironment { AddTransactionSheet() }
        .preferredColorScheme(.dark)
}

#Preview("Edit, dark") {
    PreviewEnvironment { EditPreview() }
        .preferredColorScheme(.dark)
}

/// Opens the sheet on the newest transaction in the preview data.
private struct EditPreview: View {

    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    var body: some View {
        if let first = transactions.first {
            AddTransactionSheet(transactionID: first.persistentModelID)
        }
    }
}
#endif

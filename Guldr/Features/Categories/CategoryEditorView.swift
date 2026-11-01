//
//  CategoryEditorView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import GuldrCore
import SwiftData
import SwiftUI

/// Opens the category editor for a new category or an existing one. Shows an error screen if the
/// category is gone.
struct CategoryEditorSheet: View {

    enum Target: Identifiable, Hashable {
        case new(TransactionKind)
        case edit(PersistentIdentifier)

        var id: Self { self }
    }

    let target: Target
    let onCancel: () -> Void
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dataChangeNotifier) private var notifier
    @State private var model: CategoryEditorModel?
    @State private var failedToOpen = false

    var body: some View {
        Group {
            if let model {
                CategoryEditorView(model: model, onCancel: onCancel, onSaved: onSaved)
            } else if failedToOpen {
                NavigationStack {
                    ContentUnavailableView("Couldn't open this category", systemImage: "exclamationmark.triangle",
                                           description: Text("Try again in a moment."))
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close", action: onCancel)
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
        switch target {
        case .new(let kind):
            model = CategoryEditorModel(kind: kind, context: context, notifier: notifier)
        case .edit(let id):
            do {
                model = try CategoryEditorModel(editing: id, context: context, notifier: notifier)
            } catch {
                failedToOpen = true
            }
        }
    }
}

/// A native `Form`: the name, a grid of curated SF Symbols and the 13 palette swatches (DESIGN.md ›
/// Category palette), then Delete for a custom category no transaction uses. Nothing is saved until Save.
struct CategoryEditorView: View {

    @Bindable var model: CategoryEditorModel
    let onCancel: () -> Void
    let onSaved: () -> Void

    @State private var confirmingDelete = false
    @State private var failedToSave = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $model.name)
                        .submitLabel(.done)
                } footer: {
                    nameFooter
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                        ForEach(model.symbols, id: \.self, content: symbolCell)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Symbol")
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 6)], spacing: 6) {
                        ForEach(CategoryColor.allCases, id: \.self, content: colorCell)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Color")
                } footer: {
                    Text("The category's color in the analytics charts.")
                }

                if model.canDelete {
                    Section {
                        Button("Delete category", role: .destructive) {
                            confirmingDelete = true
                        }
                        // On the button, so iOS points the confirmation there instead of at the whole form.
                        .confirmationDialog("Delete this category?", isPresented: $confirmingDelete,
                                            titleVisibility: .visible) {
                            Button("Delete category", role: .destructive, action: delete)
                        } message: {
                            Text("Its budgets are deleted too. This can't be undone.")
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(model.isNew ? Text("New category") : Text("Edit category"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .tint(Color(.gold))
                        .disabled(!model.canSave)
                }
            }
        }
        .interactiveDismissDisabled(model.hasChanges)
        .alert("Couldn't save this category", isPresented: $failedToSave) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your changes are still here. Try again in a moment.")
        }
    }

    /// Why the name can't be saved, or why a category can't be deleted.
    @ViewBuilder
    private var nameFooter: some View {
        if model.isNameTaken {
            Text("Another category is already called this.")
                .foregroundStyle(Color(.negative))
        } else if model.isSystem {
            Text("Default categories can be renamed and archived, but not deleted.")
        } else if !model.isNew && !model.canDelete {
            Text("Categories with transactions can be archived, but not deleted.")
        }
    }

    /// The add sheet's chip selection style: `GoldSoft` fill, `GoldFill` border, `Gold` glyph.
    private func symbolCell(_ symbol: String) -> some View {
        let isSelected = model.symbolName == symbol
        let shape = RoundedRectangle(cornerRadius: Radius.categoryChip, style: .continuous)
        return Button {
            withMotion(.snappy) { model.symbolName = symbol }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: Size.iconGlyphCompact))
                .foregroundStyle(isSelected ? Color(.gold) : Color(.textPrimary))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSelected ? Color(.goldSoft) : Color(.field), in: shape)
                .overlay { shape.strokeBorder(isSelected ? Color(.goldFill) : .clear, lineWidth: 1.5) }
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(Haptics.selection, trigger: isSelected) { _, selected in selected }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// A 30 pt swatch in a 44 pt target; the selected one gets a ring in its own color.
    private func colorCell(_ color: CategoryColor) -> some View {
        let isSelected = model.color == color
        return Button {
            withMotion(.snappy) { model.color = color }
        } label: {
            ZStack {
                Circle()
                    .fill(color.color)
                    .frame(width: 30, height: 30)
                Circle()
                    .strokeBorder(color.color, lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .opacity(isSelected ? 1 : 0)
            }
            .frame(width: 44, height: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(Haptics.selection, trigger: isSelected) { _, selected in selected }
        .accessibilityLabel(Text(color.accessibilityName))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func save() {
        do {
            try model.save()
            onSaved()
        } catch {
            failedToSave = true
        }
    }

    private func delete() {
        do {
            try model.delete()
            onSaved()
        } catch {
            failedToSave = true
        }
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    PreviewEnvironment { CategoryEditorSheet(target: .new(.expense), onCancel: {}, onSaved: {}) }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewEnvironment { CategoryEditorSheet(target: .new(.expense), onCancel: {}, onSaved: {}) }
        .preferredColorScheme(.dark)
}
#endif

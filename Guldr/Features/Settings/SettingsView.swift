//
//  SettingsView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 16/10/26.
//

import GuldrCore
import SwiftData
import SwiftUI

/// Settings, pushed from the Dashboard's toolbar: a native `Form` with the active currency, which can be
/// changed, the categories, About and "Delete all data". Face ID, notifications, widget privacy and export join it in the phases that
/// build them, so it never shows a control that does nothing (author's call, 2026-10-20). Debug builds
/// also link to the design system gallery from here.
struct SettingsView: View {

    @Environment(Preferences.self) private var preferences
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Environment(\.dataChangeNotifier) private var notifier
    @State private var failedToSave = false
    @State private var confirmingDelete = false
    @State private var confirmingDeleteAgain = false
    @State private var failedToDelete = false

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    CurrencyPickerView(selection: currencySelection)
                } label: {
                    LabeledContent("Currency") {
                        Text(verbatim: currencyText)
                    }
                }
            } footer: {
                Text("Totals, budgets and charts use this currency. Transactions keep the currency they were saved in.")
            }

            Section {
                NavigationLink {
                    CategoriesView()
                } label: {
                    Text("Categories")
                }
            }

            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    Text("About")
                }
            }

            Section {
                Button("Delete all data", role: .destructive) {
                    confirmingDelete = true
                }
            } footer: {
                Text("Deletes your transactions, budgets and custom categories, and starts Guldr over.")
            }

            #if DEBUG
            Section {
                NavigationLink {
                    DesignSystemGallery()
                } label: {
                    Label {
                        Text(verbatim: "Design system gallery")
                    } icon: {
                        Image(systemName: "swatchpalette")
                    }
                }
            } header: {
                Text(verbatim: "Debug")
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(Color(.appBackground))
        .navigationTitle(Text("Settings"))
        .navigationBarTitleDisplayMode(.inline)
        // Two confirmations, as the plan asks for: the dialog says what goes, the alert that it's final.
        .confirmationDialog("Delete all data?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete all data", role: .destructive) {
                confirmingDeleteAgain = true
            }
        } message: {
            Text("Every transaction, budget and custom category on this iPhone is deleted, and Guldr returns to the welcome screen.")
        }
        .alert("Are you sure?", isPresented: $confirmingDeleteAgain) {
            Button("Delete everything", role: .destructive, action: deleteAllData)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your data can't be recovered.")
        }
        .alert("Couldn't delete your data", isPresented: $failedToDelete) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Nothing was deleted. Try again in a moment.")
        }
        .alert("Couldn't save your currency", isPresented: $failedToSave) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Choose another currency and try again.")
        }
    }

    /// The data goes first: if it fails, the currency and first launch stay as they were.
    private func deleteAllData() {
        do {
            try DataReset.eraseAll(in: context)
        } catch {
            failedToDelete = true
            return
        }
        notifier.dataDidChange()
        preferences.reset()
    }

    private var activeCurrencyCode: String {
        preferences.activeCurrencyCode ?? Currency.defaultCode(for: locale)
    }

    /// The picker writes straight through `Preferences`, so every screen and the widget see the change.
    private var currencySelection: Binding<String> {
        Binding {
            activeCurrencyCode
        } set: { code in
            do {
                try preferences.setActiveCurrency(code)
            } catch {
                failedToSave = true
            }
        }
    }

    /// "US Dollar (USD)", as on the welcome screen.
    private var currencyText: String {
        let option = CurrencyOption.option(for: activeCurrencyCode, locale: locale)
        return "\(option.name) (\(option.code))"
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    PreviewEnvironment { NavigationStack { SettingsView() } }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewEnvironment { NavigationStack { SettingsView() } }
        .preferredColorScheme(.dark)
}
#endif

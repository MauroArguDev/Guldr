//
//  SettingsView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 16/10/26.
//

import GuldrCore
import SwiftUI

/// Settings, pushed from the Dashboard's toolbar: a native `Form` with the active currency, which can be
/// changed, the categories and the version. Face ID, notifications, widget privacy and export join it in the phases that
/// build them, so it never shows a control that does nothing (author's call, 2026-10-20). Debug builds
/// also link to the design system gallery from here.
struct SettingsView: View {

    @Environment(Preferences.self) private var preferences
    @Environment(\.locale) private var locale
    @State private var failedToSave = false

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
                LabeledContent("Version") {
                    Text(verbatim: Self.versionText())
                }
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
        .alert("Couldn't save your currency", isPresented: $failedToSave) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Choose another currency and try again.")
        }
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

    /// "1.0 (1)" from the bundle's version and build number.
    static func versionText(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) -> String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        guard let build = infoDictionary?["CFBundleVersion"] as? String else { return version }
        return "\(version) (\(build))"
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

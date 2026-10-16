//
//  SettingsView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 16/10/26.
//

import GuldrCore
import SwiftUI

/// Settings, pushed from the Dashboard's toolbar. For now it only shows the active currency and the
/// version; the v1 plan's Phase 22 builds the full screen (currency, Face ID, notifications, export,
/// categories, about). Debug builds also link to the design system gallery from here.
struct SettingsView: View {

    @Environment(Preferences.self) private var preferences
    @Environment(\.locale) private var locale

    var body: some View {
        Form {
            Section {
                LabeledContent("Currency") {
                    Text(verbatim: currencyText)
                }
            } footer: {
                Text("Totals, budgets and charts use this currency.")
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
    }

    /// "US Dollar (USD)", as on the welcome screen.
    private var currencyText: String {
        let code = preferences.activeCurrencyCode ?? Currency.defaultCode(for: locale)
        let option = CurrencyOption.option(for: code, locale: locale)
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

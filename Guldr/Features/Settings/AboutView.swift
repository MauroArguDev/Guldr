//
//  AboutView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import SwiftUI

/// Settings › About: the version, the privacy policy, support by email and the licenses of what ships in
/// the app. The privacy policy row joined once the page was published (v1 plan, step 33.7), so it never
/// linked to a missing page (author's call, 2026-10-21). SwiftLint is not listed: it runs at build time
/// and doesn't ship.
struct AboutView: View {

    var body: some View {
        Form {
            Section {
                VStack(spacing: 6) {
                    Wordmark()
                    Text(verbatim: Self.versionText())
                        .textRole(.meta)
                        .foregroundStyle(Color(.textSecondary))
                        .accessibilityLabel(Text("Version \(Self.versionText())"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)

            Section {
                if let url = SupportContact.privacyPolicyURL {
                    Link(destination: url) {
                        Label("Privacy policy", systemImage: "hand.raised")
                    }
                    .tint(Color(.gold))
                }
                if let url = SupportContact.mailURL(subject: "Guldr support", problem: "") {
                    Link(destination: url) {
                        Label("Contact support", systemImage: "envelope")
                    }
                    .tint(Color(.gold))
                }
            } footer: {
                Text("Write to \(SupportContact.email). Your message includes the app and iOS versions.")
            }

            Section {
                NavigationLink {
                    LicenseView(title: "Manrope", resource: "Manrope-OFL")
                } label: {
                    LabeledContent {
                        Text("SIL Open Font License 1.1")
                    } label: {
                        Text(verbatim: "Manrope")
                    }
                }
            } header: {
                Text("Acknowledgements")
            } footer: {
                Text("The Guldr wordmark is drawn from the Manrope typeface.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.appBackground))
        .navigationTitle(Text("About"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// "1.0 (1)" from the bundle's version and build number.
    static func versionText(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) -> String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        guard let build = infoDictionary?["CFBundleVersion"] as? String else { return version }
        return "\(version) (\(build))"
    }
}

/// A license's full text, bundled as a plain text file under `Resources/Licenses`.
private struct LicenseView: View {

    let title: String
    let resource: String

    var body: some View {
        ScrollView {
            Text(verbatim: text)
                .font(.footnote)
                .foregroundStyle(Color(.textPrimary))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.screenHorizontal)
        }
        .background(Color(.appBackground))
        .navigationTitle(Text(verbatim: title))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The file is part of the app; if it were missing, the license's public page says the same.
    private var text: String {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "https://openfontlicense.org"
        }
        return text
    }
}

#Preview("Light") {
    NavigationStack { AboutView() }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    NavigationStack { AboutView() }
        .preferredColorScheme(.dark)
}

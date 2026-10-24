//
//  SupportContact.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation

/// Where users reach the developer, and the public pages about the app. The same address and URLs go in
/// App Store Connect.
enum SupportContact {

    static let email = "argudev@icloud.com"

    /// The public privacy policy, published from `docs/PRIVACY.md` (v1 plan, 33.7). The same URL goes in
    /// App Store Connect.
    static let privacyPolicyURL = URL(string: "https://mauroargudev.github.io/Guldr/privacy/")

    /// Guldr's App Store page, from the app record's Apple ID (v1 plan, 34.1). The short `/app/id…` form
    /// works in every storefront and opens in the App Store app.
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6826453592")

    /// A `mailto:` link prefilled with the app version, the iOS version and what went wrong, so a
    /// report is useful without asking the user for details.
    static func mailURL(subject: String, problem: String, bundle: Bundle = .main,
                        systemVersion: String = ProcessInfo.processInfo.operatingSystemVersionString) -> URL? {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: "\n\n---\nGuldr \(version) (\(build)) · iOS \(systemVersion)\n\(problem)")
        ]
        return components.url
    }
}

//
//  SupportContact.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation

/// Where users reach the developer. The same address goes in App Store Connect.
enum SupportContact {

    static let email = "argudev@icloud.com"

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

//
//  DeepLink.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation

/// The app's `guldr://` URLs. The widget builds them and the app parses them, so both sides share this
/// one definition.
public enum DeepLink: String, CaseIterable, Sendable {
    /// `guldr://add`: open the add transaction sheet.
    case add
    /// `guldr://budget`: show the Budget tab.
    case budget

    /// The URL scheme registered in the app's Info.plist (`CFBundleURLTypes`).
    public static let scheme = "guldr"

    /// `nil` for another scheme, an unknown host, or anything after the host (path, query, fragment),
    /// so a malformed link is ignored instead of guessed. Scheme and host are matched case-insensitively.
    public init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == Self.scheme,
              let host = components.host?.lowercased(),
              components.path.isEmpty || components.path == "/",
              components.query == nil,
              components.fragment == nil else { return nil }
        self.init(rawValue: host)
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = rawValue
        // A valid scheme plus a plain lowercase host always forms a URL (covered by DeepLinkTests); the
        // fallback only satisfies the type system without a force unwrap.
        return components.url ?? URL(filePath: "/")
    }
}

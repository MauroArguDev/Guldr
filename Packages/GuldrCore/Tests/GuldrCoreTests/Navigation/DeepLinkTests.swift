//
//  DeepLinkTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import Testing
@testable import GuldrCore

struct DeepLinkTests {

    @Test(arguments: DeepLink.allCases)
    func urlRoundTrips(link: DeepLink) {
        #expect(link.url.absoluteString == "guldr://\(link.rawValue)")
        #expect(DeepLink(url: link.url) == link)
    }

    @Test(arguments: ["GULDR://ADD", "guldr://Add", "guldr://add/"])
    func schemeAndHostIgnoreCase(string: String) throws {
        #expect(DeepLink(url: try #require(URL(string: string))) == .add)
    }

    @Test(arguments: [
        "https://add",              // another scheme
        "guldr://settings",         // unknown host
        "guldr://",                 // no host
        "guldr://add/extra",        // path after the host
        "guldr://add?amount=10",    // query
        "guldr://budget#top"        // fragment
    ])
    func malformedLinksAreIgnored(string: String) throws {
        #expect(DeepLink(url: try #require(URL(string: string))) == nil)
    }
}

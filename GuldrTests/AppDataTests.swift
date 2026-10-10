//
//  AppDataTests.swift
//  GuldrTests
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import GuldrCore
import Testing
@testable import Guldr

/// App-side persistence glue. The store itself is tested in GuldrCore; these only need the app.
struct AppDataTests {

    @Test func loaderShowsTheErrorScreenWithoutAnAppGroup() {
        // An empty Info.plist fails before touching the disk, so the real store is never opened here.
        let loader = AppDataLoader(infoDictionary: [:])
        guard case .failed(.appGroupUnavailable) = loader.state else {
            Issue.record("Expected failed(appGroupUnavailable), got \(loader.state)")
            return
        }
        loader.retry()
        guard case .failed = loader.state else {
            Issue.record("Retry with the same Info.plist must fail again")
            return
        }
    }

    @Test func supportMailIsPrefilled() throws {
        let url = try #require(SupportContact.mailURL(subject: "Guldr couldn't open my data",
                                                      problem: "appGroupUnavailable", systemVersion: "26.0"))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "mailto")
        #expect(components.path == "argudev@icloud.com")
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(items["subject"] == "Guldr couldn't open my data")
        let body = try #require(items["body"])
        #expect(body.contains("iOS 26.0"))
        #expect(body.contains("appGroupUnavailable"))
        #expect(body.contains("Guldr 1.0.0"))
    }

    @Test func dataChangesRefreshDependents() {
        var refreshes = 0
        let notifier = DataChangeNotifier { refreshes += 1 }
        notifier.dataDidChange()
        notifier.dataDidChange()
        #expect(refreshes == 2)
    }
}

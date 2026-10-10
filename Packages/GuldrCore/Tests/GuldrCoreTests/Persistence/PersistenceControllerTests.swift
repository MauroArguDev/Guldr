//
//  PersistenceControllerTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import SwiftData
import Testing
@testable import GuldrCore

struct PersistenceControllerTests {

    /// A temporary folder that plays the App Group container for one test.
    private struct FakeAppGroup {
        let root = FileManager.default.temporaryDirectory.appending(path: "GuldrTests-\(UUID().uuidString)")
        var lookup: (String) -> URL? { { [root] _ in root } }
        var storeURL: URL { root.appending(path: "Library/Application Support/Guldr.store") }
        func remove() { try? FileManager.default.removeItem(at: root) }
    }

    private func categoryCount(_ controller: PersistenceController) throws -> Int {
        try ModelContext(controller.container).fetchCount(FetchDescriptor<Category>())
    }

    // MARK: - App Group ID

    @Test func readsTheAppGroupIDFromInfoPlist() throws {
        #expect(try PersistenceController.appGroupID(from: ["AppGroupID": "group.com.argudev.guldr"]) == "group.com.argudev.guldr")
    }

    @Test func rejectsAMissingOrUnexpandedAppGroupID() {
        // `[String: Any]` is not Sendable, so these cannot be test arguments.
        let invalid: [[String: Any]?] = [
            nil, [:], ["AppGroupID": ""], ["AppGroupID": "$(APP_GROUP_ID)"], ["AppGroupID": 42]
        ]
        for infoDictionary in invalid {
            let error = #expect(throws: PersistenceError.self) {
                try PersistenceController.appGroupID(from: infoDictionary)
            }
            guard case .appGroupUnavailable = error else {
                Issue.record("Expected appGroupUnavailable for \(String(describing: infoDictionary))")
                continue
            }
        }
    }

    // MARK: - Store location and errors

    @Test func storeLivesInApplicationSupportInsideTheAppGroup() throws {
        let group = FakeAppGroup()
        defer { group.remove() }

        _ = try PersistenceController(mode: .app(appGroupID: "group.test"), groupContainerURL: group.lookup)

        #expect(FileManager.default.fileExists(atPath: group.storeURL.path(percentEncoded: false)))
    }

    @Test func aMissingAppGroupContainerIsReported() {
        let error = #expect(throws: PersistenceError.self) {
            try PersistenceController(mode: .app(appGroupID: "group.test")) { _ in nil }
        }
        guard case .appGroupUnavailable(let id) = error else {
            Issue.record("Expected appGroupUnavailable, got \(String(describing: error))")
            return
        }
        #expect(id == "group.test")
    }

    @Test func aStoreThatCannotBeCreatedIsReported() throws {
        // A file where the App Group folder should be: the store folder cannot be created inside it.
        let group = FakeAppGroup()
        defer { group.remove() }
        try Data().write(to: group.root)

        let error = #expect(throws: PersistenceError.self) {
            try PersistenceController(mode: .app(appGroupID: "group.test"), groupContainerURL: group.lookup)
        }
        guard case .storeCreationFailed = error else {
            Issue.record("Expected storeCreationFailed, got \(String(describing: error))")
            return
        }
    }

    // MARK: - App

    @Test func firstOpenSeedsAndReopeningKeepsData() throws {
        let group = FakeAppGroup()
        defer { group.remove() }

        let first = try PersistenceController(mode: .app(appGroupID: "group.test"), groupContainerURL: group.lookup)
        #expect(try categoryCount(first) == 11)
        let context = ModelContext(first.container)
        context.insert(Transaction(amount: try usd(4280), kind: .expense, title: "Groceries"))
        try context.save()

        let reopened = try PersistenceController(mode: .app(appGroupID: "group.test"), groupContainerURL: group.lookup)
        #expect(try categoryCount(reopened) == 11)
        let titles = try ModelContext(reopened.container).fetch(FetchDescriptor<Transaction>()).map(\.title)
        #expect(titles == ["Groceries"])
    }

    // MARK: - Widget

    @Test func widgetBeforeTheAppHasNoDataYet() {
        let group = FakeAppGroup()
        defer { group.remove() }

        let access = PersistenceController.widgetAccess(infoDictionary: ["AppGroupID": "group.test"],
                                                        groupContainerURL: group.lookup)
        guard case .noDataYet = access else {
            Issue.record("Expected noDataYet, got \(access)")
            return
        }
        // A read-only open must not leave an empty store behind.
        #expect(!FileManager.default.fileExists(atPath: group.storeURL.path(percentEncoded: false)))
    }

    @Test func widgetReadsWhatTheAppWroteAndCannotWrite() throws {
        let group = FakeAppGroup()
        defer { group.remove() }
        let app = try PersistenceController(mode: .app(appGroupID: "group.test"), groupContainerURL: group.lookup)

        let access = PersistenceController.widgetAccess(infoDictionary: ["AppGroupID": "group.test"],
                                                        groupContainerURL: group.lookup)
        guard case .ready(let container) = access else {
            Issue.record("Expected ready, got \(access)")
            return
        }
        let widgetContext = ModelContext(container)
        #expect(try widgetContext.fetchCount(FetchDescriptor<Category>()) == 11)

        widgetContext.insert(Category(name: "Pets", symbolName: "pawprint", color: .olive, kind: .expense))
        #expect(throws: (any Error).self) { try widgetContext.save() }
        #expect(try categoryCount(app) == 11)
    }

    @Test func widgetWithoutAnAppGroupIsUnavailable() {
        let access = PersistenceController.widgetAccess(infoDictionary: nil) { _ in nil }
        guard case .unavailable(.appGroupUnavailable) = access else {
            Issue.record("Expected unavailable(appGroupUnavailable), got \(access)")
            return
        }
    }

    // MARK: - In memory

    @Test func inMemoryStoresAreSeededAndIndependent() throws {
        let first = try PersistenceController(mode: .inMemory)
        let second = try PersistenceController(mode: .inMemory)
        let context = ModelContext(first.container)
        context.insert(Transaction(amount: try usd(100), kind: .expense))
        try context.save()

        #expect(try categoryCount(first) == 11)
        #expect(try ModelContext(first.container).fetchCount(FetchDescriptor<Transaction>()) == 1)
        #expect(try ModelContext(second.container).fetchCount(FetchDescriptor<Transaction>()) == 0)
    }
}

//
//  PersistenceController.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import SwiftData

/// Builds the one SwiftData container Guldr uses (ADR 007).
///
/// The store lives in the App Group so the app and the widget read the same data:
/// `<App Group>/Library/Application Support/Guldr.store`. CloudKit stays off until v1.1.
public struct PersistenceController: Sendable {

    public enum Mode: Sendable {
        /// Read-write, in the App Group. Seeds the default categories.
        case app(appGroupID: String)
        /// Read-only, in the App Group: the widget never writes. Throws `storeNotFound` until the app has
        /// created the store.
        case widget(appGroupID: String)
        /// Nothing touches the disk. For tests and previews. Seeds the default categories.
        case inMemory
    }

    /// The Info.plist key that holds the App Group ID, filled from `APP_GROUP_ID` in the xcconfig.
    public static let appGroupInfoKey = "AppGroupID"
    static let storeFileName = "Guldr.store"

    public let container: ModelContainer

    public init(mode: Mode) throws(PersistenceError) {
        try self.init(mode: mode) { appGroupID in
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        }
    }

    /// `groupContainerURL` is injectable so tests can point the App Group at a temporary folder.
    init(mode: Mode, groupContainerURL: (String) -> URL?) throws(PersistenceError) {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration: ModelConfiguration
        switch mode {
        case .app(let appGroupID):
            let url = try Self.storeURL(appGroupID: appGroupID, groupContainerURL: groupContainerURL)
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        case .widget(let appGroupID):
            let url = try Self.storeURL(appGroupID: appGroupID, groupContainerURL: groupContainerURL)
            guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
                throw .storeNotFound
            }
            configuration = ModelConfiguration(schema: schema, url: url, allowsSave: false, cloudKitDatabase: .none)
        case .inMemory:
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }

        do {
            container = try ModelContainer(for: schema, migrationPlan: GuldrMigrationPlan.self,
                                           configurations: configuration)
            if case .widget = mode { return }
            try CategorySeeder.seedDefaults(in: ModelContext(container))
        } catch {
            throw .storeCreationFailed(underlying: error)
        }
    }

    /// Reads the App Group ID from an Info.plist dictionary, rejecting a missing, empty or unexpanded
    /// (`$(APP_GROUP_ID)`) value.
    public static func appGroupID(from infoDictionary: [String: Any]?) throws(PersistenceError) -> String {
        guard let value = infoDictionary?[appGroupInfoKey] as? String,
              !value.isEmpty, !value.hasPrefix("$(") else {
            throw .appGroupUnavailable("Info.plist has no valid \(appGroupInfoKey)")
        }
        return value
    }

    /// The store file inside the App Group. Creates `Library/Application Support` if needed, since
    /// SwiftData does not create intermediate folders.
    static func storeURL(appGroupID: String, groupContainerURL: (String) -> URL?) throws(PersistenceError) -> URL {
        guard let groupURL = groupContainerURL(appGroupID) else {
            throw .appGroupUnavailable(appGroupID)
        }
        let folder = groupURL.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            throw .storeCreationFailed(underlying: error)
        }
        return folder.appending(path: storeFileName, directoryHint: .notDirectory)
    }
}

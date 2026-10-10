//
//  PersistenceController+Widget.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import SwiftData

extension PersistenceController {

    /// What the widget can show, decided once per timeline (ADR 007).
    public enum WidgetAccess: Sendable {
        /// The shared store, opened read-only.
        case ready(ModelContainer)
        /// The app has never been opened, so there is no store yet. Show the empty state.
        case noDataYet
        /// Something is wrong with the App Group or the store. Show the empty state too; the app
        /// itself surfaces the problem with its error screen.
        case unavailable(PersistenceError)
    }

    /// Opens the shared store for the widget, reading the App Group ID from the extension's
    /// Info.plist. Never throws: every outcome maps to something the widget can render.
    public static func widgetAccess(infoDictionary: [String: Any]?) -> WidgetAccess {
        widgetAccess(infoDictionary: infoDictionary) { appGroupID in
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        }
    }

    static func widgetAccess(infoDictionary: [String: Any]?, groupContainerURL: (String) -> URL?) -> WidgetAccess {
        do {
            let appGroupID = try appGroupID(from: infoDictionary)
            let controller = try PersistenceController(mode: .widget(appGroupID: appGroupID),
                                                       groupContainerURL: groupContainerURL)
            return .ready(controller.container)
        } catch .storeNotFound {
            return .noDataYet
        } catch {
            return .unavailable(error)
        }
    }
}

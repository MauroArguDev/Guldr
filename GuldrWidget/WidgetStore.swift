//
//  WidgetStore.swift
//  GuldrWidget
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import GuldrCore

/// The widget's door to the shared store and settings (ADR 007, 010). The extension's own Info.plist
/// carries `AppGroupID`, so `Bundle.main` here is the extension bundle, not the app's.
nonisolated enum WidgetStore {

    static func open() -> PersistenceController.WidgetAccess {
        PersistenceController.widgetAccess(infoDictionary: Bundle.main.infoDictionary)
    }

    /// `nil` when the App Group can't be opened; the widget then shows its empty state.
    static func settings() -> AppSettings? {
        guard let appGroupID = try? PersistenceController.appGroupID(from: Bundle.main.infoDictionary) else {
            return nil
        }
        return try? AppSettings.shared(appGroupID: appGroupID)
    }
}

//
//  WidgetStore.swift
//  GuldrWidget
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import GuldrCore

/// The widget's door to the shared store (ADR 007). The extension's own Info.plist carries
/// `AppGroupID`, so `Bundle.main` here is the extension bundle, not the app's.
enum WidgetStore {

    static func open() -> PersistenceController.WidgetAccess {
        PersistenceController.widgetAccess(infoDictionary: Bundle.main.infoDictionary)
    }
}

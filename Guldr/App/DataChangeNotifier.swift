//
//  DataChangeNotifier.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI
import WidgetKit

/// The one call the app makes after any save that changes totals (ADR 007). Everything that depends
/// on the data refreshes from here: today the widgets, from Phase 25 also budget notifications.
///
/// Read it from the environment (`@Environment(\.dataChangeNotifier)`). The action is injectable so
/// tests and previews can observe calls without touching WidgetKit.
struct DataChangeNotifier {

    private let refreshDependents: () -> Void

    init(refreshDependents: @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() }) {
        self.refreshDependents = refreshDependents
    }

    /// Call after a successful save. WidgetKit coalesces reloads, so calling it once per save is fine.
    func dataDidChange() {
        refreshDependents()
    }
}

extension EnvironmentValues {
    @Entry var dataChangeNotifier = DataChangeNotifier()
}

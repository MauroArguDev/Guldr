//
//  AppDataLoader.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import GuldrCore
import Observation
import SwiftData

/// Opens the shared store and settings at launch and keeps the result, so the root view can show either
/// the app or the error screen (ADR 007). Opening is synchronous: it is a local SQLite open, done once.
@Observable
final class AppDataLoader {

    enum State {
        case ready(ModelContainer, AppSettings)
        case failed(PersistenceError)
    }

    private(set) var state: State

    init(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) {
        self.infoDictionary = infoDictionary
        state = Self.open(infoDictionary: infoDictionary)
    }

    /// Tries again after a failure, e.g. once the user frees up storage.
    func retry() {
        state = Self.open(infoDictionary: infoDictionary)
    }

    // MARK: - Private

    @ObservationIgnored private let infoDictionary: [String: Any]?

    private static func open(infoDictionary: [String: Any]?) -> State {
        do {
            let appGroupID = try PersistenceController.appGroupID(from: infoDictionary)
            let container = try PersistenceController(mode: .app(appGroupID: appGroupID)).container
            return .ready(container, try AppSettings.shared(appGroupID: appGroupID))
        } catch {
            return .failed(error)
        }
    }
}

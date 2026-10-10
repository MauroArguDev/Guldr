//
//  GuldrApp.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 29/9/26.
//

import SwiftData
import SwiftUI

@main
struct GuldrApp: App {

    @State private var loader = AppDataLoader()

    var body: some Scene {
        WindowGroup {
            switch loader.state {
            case .ready(let container):
                ContentView()
                    .modelContainer(container)
            case .failed(let error):
                StoreErrorView(error: error, retry: loader.retry)
            }
        }
    }
}

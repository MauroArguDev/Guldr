//
//  ContentView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 29/9/26.
//

import SwiftUI

/// Placeholder root until the app shell (v1 plan, Phase 16). Debug builds link to the design system
/// gallery so it can be reviewed on a device.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Wordmark(size: .large)
                #if DEBUG
                NavigationLink {
                    DesignSystemGallery()
                } label: {
                    Text(verbatim: "Design system gallery")
                }
                .buttonStyle(.primary)
                .fixedSize()
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.appBackground))
        }
    }
}

#Preview("Light") {
    ContentView().preferredColorScheme(.light)
}

#Preview("Dark") {
    ContentView().preferredColorScheme(.dark)
}

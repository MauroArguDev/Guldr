//
//  AnalyticsView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI

/// The Analytics tab's root. Placeholder until its phase builds the screen.
struct AnalyticsView: View {
    var body: some View {
        NavigationStack {
            Color(.appBackground)
                .ignoresSafeArea()
                .navigationTitle(Text(AppTab.analytics.title))
        }
    }
}

#Preview("Light") {
    AnalyticsView().preferredColorScheme(.light)
}

#Preview("Dark") {
    AnalyticsView().preferredColorScheme(.dark)
}

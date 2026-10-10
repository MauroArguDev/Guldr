//
//  DashboardView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI

/// The Home tab's root. Placeholder until the dashboard (v1 plan, Phase 19); debug builds link to the
/// design system gallery from here.
struct DashboardView: View {
    var body: some View {
        NavigationStack {
            Color(.appBackground)
                .ignoresSafeArea()
                .navigationTitle(Text(AppTab.home.title))
                #if DEBUG
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            DesignSystemGallery()
                        } label: {
                            Label {
                                Text(verbatim: "Design system gallery")
                            } icon: {
                                Image(systemName: "swatchpalette")
                            }
                        }
                    }
                }
                #endif
        }
    }
}

#Preview("Light") {
    DashboardView().preferredColorScheme(.light)
}

#Preview("Dark") {
    DashboardView().preferredColorScheme(.dark)
}

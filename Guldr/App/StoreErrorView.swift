//
//  StoreErrorView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftUI

/// Shown instead of the app when the store cannot be opened. Calm on purpose: nothing has been
/// deleted, so the user can retry or write to support with the details prefilled.
struct StoreErrorView: View {

    let error: PersistenceError
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Guldr couldn't open your data", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("Nothing has been deleted. Try again, and if this keeps happening, let us know.")
        } actions: {
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Color(.onGold))
            if let url = SupportContact.mailURL(subject: "Guldr couldn't open my data",
                                                problem: String(describing: error)) {
                Link("Contact support", destination: url)
                    .foregroundStyle(Color(.gold))
            }
        }
        .tint(Color(.goldFill))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.appBackground))
    }
}

#Preview("Light") {
    StoreErrorView(error: .appGroupUnavailable("group.com.argudev.guldr"), retry: {})
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    StoreErrorView(error: .appGroupUnavailable("group.com.argudev.guldr"), retry: {})
        .preferredColorScheme(.dark)
}

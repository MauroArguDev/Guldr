//
//  Wordmark.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI

/// The lowercase "guldr" wordmark from the asset catalog: outlined vector SVGs for light and dark,
/// so the Manrope font is not bundled (DESIGN.md › Typography).
///
/// Sized like the mockups' text: the SVG's height is 0.99 em of Manrope (1980 of 2000 units), so a
/// 26 pt header wordmark is 25.7 pt tall. Like a logo, it does not scale with Dynamic Type.
struct Wordmark: View {

    enum Size {
        /// The Dashboard header: 26 pt.
        case header
        /// The lock screen: 40 pt.
        case large

        var fontSize: CGFloat { self == .header ? 26 : 40 }
    }

    var size: Size = .header

    var body: some View {
        Image(.wordmark)
            .resizable()
            .scaledToFit()
            .frame(height: size.fontSize * 0.99)
            .accessibilityLabel(Text(verbatim: "Guldr"))
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview("Light and dark") {
    VStack(spacing: 32) {
        ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
            VStack(spacing: 20) {
                Wordmark()
                Wordmark(size: .large)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(Color(.appBackground))
            .environment(\.colorScheme, scheme)
        }
    }
}

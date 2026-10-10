//
//  IconChip.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI

/// An SF Symbol on a `SurfaceSecondary` rounded square. Always neutral: category colors appear only
/// in the analytics donut (ADR 009). Decorative, since the row next to it names the category.
struct IconChip: View {

    enum Size {
        /// Dashboard rows: 42 pt, radius 13, 20 pt glyph.
        case regular
        /// Transactions list: 40 pt, radius 12, 19 pt glyph.
        case compact
        /// Budget category rows: 38 pt, radius 12, 18 pt glyph.
        case budget

        var side: CGFloat {
            switch self {
            case .regular: Guldr.Size.iconChip
            case .compact: Guldr.Size.iconChipCompact
            case .budget: Guldr.Size.iconChipBudget
            }
        }

        var radius: CGFloat { self == .regular ? Radius.iconChipLarge : Radius.iconChip }

        var glyph: CGFloat {
            switch self {
            case .regular: Guldr.Size.iconGlyph
            case .compact: Guldr.Size.iconGlyphCompact
            case .budget: Guldr.Size.iconGlyphBudget
            }
        }
    }

    let symbol: String
    var size: Size = .regular

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size.glyph, weight: .regular))
            .foregroundStyle(Color(.textPrimary))
            .frame(width: size.side, height: size.side)
            .background(Color(.surfaceSecondary), in: RoundedRectangle(cornerRadius: size.radius, style: .continuous))
            .accessibilityHidden(true)
    }
}

#Preview("Light and dark") {
    VStack(spacing: 24) {
        ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
            HStack(spacing: 16) {
                IconChip(symbol: "fork.knife")
                IconChip(symbol: "car", size: .compact)
                IconChip(symbol: "heart", size: .budget)
                IconChip(symbol: "briefcase")
            }
            .padding()
            .background(Color(.surface))
            .environment(\.colorScheme, scheme)
        }
    }
    .padding()
    .background(Color(.appBackground))
}

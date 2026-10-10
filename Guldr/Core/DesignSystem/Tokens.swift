//
//  Tokens.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import CoreGraphics

// Layout values from docs/design/tokens.json, copied by hand. Change them there first, then here.
// Colors are not here: they come from the GuldrColors asset catalog.

/// Padding and gaps, in points (`spacing_pt`).
enum Spacing {
    /// Leading and trailing screen padding.
    static let screenHorizontal: CGFloat = 20
    static let screenTop: CGFloat = 64
    /// Between the Dashboard's stacked cards.
    static let stackDefault: CGFloat = 16
    /// Between list sections.
    static let stackCompact: CGFloat = 10
    static let cardPadding: CGFloat = 22
    static let cardPaddingCompact: CGFloat = 18
    static let rowVertical: CGFloat = 8
    /// Between a row's icon chip and its text.
    static let rowGap: CGFloat = 12
}

/// Corner radii, in points (`radius_pt`). Buttons are capsules, so there is no pill value here.
enum Radius {
    /// Balance and budget ring cards.
    static let phoneCard: CGFloat = 28
    static let card: CGFloat = 24
    static let compactCard: CGFloat = 22
    static let alert: CGFloat = 18
    static let field: CGFloat = 16
    static let categoryChip: CGFloat = 14
    static let keypadKey: CGFloat = 14
    static let iconChipLarge: CGFloat = 13
    static let iconChip: CGFloat = 12
    static let segmented: CGFloat = 12
    static let segmentedThumb: CGFloat = 9
    static let progressBar: CGFloat = 3
}

/// Fixed sizes, in points (`size_pt`). Text sizes live in `Typography`.
enum Size {
    /// Dashboard rows.
    static let iconChip: CGFloat = 42
    /// Transactions list rows.
    static let iconChipCompact: CGFloat = 40
    /// Budget category rows.
    static let iconChipBudget: CGFloat = 38
    static let iconGlyph: CGFloat = 20
    static let iconGlyphCompact: CGFloat = 19
    static let iconGlyphBudget: CGFloat = 18
    static let tabBarHeight: CGFloat = 64
    static let addButton: CGFloat = 64
    static let touchTargetMin: CGFloat = 44
    /// Dashboard and widget bars.
    static let progressBarHeight: CGFloat = 6
    /// Budget category rows.
    static let progressBarHeightCompact: CGFloat = 5
    static let budgetRing: CGFloat = 168
    static let budgetRingStroke: CGFloat = 12
    static let miniRing: CGFloat = 44
    static let miniRingStroke: CGFloat = 5
}

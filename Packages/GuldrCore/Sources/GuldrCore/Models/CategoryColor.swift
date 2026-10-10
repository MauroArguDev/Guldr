//
//  CategoryColor.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 9/10/26.
//

/// The curated palette a category picks its base color from (ADR 009), in picker order: twelve hues
/// around the color wheel, then a neutral.
///
/// Each case matches a `Category…` color in the `GuldrColors` asset catalog (`gold` → `CategoryGold`),
/// with light and dark variants. The raw value is what the store keeps; the app maps each case to its
/// generated color symbol, so no hex value appears in code.
public enum CategoryColor: String, CaseIterable, Codable, Sendable {
    case gold
    case amber
    case terracotta
    case wine
    case rose
    case plum
    case indigo
    case blue
    case sky
    case teal
    case green
    case olive
    case graphite
}

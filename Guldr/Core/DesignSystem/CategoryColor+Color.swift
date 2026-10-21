//
//  CategoryColor+Color.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftUI

extension CategoryColor {
    /// The palette color from `GuldrColors` (ADR 009). Used only by the analytics donut and its
    /// legend; icon chips stay neutral.
    var color: Color {
        switch self {
        case .gold: Color(.categoryGold)
        case .amber: Color(.categoryAmber)
        case .terracotta: Color(.categoryTerracotta)
        case .wine: Color(.categoryWine)
        case .rose: Color(.categoryRose)
        case .plum: Color(.categoryPlum)
        case .indigo: Color(.categoryIndigo)
        case .blue: Color(.categoryBlue)
        case .sky: Color(.categorySky)
        case .teal: Color(.categoryTeal)
        case .green: Color(.categoryGreen)
        case .olive: Color(.categoryOlive)
        case .graphite: Color(.categoryGraphite)
        }
    }

    /// What VoiceOver reads for the swatch in the category editor.
    var accessibilityName: LocalizedStringKey {
        switch self {
        case .gold: "Gold"
        case .amber: "Amber"
        case .terracotta: "Terracotta"
        case .wine: "Wine"
        case .rose: "Rose"
        case .plum: "Plum"
        case .indigo: "Indigo"
        case .blue: "Blue"
        case .sky: "Sky"
        case .teal: "Teal"
        case .green: "Green"
        case .olive: "Olive"
        case .graphite: "Graphite"
        }
    }
}

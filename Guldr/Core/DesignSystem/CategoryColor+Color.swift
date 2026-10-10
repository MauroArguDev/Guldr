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
}

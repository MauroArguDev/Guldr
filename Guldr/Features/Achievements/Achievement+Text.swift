//
//  Achievement+Text.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import GuldrCore

// The words for the catalog's identifiers, which `GuldrCore` keeps free of display text.

extension AchievementID {

    var title: LocalizedStringResource {
        switch self {
        case .unbroken: "Unbroken"
        case .daysLogged: "Days logged"
        case .completeMonth: "Complete month"
        case .bookkeeper: "Bookkeeper"
        case .withinBudget: "Within budget"
        case .steadyHand: "Steady hand"
        case .saver: "Saver"
        case .inTheBlack: "In the black"
        }
    }

    var summary: LocalizedStringResource {
        switch self {
        case .unbroken: "Your best streak, in days."
        case .daysLogged: "Days you've logged, in total."
        case .completeMonth: "Months with 90% of their days logged."
        case .bookkeeper: "Transactions in Guldr."
        case .withinBudget: "Complete months with every budget kept."
        case .steadyHand: "Complete months in a row with every budget kept."
        case .saver: "Your best savings rate in a complete month."
        case .inTheBlack: "Complete months in a row saving more than zero."
        }
    }
}

extension AchievementFamily {

    var title: LocalizedStringResource {
        switch self {
        case .consistency: "Consistency"
        case .ledger: "Ledger up to date"
        case .budget: "Budget"
        case .reserve: "Reserve"
        }
    }
}

extension AchievementTier {

    /// Their own keys: "Gold" is already a category color, which Spanish calls "Dorado", while the medal
    /// is "Oro".
    var title: LocalizedStringResource {
        switch self {
        case .bronze: LocalizedStringResource("achievement.tier.bronze", defaultValue: "Bronze",
                                              comment: "The bronze tier of an achievement.")
        case .silver: LocalizedStringResource("achievement.tier.silver", defaultValue: "Silver",
                                              comment: "The silver tier of an achievement.")
        case .gold: LocalizedStringResource("achievement.tier.gold", defaultValue: "Gold",
                                            comment: "The gold tier of an achievement.")
        }
    }
}

extension AchievementProgress {

    /// "8 / 12", or "18% / 20%" for the savings rate: no unit word, so no plural rules; the summary says
    /// what is counted.
    func amountText(locale: Locale) -> String {
        let shown = nextTier.map { achievement.threshold(for: $0) } ?? value
        let format = { (number: Int) -> String in
            achievement.unit == .percent
                ? (Double(number) / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
                : number.formatted(.number.locale(locale))
        }
        return "\(format(value)) / \(format(shown))"
    }
}

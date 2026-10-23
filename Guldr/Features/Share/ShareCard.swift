//
//  ShareCard.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import CoreTransferable
import Foundation
import GuldrCore
import SwiftUI
import UniformTypeIdentifiers

/// The two image sizes (author's call, 2026-10-23): stories and square. Laid out in points and rendered
/// at 3×, so a story is 1080 × 1920 pixels.
enum ShareCardFormat: String, CaseIterable, Identifiable {
    case story
    case square

    var id: Self { self }

    var points: CGSize {
        switch self {
        case .story: CGSize(width: 360, height: 640)
        case .square: CGSize(width: 360, height: 360)
        }
    }

    static let scale: CGFloat = 3

    var title: LocalizedStringResource {
        switch self {
        case .story: "Story"
        case .square: "Square"
        }
    }
}

/// What a card shows: an achievement's tier, or a month in review. Neither can hold an amount: the recap
/// is built from `MonthlyRecap`, which has no `Money` (v1 plan, Phase 31).
enum ShareCardContent {
    case achievement(Achievement, AchievementTier)
    case recap(RecapCard)

    /// The sheet's title.
    var title: LocalizedStringResource {
        switch self {
        case .achievement: "Share achievement"
        case .recap(let card): "Your \(card.monthName) in Guldr"
        }
    }

    /// The text shared with the image, which also describes it for VoiceOver.
    var message: String {
        switch self {
        case .achievement(let achievement, let tier):
            String(localized: "\(achievement.id.title) · \(tier.title), earned in Guldr.")
        case .recap(let card):
            String(localized: "My \(card.monthName) in Guldr: \(card.recap.daysLogged) of \(card.recap.daysInMonth) days logged.")
        }
    }
}

/// A month in review in words, for the recap card. Every value is a count, a percentage or a name.
struct RecapCard {

    struct Row: Identifiable {
        let label: LocalizedStringResource
        let value: String
        var id: String { String(localized: label) }
    }

    let recap: MonthlyRecap
    /// The top category's shown name (`Category.displayName`).
    let topCategoryName: String?
    let locale: Locale
    let timeZone: TimeZone

    /// "October", mid-sentence: lowercase in Spanish.
    var monthName: String {
        var style = Date.FormatStyle(locale: locale, timeZone: timeZone).month(.wide)
        style.capitalizationContext = .middleOfSentence
        return recap.month.dateInterval(in: timeZone).start.formatted(style)
    }

    /// "October 2026", for the card's overline.
    var monthTitle: String {
        recap.month.title(locale: locale, timeZone: timeZone)
    }

    /// What the card lists, in order; a row without data is left out.
    var rows: [Row] {
        var rows = [Row(label: "Days logged", value: "\(number(recap.daysLogged)) / \(number(recap.daysInMonth))")]
        if recap.budgetsSet > 0 {
            rows.append(Row(label: "Budgets kept", value: "\(number(recap.budgetsKept)) / \(number(recap.budgetsSet))"))
        }
        if let rate = recap.savingsRate {
            rows.append(Row(label: "Saved", value: percent(rate)))
        }
        if recap.bestStreak > 0 {
            rows.append(Row(label: "Best streak", value: String(localized: "\(recap.bestStreak) days in a row")))
        }
        if let top = recap.topCategory, let name = topCategoryName {
            rows.append(Row(label: "Top spending", value: "\(name) · \(percent(top.share))"))
        }
        return rows
    }

    private func number(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    private func percent(_ value: Int) -> String {
        (Double(value) / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }
}

/// The PNG that `ShareLink` hands over, rendered before the sheet offers it.
nonisolated struct ShareImage: Transferable {

    let png: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.png }
            .suggestedFileName("Guldr.png")
    }
}

//
//  GuldrWidget.swift
//  GuldrWidget
//
//  Created by Mauricio Argumedo on 2/10/26.
//

import GuldrCore
import SwiftUI
import WidgetKit

/// The balance widget, small and medium (Widgets mockup). Its data comes from `SummaryProvider`.
struct GuldrWidget: Widget {

    let kind = "GuldrWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SummaryProvider()) { entry in
            SummaryWidgetView(entry: entry)
                .containerBackground(Color(.widgetBackground), for: .widget)
        }
        .configurationDisplayName("Balance")
        .description("Your balance and this month at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// Light, dark and tinted are the canvas's appearance and rendering-mode variants; each preview below
// steps through the states a family can show.
#Preview("Small", as: .systemSmall) {
    GuldrWidget()
} timeline: {
    SummaryEntry(date: .now, content: .summary(.sample), hidesAmounts: false)
    SummaryEntry(date: .now, content: .summary(.sample), hidesAmounts: true)
    SummaryEntry(date: .now, content: .summary(.emptySample), hidesAmounts: false)
    SummaryEntry(date: .now, content: .notStarted, hidesAmounts: false)
}

#Preview("Medium", as: .systemMedium) {
    GuldrWidget()
} timeline: {
    SummaryEntry(date: .now, content: .summary(.sample), hidesAmounts: false,
                 streak: SummaryEntry.Streak(count: 12, isTodayLogged: true))
    SummaryEntry(date: .now, content: .summary(.sample), hidesAmounts: false,
                 streak: SummaryEntry.Streak(count: 12, isTodayLogged: false))
    SummaryEntry(date: .now, content: .summary(.sample), hidesAmounts: true)
    SummaryEntry(date: .now, content: .summary(.emptySample), hidesAmounts: false)
    SummaryEntry(date: .now, content: .notStarted, hidesAmounts: false)
}

private extension WidgetSummary {
    /// A first launch without transactions: everything at zero.
    static var emptySample: WidgetSummary {
        let sample = WidgetSummary.sample
        return (try? WidgetSummary(transactions: [], currencyCode: sample.balance.currencyCode, now: .now,
                                   categoryName: { _ in "" })) ?? sample
    }
}

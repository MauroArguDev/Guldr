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

/// Placeholder layout until the families get their own views.
struct SummaryWidgetView: View {

    let entry: SummaryEntry

    var body: some View {
        switch entry.content {
        case .notStarted:
            Text("Open Guldr to get started")
        case .summary(let summary):
            Text(verbatim: MoneyFormatter().string(from: summary.balance, precision: .wholeUnits))
        }
    }
}

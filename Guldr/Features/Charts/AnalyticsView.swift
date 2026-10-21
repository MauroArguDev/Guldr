//
//  AnalyticsView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftUI

/// The Analytics tab: the Charts mockup. A native large title, then the period picker as the first row
/// of the content. Until the charts are built (v1 plan, Phase 21), the body is the empty state a new
/// user sees.
struct AnalyticsView: View {

    @Environment(AppRouter.self) private var router
    /// 6M the first time, as in the mockup, then the last period chosen (author's call, 2026-10-20). A
    /// preference of this screen only, so it stays in the app's own defaults, not the App Group.
    @AppStorage("analyticsPeriod") private var period: CashFlowSeries.Period = .sixMonths

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.stackDefault) {
                    periodPicker
                    EmptyStateView(title: "Nothing to chart yet", symbol: "chart.bar",
                                   message: "Your income and spending show up here once you add transactions.",
                                   actionTitle: "Add transaction") {
                        router.present(.addTransaction)
                    }
                    .padding(.top, Spacing.stackDefault)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.stackDefault)
            }
            .background(Color(.appBackground))
            .navigationTitle(Text(AppTab.analytics.title))
        }
    }

    private var periodPicker: some View {
        Picker("Period", selection: $period) {
            ForEach(CashFlowSeries.Period.allCases, id: \.self) { period in
                Text(period.shortTitle)
                    .accessibilityLabel(Text(period.spokenTitle))
            }
        }
        .pickerStyle(.segmented)
        .sensoryFeedback(Haptics.selection, trigger: period)
    }
}

extension CashFlowSeries.Period {

    /// The picker's label, as in the mockup.
    var shortTitle: LocalizedStringKey {
        switch self {
        case .oneMonth: "1M"
        case .threeMonths: "3M"
        case .sixMonths: "6M"
        case .oneYear: "1Y"
        }
    }

    /// What VoiceOver reads instead of the abbreviation.
    var spokenTitle: LocalizedStringKey {
        switch self {
        case .oneMonth: "1 month"
        case .threeMonths: "3 months"
        case .sixMonths: "6 months"
        case .oneYear: "1 year"
        }
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    PreviewEnvironment { AnalyticsView() }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewEnvironment { AnalyticsView() }
        .preferredColorScheme(.dark)
}
#endif

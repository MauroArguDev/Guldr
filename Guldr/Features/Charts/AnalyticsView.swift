//
//  AnalyticsView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftData
import SwiftUI

/// The Analytics tab: the Charts mockup. A native large title, then the period picker, the period's
/// income, expenses and savings, the income vs. expenses chart and spending by category. Every figure covers the period
/// ending with the current month, in the active currency (ADR 005).
struct AnalyticsView: View {

    @Environment(AppRouter.self) private var router
    @Environment(Preferences.self) private var preferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var transactions: [Transaction]
    @Query private var categories: [Category]
    /// 6M the first time, as in the mockup, then the last period chosen (author's call, 2026-10-20). A
    /// preference of this screen only, so it stays in the app's own defaults, not the App Group.
    @AppStorage("analyticsPeriod") private var period: CashFlowSeries.Period = .sixMonths
    @State private var model: AnalyticsModel

    /// `now` is injectable so previews can show the preview data set on the mockups' date.
    init(now: @escaping () -> Date = { .now }) {
        _model = State(initialValue: AnalyticsModel(now: now))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.stackDefault) {
                    periodPicker
                    if model.hasData, let totals = model.totals {
                        totalsRow(totals)
                        CashFlowChart(bars: model.bars)
                        if let expenseTotal = model.expenseTotal, !model.slices.isEmpty {
                            CategoryDonut(slices: model.slices, total: expenseTotal, rangeTitle: model.rangeTitle)
                        }
                    } else {
                        emptyState
                            .padding(.top, Spacing.stackDefault)
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.stackDefault)
            }
            .onChange(of: transactions, initial: true) { refresh() }
            .onChange(of: categories) { refresh() }
            .onChange(of: period) { refresh() }
            .onChange(of: currencyCode) { refresh() }
            // An edit keeps the transaction's identity, so the query's results compare equal; a save says when.
            .onChange(of: router.lastSave) { refresh() }
            .background(Color(.appBackground))
            .navigationTitle(Text(AppTab.analytics.title))
        }
    }

    /// Totals use the active currency (ADR 005); before first launch picks one, the locale's.
    private var currencyCode: String {
        preferences.activeCurrencyCode ?? Currency.defaultCode(for: .autoupdatingCurrent)
    }

    private func refresh() {
        model.update(transactions: transactions, categories: categories, period: period, currencyCode: currencyCode)
    }

    /// "Income $31,050 · Expenses $12,875 · Saved $18,176" in whole units, as in the mockup; Saved in
    /// `Gold`, or with a minus sign in `Negative` when the period spent more than it earned (author's
    /// call, 2026-10-20). Stacked at accessibility sizes.
    private func totalsRow(_ totals: AnalyticsModel.Totals) -> some View {
        totalsLayout {
            total("Income", AmountText(totals.income, sign: .never, precision: .wholeUnits))
            total("Expenses", AmountText(totals.expenses, sign: .never, precision: .wholeUnits))
            total("Saved", AmountText(totals.net, tone: totals.net.isNegative ? .negative : .gold,
                                      precision: .wholeUnits))
        }
        .padding(.horizontal, 2)
    }

    private var totalsLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
    }

    private func total(_ title: LocalizedStringKey, _ amount: AmountText) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color(.textSecondary))
            amount
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// A new user is invited to add a transaction. A period with nothing in it says so and, below 1Y,
    /// offers the longest period, where older transactions show up.
    @ViewBuilder
    private var emptyState: some View {
        if !model.hasTransactions {
            EmptyStateView(title: "Nothing to chart yet", symbol: "chart.bar",
                           message: "Your income and spending show up here once you add transactions.",
                           actionTitle: "Add transaction") {
                router.present(.addTransaction)
            }
        } else if period != .oneYear {
            EmptyStateView(title: "Nothing in this period", symbol: "calendar",
                           message: "No income or expenses for \(model.rangeTitle).",
                           actionTitle: "Show the last year") {
                period = .oneYear
            }
        } else {
            EmptyStateView(title: "Nothing in this period", symbol: "calendar",
                           message: "No income or expenses for \(model.rangeTitle).")
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
// The preview data set reproduces the Charts mockup on its date, Sept 28, 2026.
#Preview("Light") {
    PreviewEnvironment { AnalyticsView(now: { PreviewData.referenceDate() }) }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewEnvironment { AnalyticsView(now: { PreviewData.referenceDate() }) }
        .preferredColorScheme(.dark)
}

#Preview("Empty") {
    PreviewEnvironment(seeded: false) { AnalyticsView() }
}
#endif

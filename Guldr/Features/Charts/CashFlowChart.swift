//
//  CashFlowChart.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 20/10/26.
//

import Charts
import GuldrCore
import SwiftUI

/// The Charts mockup's "Income vs. expenses" card: paired bars per month (a week for 1M), income in
/// `GoldFill` and expenses in `ChartExpense`, no y axis. Touching or dragging over the chart selects a
/// bar, dims the others and shows its income and expenses (author's call, 2026-10-20).
struct CashFlowChart: View {

    let bars: [AnalyticsModel.Bar]

    @Environment(\.locale) private var locale
    @ReduceMotion private var reduceMotion
    @State private var selectedKey: String?
    /// Bars grow from the baseline on first appearance (DESIGN.md › Motion); with Reduce Motion they
    /// appear at their final value.
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            chart
                .frame(height: 150)
        }
        .padding(Spacing.cardPaddingCompact)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(.standard)
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                title
                Spacer(minLength: 8)
                legend
            }
            VStack(alignment: .leading, spacing: 6) {
                title
                legend
            }
        }
    }

    private var title: some View {
        Text("Income vs. expenses")
            .textRole(.cardTitle)
            .foregroundStyle(Color(.textPrimary))
            .accessibilityAddTraits(.isHeader)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem("Income", color: Color(.goldFill))
            legendItem("Expenses", color: Color(.chartExpense))
        }
        .font(.caption)
        .foregroundStyle(Color(.textSecondary))
        .accessibilityHidden(true)
    }

    private func legendItem(_ title: LocalizedStringKey, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
        }
    }

    private var chart: some View {
        Chart {
            ForEach(bars) { bar in
                BarMark(x: .value("Period", bar.key), y: .value("Amount", revealed ? value(bar.income) : 0))
                    .foregroundStyle(Color(.goldFill))
                    .position(by: .value("Kind", "income"))
                    .cornerRadius(4)
                    .opacity(opacity(for: bar))
                    .accessibilityLabel(Text("\(bar.title), income"))
                    .accessibilityValue(Text(verbatim: amountText(bar.income)))
                BarMark(x: .value("Period", bar.key), y: .value("Amount", revealed ? value(bar.expenses) : 0))
                    .foregroundStyle(Color(.chartExpense))
                    .position(by: .value("Kind", "expenses"))
                    .cornerRadius(4)
                    .opacity(opacity(for: bar))
                    .accessibilityLabel(Text("\(bar.title), expenses"))
                    .accessibilityValue(Text(verbatim: amountText(bar.expenses)))
            }
            if let selected = selectedBar {
                RuleMark(x: .value("Period", selected.key))
                    .foregroundStyle(Color(.hairline))
                    .zIndex(-1)
                    .annotation(position: .top, spacing: 0,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        callout(for: selected)
                    }
            }
        }
        .chartXSelection(value: $selectedKey)
        .accessibilityChartDescriptor(CashFlowChartDescriptor(bars: bars, locale: locale))
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let key = value.as(String.self), let bar = barsByKey[key] {
                        Text(verbatim: bar.label)
                            .font(.caption)
                            .fontWeight(bar.isCurrent ? .semibold : .regular)
                            .foregroundStyle(bar.isCurrent ? Color(.textPrimary) : Color(.textSecondary))
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot.overlay(alignment: .bottom) {
                Rectangle().fill(Color(.hairline)).frame(height: 1)
            }
        }
        .motion(.standard, value: bars)
        .sensoryFeedback(Haptics.selection, trigger: selectedKey) { _, new in new != nil }
        // Only the marks' values animate, once layout has settled (`Motion.entranceDelay`, 32.5): a
        // transaction-wide animation in `onAppear` also animated the chart measuring its axes and plot.
        .motion(.reveal, value: revealed)
        .task {
            guard !revealed else { return }
            if !reduceMotion { try? await Task.sleep(for: Motion.entranceDelay) }
            revealed = true
        }
    }

    /// A small card with the selected bar's period, income and expenses, above the bar.
    private func callout(for bar: AnalyticsModel.Bar) -> some View {
        let formatter = MoneyFormatter(locale: locale)
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: bar.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(.textPrimary))
            calloutLine("Income", formatter.string(from: bar.income), color: Color(.goldFill))
            calloutLine("Expenses", formatter.string(from: bar.expenses), color: Color(.chartExpense))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(.surfaceSecondary), in: RoundedRectangle(cornerRadius: Radius.iconChip, style: .continuous))
    }

    private func calloutLine(_ title: LocalizedStringKey, _ amount: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).foregroundStyle(Color(.textSecondary))
            Spacer(minLength: 8)
            Text(verbatim: amount).monospacedDigit().foregroundStyle(Color(.textPrimary))
        }
        .font(.caption)
    }

    private func amountText(_ money: Money) -> String {
        MoneyFormatter(locale: locale).string(from: money)
    }

    private var barsByKey: [String: AnalyticsModel.Bar] {
        Dictionary(bars.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var selectedBar: AnalyticsModel.Bar? {
        selectedKey.flatMap { barsByKey[$0] }
    }

    private func opacity(for bar: AnalyticsModel.Bar) -> Double {
        guard let selectedKey else { return 1 }
        return bar.key == selectedKey ? 1 : 0.4
    }

    /// Swift Charts plots `Double`s; amounts are drawn in major units.
    private func value(_ money: Money) -> Double {
        NSDecimalNumber(decimal: money.decimalValue).doubleValue
    }
}

/// Audio Graphs for the bars: one category per month or week, income and expenses as two series.
private struct CashFlowChartDescriptor: AXChartDescriptorRepresentable {

    let bars: [AnalyticsModel.Bar]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let largest = bars.flatMap { [value($0.income), value($0.expenses)] }.max() ?? 0
        let currencyCode = bars.first?.income.currencyCode ?? Currency.defaultCode(for: locale)
        let xAxis = AXCategoricalDataAxisDescriptor(title: String(localized: "Period", locale: locale),
                                                    categoryOrder: bars.map(\.title))
        let yAxis = AXNumericDataAxisDescriptor(title: String(localized: "Amount", locale: locale),
                                                range: 0...max(largest, 1), gridlinePositions: []) { amount in
            amount.formatted(.currency(code: currencyCode).precision(.fractionLength(0)).locale(locale))
        }
        let income = AXDataSeriesDescriptor(name: String(localized: "Income", locale: locale), isContinuous: false,
                                            dataPoints: bars.map { AXDataPoint(x: $0.title, y: value($0.income)) })
        let expenses = AXDataSeriesDescriptor(name: String(localized: "Expenses", locale: locale), isContinuous: false,
                                              dataPoints: bars.map { AXDataPoint(x: $0.title, y: value($0.expenses)) })
        return AXChartDescriptor(title: String(localized: "Income vs. expenses", locale: locale), summary: nil,
                                 xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: [income, expenses])
    }

    private func value(_ money: Money) -> Double {
        NSDecimalNumber(decimal: money.decimalValue).doubleValue
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
private struct CashFlowChartSpecimen: View {
    var body: some View {
        // The Charts mockup's six months.
        let labels = ["Apr", "May", "Jun", "Jul", "Aug", "Sep"]
        let income: [Int64] = [500_000, 540_000, 500_000, 565_000, 500_000, 500_000]
        let expenses: [Int64] = [231_000, 214_000, 248_000, 198_000, 220_500, 175_950]
        let bars = labels.indices.map { index in
            AnalyticsModel.Bar(id: Date(timeIntervalSince1970: Double(index) * 2_678_400), label: labels[index],
                               title: labels[index], income: .previewUSD(income[index]),
                               expenses: .previewUSD(expenses[index]), isCurrent: index == labels.count - 1)
        }
        CashFlowChart(bars: bars)
            .padding(Spacing.screenHorizontal)
            .background(Color(.appBackground))
    }
}

#Preview("Light") {
    CashFlowChartSpecimen().preferredColorScheme(.light)
}

#Preview("Dark") {
    CashFlowChartSpecimen().preferredColorScheme(.dark)
}
#endif

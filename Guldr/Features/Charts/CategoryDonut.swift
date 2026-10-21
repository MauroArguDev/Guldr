//
//  CategoryDonut.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 20/10/26.
//

import Charts
import GuldrCore
import SwiftUI

/// The Charts mockup's spending by category card: a donut (136 pt, an 18 pt ring) with the period and
/// its total in the center, beside a legend that names every slice with its share (ADR 009).
///
/// Each slice is a subtle gradient from its category's base color to that color mixed 12 % with
/// `Surface`, with a 2 pt gap between slices. Instead of labels on the thin ring, touching a slice or
/// its legend row selects it: the center shows its name, amount and share, and the others dim (author's
/// call, 2026-10-20).
struct CategoryDonut: View {

    let slices: [AnalyticsModel.Slice]
    let total: Money
    /// "May – Oct", in the center while nothing is selected.
    let rangeTitle: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @ReduceMotion private var reduceMotion
    @State private var selectedID: String?
    /// The raw value Swift Charts reports for a touch on the ring: a running total of the slices' values.
    @State private var selectedAngle: Double?
    /// Slices sweep in on first appearance (DESIGN.md › Motion); with Reduce Motion they appear at once.
    @State private var revealed = false

    var body: some View {
        layout {
            donut
            legend
        }
        .padding(Spacing.cardPaddingCompact)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(.standard)
        .onChange(of: selectedAngle) { _, angle in
            guard let angle else { return }
            select(slice(at: angle)?.id)
        }
        .onChange(of: slices.map(\.id)) { _, ids in
            if let selectedID, !ids.contains(selectedID) { self.selectedID = nil }
        }
        .sensoryFeedback(Haptics.selection, trigger: selectedID) { _, new in new != nil }
    }

    /// Side by side as in the mockup; the legend goes under the donut at accessibility sizes.
    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
    }

    private var donut: some View {
        Chart(slices) { slice in
            SectorMark(angle: .value("Amount", revealed ? value(slice.total) : 0),
                       innerRadius: .ratio(100 / 136),
                       angularInset: 1)
                .foregroundStyle(gradient(for: slice.color))
                .opacity(selectedID == nil || selectedID == slice.id ? 1 : 0.35)
                .accessibilityLabel(Text(verbatim: slice.name))
                .accessibilityValue(Text(verbatim: spokenValue(slice)))
        }
        .chartLegend(.hidden)
        .chartAngleSelection(value: $selectedAngle)
        .chartBackground { _ in
            center
        }
        .accessibilityChartDescriptor(CategoryDonutDescriptor(slices: slices, rangeTitle: rangeTitle, locale: locale))
        .frame(width: 136, height: 136)
        .motion(.standard, value: slices)
        .motion(.standard, value: selectedID)
        .onAppear {
            guard !revealed else { return }
            if reduceMotion {
                revealed = true
            } else {
                withMotion(.reveal) { revealed = true }
            }
        }
    }

    /// The period and its total, or the selected slice's name, amount and share.
    private var center: some View {
        VStack(spacing: 2) {
            if let selected = selectedSlice {
                Text(verbatim: selected.name)
                    .font(.caption2)
                    .foregroundStyle(Color(.textSecondary))
                AmountText(selected.total, sign: .never, style: .display(.donutCenter), precision: .wholeUnits)
                Text(verbatim: percentText(selected))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(.textSecondary))
            } else {
                Text(verbatim: rangeTitle)
                    .font(.caption2)
                    .foregroundStyle(Color(.textSecondary))
                AmountText(total, sign: .never, style: .display(.donutCenter), precision: .wholeUnits)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(width: 84)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(slices) { slice in
                Button {
                    select(selectedID == slice.id ? nil : slice.id)
                } label: {
                    legendRow(slice)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: slice.name))
                .accessibilityValue(Text(verbatim: spokenValue(slice)))
                .accessibilityHint(Text("Shows this category in the center of the chart"))
                .accessibilityAddTraits(selectedID == slice.id ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendRow(_ slice: AnalyticsModel.Slice) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(slice.color.color)
                .frame(width: 8, height: 8)
            Text(verbatim: slice.name)
                .foregroundStyle(Color(.textPrimary))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: percentText(slice))
                .monospacedDigit()
                .foregroundStyle(Color(.textSecondary))
        }
        .textRole(.meta)
        .opacity(selectedID == nil || selectedID == slice.id ? 1 : 0.5)
        .contentShape(.rect)
    }

    private var selectedSlice: AnalyticsModel.Slice? {
        slices.first { $0.id == selectedID }
    }

    private func select(_ id: String?) {
        withMotion(.snappy) { selectedID = id }
    }

    /// The slice under a touch: the first whose running total reaches the reported value.
    private func slice(at angle: Double) -> AnalyticsModel.Slice? {
        var runningTotal = 0.0
        for slice in slices {
            runningTotal += value(slice.total)
            if angle <= runningTotal { return slice }
        }
        return slices.last
    }

    /// From the base color to the base color mixed 12 % with `Surface` (ADR 009).
    private func gradient(for color: CategoryColor) -> LinearGradient {
        LinearGradient(colors: [color.color, color.color.mix(with: Color(.surface), by: 0.12)],
                       startPoint: .top, endPoint: .bottom)
    }

    private func percentText(_ slice: AnalyticsModel.Slice) -> String {
        (Double(slice.percentage) / 100).formatted(.percent.precision(.fractionLength(0)))
    }

    /// "48%, $850.00".
    private func spokenValue(_ slice: AnalyticsModel.Slice) -> String {
        percentText(slice) + ", " + MoneyFormatter(locale: locale).string(from: slice.total)
    }

    private func value(_ money: Money) -> Double {
        NSDecimalNumber(decimal: money.decimalValue).doubleValue
    }
}

/// Audio Graphs for the donut: one category per slice, its amount as the value.
private struct CategoryDonutDescriptor: AXChartDescriptorRepresentable {

    let slices: [AnalyticsModel.Slice]
    let rangeTitle: String
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let largest = slices.map { value($0.total) }.max() ?? 0
        let currencyCode = slices.first?.total.currencyCode ?? Currency.defaultCode(for: locale)
        let xAxis = AXCategoricalDataAxisDescriptor(title: String(localized: "Category", locale: locale),
                                                    categoryOrder: slices.map(\.name))
        let yAxis = AXNumericDataAxisDescriptor(title: String(localized: "Amount", locale: locale),
                                                range: 0...max(largest, 1), gridlinePositions: []) { amount in
            amount.formatted(.currency(code: currencyCode).precision(.fractionLength(0)).locale(locale))
        }
        let series = AXDataSeriesDescriptor(name: String(localized: "Spending", locale: locale), isContinuous: false,
                                            dataPoints: slices.map { AXDataPoint(x: $0.name, y: value($0.total)) })
        return AXChartDescriptor(title: String(localized: "Spending by category, \(rangeTitle)", locale: locale),
                                 summary: nil, xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: [series])
    }

    private func value(_ money: Money) -> Double {
        NSDecimalNumber(decimal: money.decimalValue).doubleValue
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
private struct CategoryDonutSpecimen: View {
    var body: some View {
        // The Charts mockup's September.
        let names = ["Housing", "Food", "Shopping", "Transport", "Entertainment", "Health", "Other"]
        let colors: [CategoryColor] = [.indigo, .gold, .plum, .sky, .wine, .green, .graphite]
        let cents: [Int64] = [85_000, 31_200, 21_650, 14_500, 9_600, 4_000, 10_000]
        let percentages = [48, 18, 12, 8, 6, 2, 6]
        let slices = names.indices.map { index in
            AnalyticsModel.Slice(id: names[index], name: names[index], color: colors[index],
                                 total: .previewUSD(cents[index]), percentage: percentages[index])
        }
        CategoryDonut(slices: slices, total: .previewUSD(175_950), rangeTitle: "September")
            .padding(Spacing.screenHorizontal)
            .background(Color(.appBackground))
    }
}

#Preview("Light") {
    CategoryDonutSpecimen().preferredColorScheme(.light)
}

#Preview("Dark") {
    CategoryDonutSpecimen().preferredColorScheme(.dark)
}
#endif

//
//  DesignSystemGallery.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

#if DEBUG
import GuldrCore
import SwiftUI

/// Every design-system component and its animated states on one screen, for review on a device
/// (v1 plan, step 15.12). Debug builds only. The controls override appearance, text size and
/// Reduce Motion for this screen; "Replay" restarts the entrance animations.
struct DesignSystemGallery: View {

    enum Appearance: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"

        var id: String { rawValue }
        var scheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    enum TextSize: String, CaseIterable, Identifiable {
        case standard = "Default"
        case large = "XXXL"
        case accessibility = "AX5"

        var id: String { rawValue }
        var size: DynamicTypeSize {
            switch self {
            case .standard: .large
            case .large: .xxxLarge
            case .accessibility: .accessibility5
            }
        }
    }

    @State private var appearance = Appearance.system
    @State private var textSize = TextSize.standard
    @State private var reduceMotion = false
    @State private var replay = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                controls
                GallerySections()
                    .id(replay)
                    .environment(\.simulatesReduceMotion, reduceMotion)
                    .dynamicTypeSize(textSize.size)
            }
            .padding(Spacing.screenHorizontal)
        }
        .background(Color(.appBackground))
        .navigationTitle(Text(verbatim: "Design system"))
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(appearance.scheme)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(selection: $appearance) {
                ForEach(Appearance.allCases) { Text(verbatim: $0.rawValue).tag($0) }
            } label: { Text(verbatim: "Appearance") }
            Picker(selection: $textSize) {
                ForEach(TextSize.allCases) { Text(verbatim: $0.rawValue).tag($0) }
            } label: { Text(verbatim: "Text size") }
            Toggle(isOn: $reduceMotion) { Text(verbatim: "Simulate Reduce Motion") }
                .tint(Color(.goldFill))
            Button { replay += 1 } label: {
                Label { Text(verbatim: "Replay entrance animations") } icon: { Image(systemName: "arrow.counterclockwise") }
            }
            .foregroundStyle(Color(.gold))
        }
        .pickerStyle(.segmented)
        .padding(Spacing.cardPaddingCompact)
        .card(.compact)
    }
}

// MARK: - Sections

private struct GallerySections: View {

    @State private var balance: Int64 = 1_817_550
    @State private var usage = 0.71
    @State private var selectedChip = "food"
    @State private var saves = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            section("Colors") { colors }
            section("Typography") { typography }
            section("Surfaces") { surfaces }
            section("Atoms") { atoms }
            section("Molecules") { molecules }
        }
        .foregroundStyle(Color(.textPrimary))
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(verbatim: title).textRole(.overline).foregroundStyle(Color(.textSecondary))
            content()
        }
    }

    // MARK: Colors

    private var colors: some View {
        let interface: [(String, Color)] = [
            ("AppBackground", Color(.appBackground)), ("Surface", Color(.surface)),
            ("SurfaceSecondary", Color(.surfaceSecondary)), ("Field", Color(.field)),
            ("TextPrimary", Color(.textPrimary)), ("TextSecondary", Color(.textSecondary)),
            ("Hairline", Color(.hairline)), ("Track", Color(.track)), ("Gold", Color(.gold)),
            ("GoldFill", Color(.goldFill)), ("GoldSoft", Color(.goldSoft)), ("Positive", Color(.positive)),
            ("Negative", Color(.negative)), ("NegativeSoft", Color(.negativeSoft))
        ]
        let categories = CategoryColor.allCases.map { ($0.rawValue, $0.color) }
        return VStack(alignment: .leading, spacing: 14) {
            swatches(interface)
            swatches(categories)
        }
    }

    private func swatches(_ colors: [(String, Color)]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(colors, id: \.0) { name, color in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: Radius.iconChip, style: .continuous)
                        .fill(color)
                        .overlay { RoundedRectangle(cornerRadius: Radius.iconChip, style: .continuous).strokeBorder(Color(.hairline)) }
                        .frame(height: 44)
                    Text(verbatim: name).font(.caption2).foregroundStyle(Color(.textSecondary)).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        }
    }

    // MARK: Typography

    private var typography: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: "Transactions").textRole(.largeTitle)
            Text(verbatim: "Recent").textRole(.sectionTitle)
            Text(verbatim: "$5,000.00").textRole(.summaryValue)
            Text(verbatim: "Groceries").textRole(.rowTitle)
            Text(verbatim: "September budget").textRole(.cardTitle)
            Text(verbatim: "Food · Today").textRole(.meta).foregroundStyle(Color(.textSecondary))
            Text(verbatim: "September budget").textRole(.overline).foregroundStyle(Color(.textSecondary))
            Text(verbatim: "$42.80").displayFont(.addAmount)
            HStack(spacing: 24) {
                Wordmark()
                Wordmark(size: .large)
            }
        }
    }

    // MARK: Surfaces

    private var surfaces: some View {
        VStack(alignment: .leading, spacing: Spacing.stackDefault) {
            VStack(alignment: .leading, spacing: 14) {
                Text(verbatim: "Balance").textRole(.meta).foregroundStyle(Color(.textSecondary))
                AmountText(.previewUSD(balance), style: .hero)
                LedgerLines(variant: .leading, drawsIn: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.cardPadding)
            .card(.hero)

            HStack(spacing: 12) {
                summaryCard("Income", .previewUSD(500_000))
                summaryCard("Expenses", .previewUSD(175_950))
            }

            LedgerLines(variant: .centered).padding(.horizontal, 40)
            VStack(alignment: .leading, spacing: 8) {
                AmountText(.previewUSD(1_248_025), style: .display(.widgetSmall), precision: .wholeUnits)
                LedgerLines(variant: .compact)
            }
            .frame(width: 150)
        }
    }

    private func summaryCard(_ title: String, _ amount: Money) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: title).textRole(.meta).foregroundStyle(Color(.textSecondary))
            AmountText(amount, style: .summary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.cardPaddingCompact)
        .card(.compact)
    }

    // MARK: Atoms

    private var atoms: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                AmountText(.previewUSD(4_280), kind: .expense)
                Spacer()
                AmountText(.previewUSD(500_000), kind: .income)
                Spacer()
                AmountText(.previewUSD(9_600), tone: .negative)
            }
            Button { balance += 4_280 } label: { Text(verbatim: "Change the balance (numeric transition)") }
                .foregroundStyle(Color(.gold))
            HStack(spacing: 14) {
                IconChip(symbol: "fork.knife")
                IconChip(symbol: "car", size: .compact)
                IconChip(symbol: "heart", size: .budget)
            }
            ProgressBar(value: usage)
            ProgressBar(value: 1.2, height: .compact, tone: .over)
            HStack(spacing: 16) {
                MiniRing(value: usage)
                MiniRing(value: 1.2, tone: .over)
            }
            Button { usage = usage > 0.5 ? 0.32 : 0.71 } label: { Text(verbatim: "Change progress") }
                .foregroundStyle(Color(.gold))
            Button { saves += 1 } label: { Text(verbatim: "Save (success haptic)") }
                .buttonStyle(.primary)
                .sensoryFeedback(Haptics.saved, trigger: saves)
            Button {} label: { Text(verbatim: "Disabled") }
                .buttonStyle(.primary)
                .disabled(true)
        }
    }

    // MARK: Molecules

    private var molecules: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 18) {
                BudgetRing(remaining: .previewUSD(Int64((1 - min(usage, 1)) * 203_000)), usage: usage)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: "Spent").textRole(.meta).foregroundStyle(Color(.textSecondary))
                    AmountText(.previewUSD(Int64(usage * 203_000)), style: .summary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(.hero)

            OverBudgetAlert(categoryName: "Entertainment", overAmount: .previewUSD(1_600))

            VStack(spacing: 2) {
                CategoryBudgetRow(name: "Entertainment", symbol: "play", line: .preview(9_600, of: 8_000))
                CategoryBudgetRow(name: "Food", symbol: "fork.knife", line: .preview(31_200, of: 40_000))
            }

            BudgetSummaryRow(title: "September budget", detail: "$1,443.00 of $2,030.00 · 1 category over budget", usage: usage)
                .padding(.vertical, 16)
                .padding(.horizontal, Spacing.cardPaddingCompact)
                .card(.compact)

            VStack(spacing: 0) {
                TransactionRow(title: "Groceries", meta: "Food · Today", symbol: "fork.knife",
                               amount: .previewUSD(4_280), kind: .expense)
                TransactionRow(title: "Salary", meta: "Salary · Sep 25", symbol: "briefcase",
                               amount: .previewUSD(500_000), kind: .income)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(DefaultCategory.all.filter { $0.kind == .expense }, id: \.systemKey) { category in
                    CategoryChip(name: category.name, symbol: category.symbolName,
                                 isSelected: selectedChip == category.systemKey) { selectedChip = category.systemKey }
                }
            }

            EmptyStateView(title: "No transactions yet", symbol: "list.bullet",
                           message: "Add your first expense or income to see it here.",
                           actionTitle: "Add transaction", action: {})
                .frame(minHeight: 260)
                .card(.standard)
        }
    }
}

#Preview {
    NavigationStack { DesignSystemGallery() }
}
#endif

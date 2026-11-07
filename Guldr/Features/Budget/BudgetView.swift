//
//  BudgetView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftData
import SwiftUI

/// The Budget tab: the Budget mockup. A native large title, then the month with previous and next
/// buttons as the first row of the content, the ring card, an alert per over-budget category and every
/// budgeted category's row. A month without budgets shows the empty state. Swiping sideways moves between
/// months with the content following the finger. Edit opens the month's limits in a sheet.
struct BudgetView: View {

    @Environment(AppRouter.self) private var router
    @Environment(Preferences.self) private var preferences
    @Environment(\.modelContext) private var context
    @Environment(\.dataChangeNotifier) private var notifier
    @Environment(BudgetAlertCenter.self) private var alerts
    @Query private var transactions: [Transaction]
    @Query private var budgets: [Budget]
    @State private var model = BudgetModel()
    @State private var failedToCopy = false
    /// How far the finger has moved the pages.
    @State private var swipeOffset: CGFloat = 0
    @State private var pageWidth: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.stackCompact) {
                    monthSwitcher
                        .padding(.horizontal, Spacing.screenHorizontal)
                    monthPages
                }
                .padding(.bottom, Spacing.stackDefault)
                // Fills the screen, so a swipe also works below a short month.
                .frame(minHeight: viewportHeight, alignment: .top)
                .contentShape(.rect)
                .gesture(HorizontalPan(onChanged: followSwipe, onEnded: finishSwipe))
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.containerSize.height - geometry.contentInsets.top - geometry.contentInsets.bottom
            } action: { _, height in
                viewportHeight = max(height, 0)
            }
            .sensoryFeedback(Haptics.selection, trigger: model.month)
            .onChange(of: transactions, initial: true) { refresh() }
            .onChange(of: budgets) { refresh() }
            .onChange(of: model.month) { refresh() }
            .onChange(of: currencyCode) { refresh() }
            // An edit keeps the model's identity, so the queries' results compare equal; a save says when.
            .onChange(of: router.lastSave) { refresh() }
            .onChange(of: router.categoryChanges) { refresh() }
            .background(Color(.appBackground))
            .navigationTitle(Text(AppTab.budget.title))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        router.present(.editBudget(model.month))
                    }
                    .tint(Color(.gold))
                    .accessibilityHint(Text("Edits this month's budgets"))
                }
            }
        }
        .alert("Couldn't copy last month's budgets", isPresented: $failedToCopy) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try again in a moment.")
        }
    }

    /// Totals use the active currency (ADR 005); before first launch picks one, the locale's.
    private var currencyCode: String {
        preferences.activeCurrencyCode ?? Currency.defaultCode(for: .autoupdatingCurrent)
    }

    private func refresh() {
        model.update(transactions: transactions, budgets: budgets, currencyCode: currencyCode)
    }

    // MARK: - Pages

    /// The month on screen with the ones beside it past the edges, all moving with the finger. Only the month
    /// on screen takes up height. Each page keeps its identity as it moves, so landing a swipe redraws nothing.
    private var monthPages: some View {
        ZStack(alignment: .top) {
            // The neighbors wait for the width: until then they would sit on top of the month.
            ForEach(model.visibleMonths.filter { $0 == model.month || pageWidth > 0 }, id: \.self) { month in
                let isOnScreen = month == model.month
                pageContent(model.page(for: month))
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: isOnScreen ? nil : 0, alignment: .top)
                    .offset(x: offset(of: month))
                    .accessibilityHidden(!isOnScreen)
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pageWidth = $0 }
    }

    private func offset(of month: YearMonth) -> CGFloat {
        let position: CGFloat = month < model.month ? -1 : month > model.month ? 1 : 0
        return position * pageWidth + swipeOffset
    }

    private func pageContent(_ page: BudgetModel.Page) -> some View {
        VStack(spacing: Spacing.stackCompact) {
            if let overview = page.overview {
                BudgetOverviewCard(overview: overview)
                ForEach(page.alerts) { alert in
                    OverBudgetAlert(categoryName: alert.categoryName, overAmount: alert.overAmount)
                }
                categoryRows(page.rows)
            } else {
                emptyState(canCopyLastMonth: page.canCopyLastMonth)
                    .padding(.top, Spacing.stackDefault)
            }
        }
    }

    /// Nothing waits past next month, so the page only gives a little there.
    private func followSwipe(_ translation: CGFloat) {
        swipeOffset = translation < 0 && !model.canShowNextMonth ? translation / 3 : translation
    }

    /// One animation carries both: the offsets depend on the month, so the pages slide to their new places.
    private func finishSwipe(translation: CGFloat, velocity: CGFloat) {
        withMotion(.snappy) {
            model.finishSwipe(translation: translation, velocity: velocity, pageWidth: pageWidth)
            swipeOffset = 0
        }
    }

    /// A month without budgets (author's call, 2026-10-20): copying last month's is the primary action
    /// when it has any, with setting them by hand as the secondary one; otherwise only the latter.
    @ViewBuilder
    private func emptyState(canCopyLastMonth: Bool) -> some View {
        if canCopyLastMonth {
            EmptyStateView(title: "No budgets this month", symbol: "chart.pie",
                           message: "Start from last month's limits, or set new ones.",
                           actionTitle: "Copy last month's budgets", action: copyLastMonth,
                           secondaryActionTitle: "Set budgets", secondaryAction: editBudgets)
        } else {
            EmptyStateView(title: "No budgets yet", symbol: "chart.pie",
                           message: "Set a monthly limit for a category to see what is left to spend.",
                           actionTitle: "Set budgets", action: editBudgets)
        }
    }

    private func editBudgets() {
        router.present(.editBudget(model.month))
    }

    /// Copies and saves at once: the user already chose last month's limits, so there is nothing to review.
    /// It goes through the edit sheet's model, so both paths save the same way.
    private func copyLastMonth() {
        do {
            let editor = try EditBudgetModel(month: model.month, context: context, currencyCode: currencyCode,
                                             notifier: notifier)
            editor.copyLastMonth()
            try editor.save()
            router.finishSave(.saved)
            // No sheet closes on this path, so the budget alerts offer comes from here.
            Task { await alerts.offerIfNeeded() }
        } catch {
            failedToCopy = true
        }
    }

    /// The mockup's rows sit straight on the background, 2 pt apart, highest usage first.
    private func categoryRows(_ rows: [BudgetModel.Row]) -> some View {
        VStack(spacing: 2) {
            ForEach(rows) { row in
                CategoryBudgetRow(name: row.name, symbol: row.symbol, line: row.line)
                    .padding(.horizontal, 2)
            }
        }
    }

    /// "‹ September 2026 ›": chevrons in `TextSecondary` at the edges, the month centered. Next stops at
    /// next month and fades to 40 %, the disabled style of the primary button.
    private var monthSwitcher: some View {
        HStack(spacing: 0) {
            monthButton("Previous month", symbol: "chevron.left", alignment: .leading) {
                withMotion(.standard) { model.showPreviousMonth() }
            }
            Text(verbatim: model.monthTitle)
                .textRole(.cardTitle)
                .foregroundStyle(Color(.textPrimary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            monthButton("Next month", symbol: "chevron.right", alignment: .trailing) {
                withMotion(.standard) { model.showNextMonth() }
            }
            .disabled(!model.canShowNextMonth)
            .opacity(model.canShowNextMonth ? 1 : 0.4)
        }
    }

    private func monthButton(_ title: LocalizedStringKey, symbol: String, alignment: Alignment,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(.textSecondary))
                .frame(width: Size.touchTargetMin, height: Size.touchTargetMin, alignment: alignment)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    PreviewEnvironment { BudgetView() }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewEnvironment { BudgetView() }
        .preferredColorScheme(.dark)
}
#endif

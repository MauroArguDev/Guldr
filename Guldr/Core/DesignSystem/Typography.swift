//
//  Typography.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI

/// The SF Pro styles from DESIGN.md › Typography.
///
/// Sizes that match an iOS text style use it, so they follow Dynamic Type for free:
/// 34 = Large Title, 20 = Title 3, 16 = Callout, 15 = Subheadline, 13 = Footnote, 12 = Caption.
/// The 19 pt summary value has no matching style and scales with `@ScaledMetric`.
enum TextRole {
    case largeTitle
    case sectionTitle
    case summaryValue
    case rowTitle
    /// Row amounts: like `rowTitle`, with tabular digits so amounts line up.
    case rowAmount
    case cardTitle
    case meta
    /// Uppercase with wide tracking, e.g. "SEPTEMBER BUDGET".
    case overline
}

/// The New York serif sizes for large amounts and brand moments (`typography.display.sizes_pt`).
enum DisplaySize {
    case balance
    case balanceCents
    case addAmount
    case budgetRingCenter
    case widgetSmall
    case widgetMedium
    case donutCenter

    var points: CGFloat {
        switch self {
        case .balance: 46
        case .balanceCents: 26
        case .addAmount: 58
        case .budgetRingCenter: 30
        case .widgetSmall: 28
        case .widgetMedium: 26
        case .donutCenter: 20
        }
    }
}

extension View {
    /// Applies one of the SF Pro roles: font, weight, tracking and case.
    func textRole(_ role: TextRole) -> some View {
        modifier(TextRoleModifier(role: role))
    }

    /// New York serif at a display size, scaled with Dynamic Type, with tabular digits so changing
    /// amounts do not shift sideways.
    func displayFont(_ size: DisplaySize) -> some View {
        modifier(DisplayFontModifier(size: size))
    }
}

// MARK: - Modifiers

private struct TextRoleModifier: ViewModifier {

    let role: TextRole
    @ScaledMetric(relativeTo: .title3) private var summarySize: CGFloat = 19

    func body(content: Content) -> some View {
        switch role {
        case .largeTitle:
            content.font(.largeTitle.bold()).tracking(-0.68)        // −0.02 em
        case .sectionTitle:
            content.font(.title3.bold()).tracking(-0.2)              // −0.01 em
        case .summaryValue:
            content.font(.system(size: summarySize, weight: .semibold)).monospacedDigit()
        case .rowTitle:
            content.font(.callout.weight(.semibold))
        case .rowAmount:
            content.font(.callout.weight(.semibold)).monospacedDigit()
        case .cardTitle:
            content.font(.subheadline.weight(.semibold))
        case .meta:
            content.font(.footnote)
        case .overline:
            content.font(.caption.weight(.semibold)).tracking(1.2).textCase(.uppercase)   // +0.1 em
        }
    }
}

private struct DisplayFontModifier: ViewModifier {

    @ScaledMetric private var points: CGFloat

    init(size: DisplaySize) {
        _points = ScaledMetric(wrappedValue: size.points, relativeTo: .largeTitle)
    }

    func body(content: Content) -> some View {
        content.font(.system(size: points, design: .serif)).monospacedDigit()
    }
}

// MARK: - Previews

private struct TypographySpecimen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.stackDefault) {
                Text(verbatim: "September budget").textRole(.overline).foregroundStyle(Color(.textSecondary))
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(verbatim: "$12,450").displayFont(.balance)
                    Text(verbatim: ".80").displayFont(.balanceCents).foregroundStyle(Color(.textSecondary))
                }
                Text(verbatim: "$42.80").displayFont(.addAmount)
                Text(verbatim: "$587").displayFont(.budgetRingCenter)
                Text(verbatim: "Transactions").textRole(.largeTitle)
                Text(verbatim: "Recent").textRole(.sectionTitle)
                Text(verbatim: "$5,000.00").textRole(.summaryValue)
                HStack {
                    Text(verbatim: "Groceries").textRole(.rowTitle)
                    Spacer()
                    Text(verbatim: "−$42.80").textRole(.rowAmount)
                }
                Text(verbatim: "September budget").textRole(.cardTitle)
                Text(verbatim: "Food · Today").textRole(.meta).foregroundStyle(Color(.textSecondary))
            }
            .foregroundStyle(Color(.textPrimary))
            .padding(.horizontal, Spacing.screenHorizontal)
        }
        .background(Color(.appBackground))
    }
}

#Preview("Light") {
    TypographySpecimen().preferredColorScheme(.light)
}

#Preview("Dark") {
    TypographySpecimen().preferredColorScheme(.dark)
}

#Preview("Largest Dynamic Type") {
    TypographySpecimen().dynamicTypeSize(.accessibility5)
}

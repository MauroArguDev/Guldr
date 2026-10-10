//
//  Card.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI

/// The card surfaces from DESIGN.md › Color (Cards): `Surface` with a 1 pt `Hairline` border in both
/// modes; elevated cards also cast a soft shadow in light mode. Padding stays with the caller, since
/// it differs per card (22 balance, 20 budget ring, 18 charts).
enum CardStyle {
    /// Radius 28, shadow: the balance and budget ring cards.
    case hero
    /// Radius 24, shadow: chart cards.
    case standard
    /// Radius 22, no shadow: the income and expense summaries.
    case compact

    var radius: CGFloat {
        switch self {
        case .hero: Radius.phoneCard
        case .standard: Radius.card
        case .compact: Radius.compactCard
        }
    }

    var isElevated: Bool { self != .compact }
}

extension View {
    func card(_ style: CardStyle = .standard) -> some View {
        modifier(CardModifier(style: style))
    }
}

private struct CardModifier: ViewModifier {

    let style: CardStyle
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: style.radius, style: .continuous)
        let shadowColor = Color(.textPrimary)
        let castsShadow = style.isElevated && colorScheme == .light
        content
            .background {
                // The shadow is cast by the background shape only, so text inside never gets one.
                // CSS blur radii (2 and 30) are twice SwiftUI's shadow radius.
                shape
                    .fill(Color(.surface))
                    .shadow(color: shadowColor.opacity(castsShadow ? 0.04 : 0), radius: 1, y: 1)
                    .shadow(color: shadowColor.opacity(castsShadow ? 0.06 : 0), radius: 15, y: 10)
            }
            .overlay {
                shape.strokeBorder(Color(.hairline), lineWidth: 1)
            }
            .clipShape(shape)
    }
}

// MARK: - Previews

private struct CardSpecimen: View {
    var body: some View {
        VStack(spacing: Spacing.stackDefault) {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: "Hero").textRole(.cardTitle)
                Text(verbatim: "Balance and budget ring cards").textRole(.meta).foregroundStyle(Color(.textSecondary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.cardPadding)
            .card(.hero)

            Text(verbatim: "Standard").textRole(.cardTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.cardPaddingCompact)
                .card(.standard)

            HStack(spacing: 12) {
                Text(verbatim: "Compact").textRole(.cardTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.cardPaddingCompact)
                    .card(.compact)
                Text(verbatim: "Compact").textRole(.cardTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.cardPaddingCompact)
                    .card(.compact)
            }
        }
        .foregroundStyle(Color(.textPrimary))
        .padding(Spacing.screenHorizontal)
        .frame(maxHeight: .infinity)
        .background(Color(.appBackground))
    }
}

#Preview("Light") {
    CardSpecimen().preferredColorScheme(.light)
}

#Preview("Dark") {
    CardSpecimen().preferredColorScheme(.dark)
}

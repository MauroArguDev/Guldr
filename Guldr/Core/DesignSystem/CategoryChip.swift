//
//  CategoryChip.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI

/// A category in the add sheet's 4-column grid: 62 pt tall, radius 14, symbol over a short name.
/// Selected: `GoldSoft` fill, 1.5 pt `GoldFill` border, `Gold` content (DESIGN.md › CategoryChip).
struct CategoryChip: View {

    let name: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .caption2) private var nameSize: CGFloat = 10.5
    @ScaledMetric(relativeTo: .caption2) private var glyphSize: CGFloat = Size.iconGlyphCompact
    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 62

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.categoryChip, style: .continuous)
        Button(action: action) {
            VStack(spacing: 4) {
                // Symbols differ in height; a fixed box keeps every name on the same baseline.
                Image(systemName: symbol)
                    .font(.system(size: glyphSize))
                    .frame(height: glyphSize + 4)
                Text(name)
                    .font(.system(size: nameSize, weight: .semibold))
                    .tracking(-0.1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color(.gold) : Color(.textPrimary))
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.horizontal, 2)
            .background(isSelected ? Color(.goldSoft) : Color(.field), in: shape)
            .overlay { shape.strokeBorder(isSelected ? Color(.goldFill) : .clear, lineWidth: 1.5) }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .motion(.snappy, value: isSelected)
        // Fires on the chip that becomes selected, once per change.
        .sensoryFeedback(Haptics.selection, trigger: isSelected) { _, selected in selected }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Previews

private struct CategoryChipSpecimen: View {

    @State private var selected = "food"
    private let categories = [("food", "Food", "fork.knife"), ("transport", "Transport", "car"),
                              ("housing", "Housing", "house"), ("health", "Health", "heart"),
                              ("shopping", "Shopping", "bag"), ("entertainment", "Entertainment", "play"),
                              ("education", "Education", "book"), ("other", "Other", "ellipsis.circle")]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(categories, id: \.0) { key, name, symbol in
                CategoryChip(name: name, symbol: symbol, isSelected: selected == key) { selected = key }
            }
        }
        .padding(Spacing.screenHorizontal)
        .frame(maxHeight: .infinity)
        .background(Color(.appBackground))
    }
}

#Preview("Light") {
    CategoryChipSpecimen().preferredColorScheme(.light)
}

#Preview("Dark") {
    CategoryChipSpecimen().preferredColorScheme(.dark)
}

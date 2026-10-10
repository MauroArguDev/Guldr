//
//  LedgerLines.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI

/// The brand motif from DESIGN.md › Brand motif: 1 pt `GoldFill` lines, as wide as their container.
/// Decorative, so hidden from VoiceOver.
struct LedgerLines: View {

    enum Variant {
        /// Under the balance: three lines, left-aligned.
        case leading
        /// Above the Face ID button: three lines, centered.
        case centered
        /// The small widget: two lines, closer together.
        case compact

        fileprivate var lines: [(width: CGFloat, opacity: Double)] {
            switch self {
            case .leading: [(1, 1), (0.78, 0.5), (0.56, 0.25)]
            case .centered: [(1, 0.6), (0.7, 0.35), (0.4, 0.18)]
            case .compact: [(1, 1), (0.7, 0.45)]
            }
        }

        fileprivate var gap: CGFloat { self == .compact ? 3 : 5 }
        fileprivate var anchor: UnitPoint { self == .centered ? .center : .leading }
    }

    let variant: Variant
    /// Draws the lines in once when they appear, left to right (from the center when centered).
    /// Only the Dashboard does this, once per launch; elsewhere the lines are static.
    var drawsIn = false

    @State private var drawn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // GeometryReader measures the space the lines were given (a card, a widget), not the screen.
        GeometryReader { proxy in
            VStack(alignment: variant == .centered ? .center : .leading, spacing: variant.gap) {
                ForEach(Array(variant.lines.enumerated()), id: \.offset) { index, line in
                    Rectangle()
                        .fill(Color(.goldFill))
                        .opacity(line.opacity)
                        .frame(width: proxy.size.width * line.width, height: 1)
                        .scaleEffect(x: isVisible ? 1 : 0, anchor: variant.anchor)
                        .motion(.reveal, value: drawn,
                                delay: Motion.staggerDelay(index: index, reduceMotion: reduceMotion))
                }
            }
            .frame(width: proxy.size.width, alignment: variant == .centered ? .center : .leading)
        }
        .frame(height: height)
        .accessibilityHidden(true)
        .onAppear { drawn = true }
    }

    /// 1 pt per line plus the gaps between them.
    private var height: CGFloat {
        let count = CGFloat(variant.lines.count)
        return count + (count - 1) * variant.gap
    }

    /// Static lines are always visible; drawn-in lines wait for the first appearance.
    private var isVisible: Bool { !drawsIn || drawn }
}

// MARK: - Previews

private struct LedgerLinesSpecimen: View {

    @State private var replay = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 12) {
                Text("$12,450").displayFont(.balance)
                LedgerLines(variant: .leading, drawsIn: true).id(replay)
            }
            LedgerLines(variant: .centered)
            VStack(alignment: .leading, spacing: 8) {
                Text("$12,480").displayFont(.widgetSmall)
                LedgerLines(variant: .compact)
            }
            .frame(width: 140)
            Button("Replay") { replay += 1 }
        }
        .foregroundStyle(Color(.textPrimary))
        .padding(Spacing.screenHorizontal)
        .frame(maxHeight: .infinity)
        .background(Color(.appBackground))
    }
}

#Preview("Light") {
    LedgerLinesSpecimen().preferredColorScheme(.light)
}

#Preview("Dark") {
    LedgerLinesSpecimen().preferredColorScheme(.dark)
}

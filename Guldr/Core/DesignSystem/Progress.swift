//
//  Progress.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI

/// How a progress indicator is colored. Over budget switches the fill to `Negative` (DESIGN.md ›
/// CategoryBudgetRow); everything else is `GoldFill` on `Track`.
enum ProgressTone {
    case standard
    case over

    var fill: Color { self == .over ? Color(.negative) : Color(.goldFill) }
}

/// A horizontal bar: savings rate, budget usage per category.
struct ProgressBar: View {

    enum Height {
        /// Dashboard and widgets: 6 pt.
        case regular
        /// Budget category rows: 5 pt.
        case compact

        var points: CGFloat { self == .regular ? Size.progressBarHeight : Size.progressBarHeightCompact }
    }

    /// 0…1; values above 1 are drawn full.
    let value: Double
    var height: Height = .regular
    var tone: ProgressTone = .standard

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.progressBar, style: .continuous)
        Entrance { revealed in
            GeometryReader { proxy in
                shape
                    .fill(tone.fill)
                    .frame(width: proxy.size.width * (revealed ? clamped : 0))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .motion(.reveal, value: revealed)
            .motion(.standard, value: clamped)
        }
        .frame(height: height.points)
        .background(Color(.track), in: shape)
        .clipShape(shape)
        .accessibilityElement()
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }

    private var clamped: Double { min(max(value, 0), 1) }
}

/// The 44 pt ring of the Dashboard's budget summary row: stroke 5, round caps, starts at 12 o'clock.
struct MiniRing: View {

    /// 0…1; values above 1 are drawn full.
    let value: Double
    var tone: ProgressTone = .standard

    var body: some View {
        RingShape(value: value, lineWidth: Size.miniRingStroke, tone: tone)
            .frame(width: Size.miniRing, height: Size.miniRing)
    }
}

/// A ring drawn inside its frame, so the stroke never spills over the edges. Shared with `BudgetRing`.
struct RingShape: View {

    let value: Double
    let lineWidth: CGFloat
    var tone: ProgressTone = .standard

    var body: some View {
        let inset = lineWidth / 2
        ZStack {
            Circle()
                .inset(by: inset)
                .stroke(Color(.track), lineWidth: lineWidth)
            Entrance { revealed in
                Circle()
                    .inset(by: inset)
                    .trim(from: 0, to: revealed ? clamped : 0)
                    .stroke(tone.fill, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .motion(.reveal, value: revealed)
                    .motion(.standard, value: clamped)
            }
        }
        .accessibilityElement()
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }

    private var clamped: Double { min(max(value, 0), 1) }
}

// MARK: - Previews

private struct ProgressSpecimen: View {

    @State private var value = 0.71
    @State private var replay = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ProgressBar(value: value)
            ProgressBar(value: 1.2, height: .compact, tone: .over)
            HStack(spacing: 20) {
                MiniRing(value: value)
                MiniRing(value: 1.2, tone: .over)
                RingShape(value: value, lineWidth: Size.budgetRingStroke)
                    .frame(width: 120, height: 120)
            }
            .id(replay)
            HStack {
                Button { value = value > 0.5 ? 0.3 : 0.71 } label: { Text(verbatim: "Change") }
                Button { replay += 1 } label: { Text(verbatim: "Replay") }
            }
        }
        .padding(Spacing.screenHorizontal)
        .frame(maxHeight: .infinity)
        .background(Color(.appBackground))
    }
}

#Preview("Light") {
    ProgressSpecimen().preferredColorScheme(.light)
}

#Preview("Dark") {
    ProgressSpecimen().preferredColorScheme(.dark)
}

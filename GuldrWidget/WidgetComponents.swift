//
//  WidgetComponents.swift
//  GuldrWidget
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import GuldrCore
import SwiftUI
import WidgetKit

/// The icon's glyph as a stroke, so it takes `Gold` and follows the tinted home screen. Its path is
/// the Widgets mockup's on the 1024 grid: a 250-unit arc open at the top right, then the bar to the
/// center line (DESIGN.md › App icon).
struct GlyphMark: View {

    var body: some View {
        GeometryReader { proxy in
            GlyphShape()
                .stroke(Color(.gold), lineWidth: proxy.size.width * 110 / 1024)
        }
        .widgetAccentable()
        .accessibilityHidden(true)
    }
}

/// The arc goes from the opening (703.5, 351.3) the long way round to (762, 512), then straight to
/// (548, 512). Drawn with points instead of `addArc`, whose direction flips with the coordinate system.
nonisolated private struct GlyphShape: Shape {

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 1024
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }
        let start = atan2(351.3 - 512, 703.5 - 512)  // about −40°
        let sweep = 2 * CGFloat.pi + start             // back to 0°, counterclockwise on screen
        var path = Path()
        let steps = 72
        for step in 0...steps {
            let angle = start - sweep * CGFloat(step) / CGFloat(steps)
            let next = point(512 + 250 * cos(angle), 512 + 250 * sin(angle))
            if step == 0 { path.move(to: next) } else { path.addLine(to: next) }
        }
        path.addLine(to: point(548, 512))
        return path
    }
}

/// The small widget's two ledger lines under the balance: 1 pt `GoldFill`, the second at 70 % width and
/// 45 % opacity, 3 pt apart (DESIGN.md › Motif lines, compact).
struct WidgetLedgerLines: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Rectangle().fill(Color(.goldFill)).frame(height: 1)
            GeometryReader { proxy in
                Rectangle().fill(Color(.goldFill)).frame(width: proxy.size.width * 0.7, height: 1)
            }
            .frame(height: 1)
            .opacity(0.45)
        }
        .widgetAccentable()
        .accessibilityHidden(true)
    }
}

/// An amount the widget hides when asked (ADR 011 and Settings) and iOS hides on a locked iPhone.
struct WidgetAmount: View {

    let text: String
    let hidesAmounts: Bool

    var body: some View {
        Text(verbatim: text)
            .monospacedDigit()
            .privacySensitive()
            .redacted(reason: hidesAmounts ? .privacy : [])
    }
}

/// "Balance" with the glyph, as both widgets' header.
struct WidgetHeader: View {

    var glyphSize: CGFloat = 18
    var glyphLeading = false

    var body: some View {
        HStack(spacing: 6) {
            if glyphLeading { GlyphMark().frame(width: glyphSize, height: glyphSize) }
            Text("Balance")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(.textSecondary))
            if !glyphLeading {
                Spacer(minLength: 4)
                GlyphMark().frame(width: glyphSize, height: glyphSize)
            }
        }
    }
}

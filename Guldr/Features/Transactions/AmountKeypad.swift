//
//  AmountKeypad.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 15/10/26.
//

import SwiftUI

/// The add sheet's 3 × 4 keypad: digits, the locale's decimal separator and delete (DESIGN.md › Add
/// sheet). Each action returns whether the key was accepted; only accepted keys play the light impact.
struct AmountKeypad: View {

    let acceptsDecimals: Bool
    let onDigit: (Int) -> Bool
    let onDecimalSeparator: () -> Bool
    let onDelete: () -> Bool

    @Environment(\.locale) private var locale
    @State private var acceptedPresses = 0

    private enum Key: Hashable {
        case digit(Int)
        case decimalSeparator
        case delete
    }

    private let keys: [Key] = (1...9).map(Key.digit) + [.decimalSeparator, .digit(0), .delete]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.gridGap), count: 3),
                  spacing: Spacing.gridGap) {
            ForEach(keys, id: \.self) { key in
                Button {
                    if press(key) { acceptedPresses += 1 }
                } label: {
                    label(for: key)
                }
                .buttonStyle(KeypadKeyStyle())
                .disabled(key == .decimalSeparator && !acceptsDecimals)
            }
        }
        // Keys keep their 50 pt height (above the 44 pt minimum) and their digits stop growing at the
        // first accessibility size, so the keypad never pushes the amount off screen.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .sensoryFeedback(Haptics.keypadKey, trigger: acceptedPresses)
    }

    private func press(_ key: Key) -> Bool {
        switch key {
        case .digit(let digit): onDigit(digit)
        case .decimalSeparator: onDecimalSeparator()
        case .delete: onDelete()
        }
    }

    @ViewBuilder
    private func label(for key: Key) -> some View {
        switch key {
        case .digit(let digit):
            Text(verbatim: digit.formatted(.number.locale(locale)))
        case .decimalSeparator:
            Text(verbatim: locale.decimalSeparator ?? ".")
                .accessibilityLabel(Text("Decimal point"))
        case .delete:
            Image(systemName: "delete.left")
                .accessibilityLabel(Text("Delete"))
        }
    }
}

private struct KeypadKeyStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 24))
            .foregroundStyle(Color(.textPrimary))
            .frame(maxWidth: .infinity, minHeight: Size.keypadKey)
            .background(Color(.keypadKey), in: .rect(cornerRadius: Radius.keypadKey, style: .continuous))
            .contentShape(.rect(cornerRadius: Radius.keypadKey, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
            .motion(.snappy, value: configuration.isPressed)
    }
}

#Preview("Light") {
    AmountKeypad(acceptsDecimals: true, onDigit: { _ in true }, onDecimalSeparator: { true }, onDelete: { true })
        .padding()
        .background(Color(.sheetBackground))
        .preferredColorScheme(.light)
}

#Preview("Dark, no decimals") {
    AmountKeypad(acceptsDecimals: false, onDigit: { _ in true }, onDecimalSeparator: { false }, onDelete: { true })
        .padding()
        .background(Color(.sheetBackground))
        .preferredColorScheme(.dark)
}

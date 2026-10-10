//
//  PrimaryButton.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI

/// The primary action: a 54 pt `GoldFill` capsule with 17 pt semibold `OnGold` text (DESIGN.md ›
/// Primary button). It grows with Dynamic Type instead of clipping.
struct PrimaryButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 54

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)                                     // 17 pt semibold
            .foregroundStyle(Color(.onGold))
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.horizontal, Spacing.screenHorizontal)
            .background(Color(.goldFill), in: Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .motion(.snappy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

// MARK: - Previews

private struct PrimaryButtonSpecimen: View {

    @State private var saves = 0

    var body: some View {
        VStack(spacing: 16) {
            Button("Save") { saves += 1 }
                .buttonStyle(.primary)
                // The success haptic belongs to the save itself; a screen triggers it after a real save.
                .sensoryFeedback(Haptics.saved, trigger: saves)
            Button("Unlock with Face ID") {}
                .buttonStyle(.primary)
            Button("Save") {}
                .buttonStyle(.primary)
                .disabled(true)
        }
        .padding(Spacing.screenHorizontal)
        .frame(maxHeight: .infinity)
        .background(Color(.appBackground))
    }
}

#Preview("Light") {
    PrimaryButtonSpecimen().preferredColorScheme(.light)
}

#Preview("Dark") {
    PrimaryButtonSpecimen().preferredColorScheme(.dark)
}

#Preview("Largest Dynamic Type") {
    PrimaryButtonSpecimen().dynamicTypeSize(.accessibility5)
}

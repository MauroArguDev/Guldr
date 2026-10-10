//
//  Motion.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI
import UIKit

/// The animation tokens from DESIGN.md › Motion. Every animation in the app goes through here, so
/// Reduce Motion is handled in one place.
enum Motion {
    /// Layout and value changes.
    case standard
    /// Direct manipulation: chips, keypad, segmented controls, toggles.
    case snappy
    /// Success moments only.
    case emphasized
    /// First appearance of fills: bars, rings, the ledger lines.
    case reveal

    var animation: Animation {
        switch self {
        case .standard: .smooth(duration: 0.35)
        case .snappy: .snappy(duration: 0.25)
        case .emphasized: .spring(duration: 0.45, bounce: 0.15)
        case .reveal: .smooth(duration: 0.6)
        }
    }

    /// What Reduce Motion uses instead of movement.
    static let crossFade: Animation = .easeInOut(duration: 0.2)

    /// The animation to run. With Reduce Motion, fills appear at their final value (`nil`) and
    /// everything else becomes a short cross-fade.
    func resolved(reduceMotion: Bool) -> Animation? {
        guard reduceMotion else { return animation }
        return self == .reveal ? nil : Self.crossFade
    }

    // MARK: - Stagger

    static let staggerStep: Double = 0.04
    static let staggerMaxTotal: Double = 0.25

    /// Delay for the item at `index` in an entrance: 0.04 s apart, capped at 0.25 s so long lists
    /// never wait. Zero with Reduce Motion.
    static func staggerDelay(index: Int, reduceMotion: Bool) -> Double {
        guard !reduceMotion else { return 0 }
        return min(Double(max(0, index)) * staggerStep, staggerMaxTotal)
    }
}

/// `withAnimation` through a Motion token, for state changes made in actions (a button tap, a save).
/// Views use `.motion(_:value:)` instead, which reads Reduce Motion from the environment.
func withMotion<Result>(_ motion: Motion, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(motion.resolved(reduceMotion: UIAccessibility.isReduceMotionEnabled), body)
}

extension View {
    /// `.animation(_:value:)` through a Motion token. `delay` staggers entrances; use
    /// `Motion.staggerDelay(index:reduceMotion:)` for it.
    func motion(_ motion: Motion, value: some Equatable, delay: Double = 0) -> some View {
        modifier(MotionModifier(motion: motion, value: value, delay: delay))
    }

    /// A transition that becomes a plain cross-fade with Reduce Motion.
    func motionTransition(_ transition: AnyTransition) -> some View {
        modifier(MotionTransitionModifier(transition: transition))
    }
}

/// Whether motion should be reduced: the system's Reduce Motion setting, or the design system
/// gallery's simulation of it. Components read this instead of `accessibilityReduceMotion`, which
/// SwiftUI does not let a view override.
@propertyWrapper
struct ReduceMotion: DynamicProperty {

    @Environment(\.accessibilityReduceMotion) private var system
    @Environment(\.simulatesReduceMotion) private var simulated

    var wrappedValue: Bool { system || simulated }
}

extension EnvironmentValues {
    /// Set by the design system gallery to preview Reduce Motion without changing the device setting.
    @Entry var simulatesReduceMotion = false
    /// Changing it replays every `Entrance` below it (the design system gallery's "Replay").
    @Entry var entranceReplay = 0
}

/// Runs an entrance: `content` first renders with `revealed == false`, then with `true` once it
/// appears; the content animates that change with `.motion(.reveal, value:)`.
///
/// When `entranceReplay` changes, only this content is recreated, so it starts over from `false`.
/// Resetting a flag and setting it again would land in the same frame and never show the empty state.
/// The content must sit in a fixed-size frame (a bar's height, a ring's frame), so recreating it never
/// changes the layout around it.
struct Entrance<Content: View>: View {

    @ViewBuilder let content: (_ revealed: Bool) -> Content
    @Environment(\.entranceReplay) private var replay

    var body: some View {
        EntranceInstance(content: content).id(replay)
    }
}

private struct EntranceInstance<Content: View>: View {

    let content: (Bool) -> Content
    @State private var revealed = false

    var body: some View {
        content(revealed).onAppear { revealed = true }
    }
}

/// The haptics from DESIGN.md › Motion, for `.sensoryFeedback(_:trigger:)`. They stay on with
/// Reduce Motion: they do not move anything on screen.
enum Haptics {
    /// A category chip or segmented control changes.
    static let selection: SensoryFeedback = .selection
    static let keypadKey: SensoryFeedback = .impact(weight: .light)
    /// A transaction or budget was saved.
    static let saved: SensoryFeedback = .success
    /// A save pushed a budget over its limit.
    static let budgetExceeded: SensoryFeedback = .warning
    static let unlockFailed: SensoryFeedback = .error
}

// MARK: - Modifiers

private struct MotionModifier<Value: Equatable>: ViewModifier {

    let motion: Motion
    let value: Value
    let delay: Double
    @ReduceMotion private var reduceMotion

    func body(content: Content) -> some View {
        let animation = motion.resolved(reduceMotion: reduceMotion)
        content.animation(delay > 0 && !reduceMotion ? animation?.delay(delay) : animation, value: value)
    }
}

private struct MotionTransitionModifier: ViewModifier {

    let transition: AnyTransition
    @ReduceMotion private var reduceMotion

    func body(content: Content) -> some View {
        content.transition(reduceMotion ? .opacity : transition)
    }
}

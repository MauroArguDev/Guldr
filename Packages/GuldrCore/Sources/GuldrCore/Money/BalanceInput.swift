//
//  BalanceInput.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 1/11/26.
//

import Foundation

/// The keypad's amount on the starting balance screens (ADR 016): an `AmountInput` that can start from
/// today's balance. Like a selected text field, the first key replaces a prefilled amount instead of
/// appending to it, and delete clears it.
public struct BalanceInput: Equatable, Sendable {

    public private(set) var amount: AmountInput
    /// A prefilled amount the user hasn't touched yet.
    public private(set) var isPrefilled: Bool

    /// Empty, as in onboarding.
    public init(currencyCode: String) throws(MoneyError) {
        amount = try AmountInput(currencyCode: currencyCode)
        isPrefilled = false
    }

    /// Starts from `money`; zero starts empty, with nothing to replace.
    public init(prefilled money: Money) throws(MoneyError) {
        amount = try AmountInput(money: money)
        isPrefilled = !amount.isEmpty
    }

    /// Each returns whether the key did something, so the keypad can skip the haptic for a rejected one.
    @discardableResult
    public mutating func pressDigit(_ digit: Int) -> Bool {
        let cleared = clearPrefill()
        return amount.appendDigit(digit) || cleared
    }

    @discardableResult
    public mutating func pressDecimalSeparator() -> Bool {
        let cleared = clearPrefill()
        return amount.appendDecimalSeparator() || cleared
    }

    @discardableResult
    public mutating func pressDelete() -> Bool {
        if clearPrefill() { return true }
        return amount.deleteBackward()
    }

    // MARK: - Private

    private mutating func clearPrefill() -> Bool {
        guard isPrefilled else { return false }
        amount.clear()
        isPrefilled = false
        return true
    }
}

//
//  AmountInput.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 8/10/26.
//

import Foundation

/// The state of the custom keypad in the add-transaction sheet.
///
/// It keeps what the user typed (integer digits and, after the decimal key, up to the currency's
/// minor-unit digits) and turns it into exact minor units. Every edit returns whether it was accepted,
/// so the UI can give feedback when a key does nothing.
public struct AmountInput: Equatable, Sendable {

    /// Upper bound for the integer part; keeps amounts far below the `Int64` limit.
    public static let maxIntegerDigits = 10

    public let currencyCode: String
    public let fractionDigitLimit: Int
    public private(set) var integerDigits = ""
    /// `nil` until the decimal key is pressed; then the typed fraction digits (possibly empty).
    public private(set) var fractionDigits: String?

    public init(currencyCode: String) throws(MoneyError) {
        self.currencyCode = try Currency.validatedCode(currencyCode)
        self.fractionDigitLimit = try Currency.minorUnitDigits(for: self.currencyCode)
    }

    /// Prefills the keypad from an existing amount (edit mode), dropping trailing fraction zeros.
    public init(money: Money) throws(MoneyError) {
        try self.init(currencyCode: money.currencyCode)
        let magnitude = String(money.minorUnits.magnitude)
        let padded = String(repeating: "0", count: max(0, fractionDigitLimit + 1 - magnitude.count)) + magnitude
        let integerPart = String(padded.dropLast(fractionDigitLimit))
        let fractionPart = String(padded.suffix(fractionDigitLimit)).replacing(/0+$/, with: "")
        integerDigits = integerPart == "0" ? "" : integerPart
        fractionDigits = fractionPart.isEmpty ? nil : fractionPart
    }

    public var isEmpty: Bool { integerDigits.isEmpty && (fractionDigits ?? "").isEmpty }

    /// Appends a digit from 0 to 9. Leading zeros are ignored; limits are enforced.
    @discardableResult
    public mutating func appendDigit(_ digit: Int) -> Bool {
        guard (0...9).contains(digit) else { return false }
        if let fraction = fractionDigits {
            guard fraction.count < fractionDigitLimit else { return false }
            fractionDigits = fraction + String(digit)
            return true
        }
        if integerDigits.isEmpty && digit == 0 { return false }
        guard integerDigits.count < Self.maxIntegerDigits else { return false }
        integerDigits += String(digit)
        return true
    }

    /// Starts the fraction part. Rejected for currencies without minor units or when already typed.
    @discardableResult
    public mutating func appendDecimalSeparator() -> Bool {
        guard fractionDigitLimit > 0, fractionDigits == nil else { return false }
        fractionDigits = ""
        return true
    }

    /// Removes the last typed character (a fraction digit, the separator or an integer digit).
    @discardableResult
    public mutating func deleteBackward() -> Bool {
        if let fraction = fractionDigits {
            fractionDigits = fraction.isEmpty ? nil : String(fraction.dropLast())
            return true
        }
        guard !integerDigits.isEmpty else { return false }
        integerDigits.removeLast()
        return true
    }

    public mutating func clear() {
        integerDigits = ""
        fractionDigits = nil
    }

    /// Exact minor units for what was typed: "12.5" in USD is 1250.
    public var minorUnits: Int64 {
        let fraction = (fractionDigits ?? "").padding(toLength: fractionDigitLimit, withPad: "0", startingAt: 0)
        return Int64((integerDigits.isEmpty ? "0" : integerDigits) + fraction) ?? 0
    }

    /// The typed amount. `currencyCode` was validated in `init`, so no error is possible here.
    public var money: Money {
        Money.unchecked(minorUnits, currencyCode)
    }

    /// What the keypad shows, without the currency symbol: "1,234.5" in en-US, "1.234,5" in es-ES.
    /// The typed fraction is kept as typed so the user sees each key press.
    public func displayText(locale: Locale) -> String {
        let integerValue = Int64(integerDigits) ?? 0
        let integerText = integerValue.formatted(.number.grouping(.automatic).locale(locale))
        guard let fraction = fractionDigits else { return integerText }
        return integerText + (locale.decimalSeparator ?? ".") + fraction
    }
}

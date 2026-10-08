//
//  Money.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 8/10/26.
//

import Foundation

/// An exact amount of money: integer minor units plus an ISO 4217 currency code (ADR 005).
///
/// `$12.34` is `Money(minorUnits: 1234, currencyCode: "USD")`. Arithmetic is only defined between
/// amounts in the same currency. `Decimal` appears only when converting to and from text.
public struct Money: Hashable, Sendable, Codable {

    public let minorUnits: Int64
    public let currencyCode: String

    /// Creates an amount from minor units. The code is validated and uppercased.
    public init(minorUnits: Int64, currencyCode: String) throws(MoneyError) {
        self.minorUnits = minorUnits
        self.currencyCode = try Currency.validatedCode(currencyCode)
    }

    /// Creates an amount from a decimal value, rounding half away from zero to the currency's minor unit.
    public init(_ value: Decimal, currencyCode: String) throws(MoneyError) {
        let code = try Currency.validatedCode(currencyCode)
        let digits = try Currency.minorUnitDigits(for: code)
        var scaled = value * Self.powerOfTen(digits)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        guard rounded >= Decimal(Int64.min), rounded <= Decimal(Int64.max) else {
            throw .overflow
        }
        self.minorUnits = NSDecimalNumber(decimal: rounded).int64Value
        self.currencyCode = code
    }

    /// Zero in the given currency.
    public static func zero(_ currencyCode: String) throws(MoneyError) -> Money {
        try Money(minorUnits: 0, currencyCode: currencyCode)
    }

    public var isZero: Bool { minorUnits == 0 }
    public var isNegative: Bool { minorUnits < 0 }

    /// The exact decimal value, e.g. `12.34` for 1234 minor units of USD.
    public var decimalValue: Decimal {
        let digits = (try? Currency.minorUnitDigits(for: currencyCode)) ?? 2
        let sign: FloatingPointSign = minorUnits < 0 ? .minus : .plus
        return Decimal(sign: sign, exponent: -digits, significand: Decimal(minorUnits.magnitude))
    }

    public func adding(_ other: Money) throws(MoneyError) -> Money {
        try ensureSameCurrency(as: other)
        let (result, overflow) = minorUnits.addingReportingOverflow(other.minorUnits)
        guard !overflow else { throw .overflow }
        return Money(unchecked: result, currencyCode)
    }

    public func subtracting(_ other: Money) throws(MoneyError) -> Money {
        try ensureSameCurrency(as: other)
        let (result, overflow) = minorUnits.subtractingReportingOverflow(other.minorUnits)
        guard !overflow else { throw .overflow }
        return Money(unchecked: result, currencyCode)
    }

    public func negated() throws(MoneyError) -> Money {
        let (result, overflow) = Int64(0).subtractingReportingOverflow(minorUnits)
        guard !overflow else { throw .overflow }
        return Money(unchecked: result, currencyCode)
    }

    /// Sums amounts that all share `currencyCode`. Throws on a mismatch or overflow.
    public static func sum(_ amounts: some Sequence<Money>, currencyCode: String) throws(MoneyError) -> Money {
        var total = try Money.zero(currencyCode)
        for amount in amounts {
            total = try total.adding(amount)
        }
        return total
    }

    // MARK: - Private

    /// Used only after the code was validated by an existing value.
    private init(unchecked minorUnits: Int64, _ currencyCode: String) {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode
    }

    /// Internal escape hatch for callers that already validated `currencyCode`.
    static func unchecked(_ minorUnits: Int64, _ currencyCode: String) -> Money {
        Money(unchecked: minorUnits, currencyCode)
    }

    private func ensureSameCurrency(as other: Money) throws(MoneyError) {
        guard currencyCode == other.currencyCode else {
            throw .currencyMismatch(currencyCode, other.currencyCode)
        }
    }

    private static func powerOfTen(_ exponent: Int) -> Decimal {
        Decimal(sign: .plus, exponent: exponent, significand: 1)
    }
}

extension Money {
    private enum CodingKeys: String, CodingKey {
        case minorUnits, currencyCode
    }

    /// Decoding goes through the validating initializer, so stored data can't create an invalid currency.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            minorUnits: container.decode(Int64.self, forKey: .minorUnits),
            currencyCode: container.decode(String.self, forKey: .currencyCode)
        )
    }
}

extension Money: CustomStringConvertible {
    /// Debug-friendly description, e.g. `12.34 USD`. Use `MoneyFormatter` for user-facing text.
    public var description: String { "\(decimalValue) \(currencyCode)" }
}

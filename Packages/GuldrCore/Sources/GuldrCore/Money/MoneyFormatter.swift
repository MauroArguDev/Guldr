//
//  MoneyFormatter.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 8/10/26.
//

import Foundation

/// User-facing text for `Money`, following the locale and the design system's sign rules:
/// income shows "+", expenses and negative balances show a true minus "−" (U+2212), as in the mockups.
public struct MoneyFormatter: Sendable {

    /// How the sign of an amount is shown.
    public enum SignDisplay: Sendable {
        /// "−" only when the amount is negative (balances).
        case automatic
        /// Always "+" (income rows).
        case plus
        /// Always "−" (expense rows), even though expenses are stored as positive amounts.
        case minus
        /// Never a sign (labels such as "of $2,030.00").
        case never
    }

    /// How many decimals are shown.
    public enum Precision: Sendable {
        /// Every minor unit: "$1,759.50". Rows, forms, anything the user reconciles.
        case full
        /// Rounded to whole units, halves away from zero: "$1,760". Large summary figures where cents
        /// are noise: the budget ring, chart totals, the donut center, widgets.
        case wholeUnits
    }

    /// A formatted amount split around the decimal separator, for the serif balance where cents are smaller.
    public struct Parts: Equatable, Sendable {
        /// Sign, symbol and integer part, e.g. "$12,450" or "−12.450".
        public let main: String
        /// Separator, minor units and any trailing symbol, e.g. ".80" or ",80 €". `nil` for JPY-like currencies.
        public let fraction: String?
    }

    public static let minusSign = "\u{2212}"

    public let locale: Locale

    public init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
    }

    /// The amount, e.g. "$1,234.50", "+$5,000.00", "−$42.80", "12.345,67 €", or "$1,235" in whole units.
    public func string(from money: Money, sign: SignDisplay = .automatic, precision: Precision = .full) -> String {
        let magnitude = formattedMagnitude(of: money, precision: precision)
        // An amount that rounds to zero shows no sign: "$0", never "−$0".
        let showsZero = precision == .wholeUnits && wholeUnits(of: money) == 0
        return (showsZero ? "" : signPrefix(for: money, sign: sign)) + magnitude
    }

    /// The amount split for the large balance: main "$12,450" and fraction ".80".
    public func parts(from money: Money, sign: SignDisplay = .automatic) -> Parts {
        let magnitude = formattedMagnitude(of: money, precision: .full)
        let prefix = signPrefix(for: money, sign: sign)
        let digits = (try? Currency.minorUnitDigits(for: money.currencyCode)) ?? 2
        guard digits > 0,
              let separator = locale.decimalSeparator,
              let range = magnitude.range(of: separator, options: .backwards) else {
            return Parts(main: prefix + magnitude, fraction: nil)
        }
        return Parts(
            main: prefix + magnitude[..<range.lowerBound],
            fraction: String(magnitude[range.lowerBound...])
        )
    }

    // MARK: - Private

    private func signPrefix(for money: Money, sign: SignDisplay) -> String {
        switch sign {
        case .automatic: money.isNegative ? Self.minusSign : ""
        case .plus: money.isZero ? "" : "+"
        case .minus: money.isZero ? "" : Self.minusSign
        case .never: ""
        }
    }

    /// Formats the absolute value; the sign is added separately so every locale uses the same signs.
    private func formattedMagnitude(of money: Money, precision: Precision) -> String {
        let digits = (try? Currency.minorUnitDigits(for: money.currencyCode)) ?? 2
        let magnitude = Decimal(sign: .plus, exponent: -digits, significand: Decimal(money.minorUnits.magnitude))
        let style = Decimal.FormatStyle.Currency(code: money.currencyCode).locale(locale)
        switch precision {
        case .full:
            return magnitude.formatted(style.precision(.fractionLength(digits)))
        case .wholeUnits:
            // The default rounding is half-to-even ($12,874.50 → $12,874); money reads half-up.
            return magnitude.formatted(style.precision(.fractionLength(0)).rounded(rule: .toNearestOrAwayFromZero))
        }
    }

    /// The magnitude rounded to whole units, halves away from zero.
    private func wholeUnits(of money: Money) -> Decimal {
        let digits = (try? Currency.minorUnitDigits(for: money.currencyCode)) ?? 2
        var value = Decimal(sign: .plus, exponent: -digits, significand: Decimal(money.minorUnits.magnitude))
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return rounded
    }
}

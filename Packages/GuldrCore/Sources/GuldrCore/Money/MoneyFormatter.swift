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

    /// The full amount, e.g. "$1,234.50", "+$5,000.00", "−$42.80", "12.345,67 €".
    public func string(from money: Money, sign: SignDisplay = .automatic) -> String {
        signPrefix(for: money, sign: sign) + formattedMagnitude(of: money)
    }

    /// The amount split for the large balance: main "$12,450" and fraction ".80".
    public func parts(from money: Money, sign: SignDisplay = .automatic) -> Parts {
        let magnitude = formattedMagnitude(of: money)
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
    private func formattedMagnitude(of money: Money) -> String {
        let digits = (try? Currency.minorUnitDigits(for: money.currencyCode)) ?? 2
        let magnitude = Decimal(sign: .plus, exponent: -digits, significand: Decimal(money.minorUnits.magnitude))
        return magnitude.formatted(
            .currency(code: money.currencyCode)
                .locale(locale)
                .precision(.fractionLength(digits))
        )
    }
}

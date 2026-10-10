//
//  Currency.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 8/10/26.
//

import Foundation
import Synchronization

/// ISO 4217 currency metadata, read from Foundation instead of a hard-coded table (ADR 005).
public enum Currency {

    /// Number of minor-unit digits for a currency: 2 for USD, 0 for JPY, 3 for KWD.
    public static func minorUnitDigits(for code: String) throws(MoneyError) -> Int {
        let code = try validatedCode(code)
        if let cached = digitsCache.withLock({ $0[code] }) {
            return cached
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        let digits = formatter.maximumFractionDigits
        digitsCache.withLock { $0[code] = digits }
        return digits
    }

    /// Uppercases and checks the code against the system's list of ISO 4217 currencies.
    public static func validatedCode(_ code: String) throws(MoneyError) -> String {
        let uppercased = code.uppercased()
        guard knownCodes.contains(uppercased) else {
            throw .unknownCurrency(code)
        }
        return uppercased
    }

    /// The currency of a locale, used as the default active currency at first launch. US dollars when the
    /// locale has no region (`en`, `es_419`) or its currency is not one the system lists.
    public static func defaultCode(for locale: Locale) -> String {
        guard let identifier = locale.currency?.identifier,
              let code = try? validatedCode(identifier) else { return "USD" }
        return code
    }

    private static let knownCodes = Set(Locale.commonISOCurrencyCodes)

    // NumberFormatter is relatively expensive to create; the digits never change at runtime.
    private static let digitsCache = Mutex<[String: Int]>([:])
}

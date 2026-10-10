//
//  CurrencyOption.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation

/// A row in the currency picker: the ISO code, its name and symbol in the user's language.
public struct CurrencyOption: Identifiable, Hashable, Sendable {

    public let code: String
    public let name: String
    public let symbol: String

    public var id: String { code }

    /// Every currency the system knows, named in `locale`'s language and sorted by name.
    public static func all(locale: Locale = .autoupdatingCurrent) -> [CurrencyOption] {
        Locale.commonISOCurrencyCodes
            .map { option(for: $0, locale: locale) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public static func option(for code: String, locale: Locale = .autoupdatingCurrent) -> CurrencyOption {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = code
        return CurrencyOption(code: code,
                              name: locale.localizedString(forCurrencyCode: code) ?? code,
                              symbol: formatter.currencySymbol ?? code)
    }

    /// Search by name, code or symbol, ignoring case and diacritics ("euro", "eur", "€", "colon" finds
    /// "colón"). An empty or blank query matches everything.
    public func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return [name, code, symbol].contains { $0.range(of: query, options: options) != nil }
    }
}

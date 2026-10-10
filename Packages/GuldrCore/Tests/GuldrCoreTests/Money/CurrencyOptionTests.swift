//
//  CurrencyOptionTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation
import Testing
@testable import GuldrCore

struct CurrencyOptionTests {

    private let spanish = Locale(identifier: "es_ES")

    @Test func listsEveryKnownCurrencyOnceSortedByName() {
        let options = CurrencyOption.all(locale: Locale(identifier: "en_US"))
        #expect(options.count == Set(Locale.commonISOCurrencyCodes).count)
        #expect(Set(options.map(\.code)).count == options.count)
        let names = options.map(\.name)
        #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    @Test func namesAndSymbolsFollowTheLocale() {
        let euro = CurrencyOption.option(for: "EUR", locale: spanish)
        #expect(euro.name == "euro")
        #expect(euro.symbol == "€")
        #expect(CurrencyOption.option(for: "USD", locale: spanish).symbol == "US$")
    }

    @Test(arguments: ["colon", "COLÓN", "crc", "  costarricense "])
    func searchIgnoresCaseAccentsAndSpaces(query: String) {
        #expect(CurrencyOption.option(for: "CRC", locale: spanish).matches(query))
    }

    @Test func searchMatchesTheSymbol() {
        #expect(CurrencyOption.option(for: "EUR", locale: spanish).matches("€"))
    }

    @Test(arguments: ["", "   "])
    func blankQueryMatchesEverything(query: String) {
        #expect(CurrencyOption.option(for: "JPY", locale: spanish).matches(query))
    }

    @Test func unrelatedQueryDoesNotMatch() {
        #expect(!CurrencyOption.option(for: "JPY", locale: spanish).matches("dólar"))
    }
}

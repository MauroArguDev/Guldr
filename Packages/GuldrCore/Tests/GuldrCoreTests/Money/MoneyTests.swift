//
//  MoneyTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 8/10/26.
//

import Foundation
import Testing
@testable import GuldrCore

struct CurrencyTests {

    @Test(arguments: [("USD", 2), ("MXN", 2), ("EUR", 2), ("JPY", 0), ("KWD", 3)])
    func minorUnitDigits(code: String, digits: Int) throws {
        #expect(try Currency.minorUnitDigits(for: code) == digits)
    }

    @Test func codesAreUppercased() throws {
        #expect(try Currency.validatedCode("mxn") == "MXN")
    }

    @Test func unknownCodeThrows() {
        #expect(throws: MoneyError.unknownCurrency("XYZ")) {
            try Currency.validatedCode("XYZ")
        }
    }

    @Test func defaultCodeComesFromTheLocale() {
        #expect(Currency.defaultCode(for: Locale(identifier: "es_MX")) == "MXN")
        #expect(Currency.defaultCode(for: Locale(identifier: "en_US")) == "USD")
    }

    @Test func defaultCodeFollowsACurrencyOverride() {
        #expect(Currency.defaultCode(for: Locale(identifier: "en_US@currency=EUR")) == "EUR")
    }

    @Test(arguments: ["en", "es_419"])
    func defaultCodeFallsBackToDollarsWithoutARegion(identifier: String) {
        #expect(Currency.defaultCode(for: Locale(identifier: identifier)) == "USD")
    }
}

struct MoneyTests {

    @Test func storesMinorUnitsAndUppercasedCode() throws {
        let money = try Money(minorUnits: 1234, currencyCode: "usd")
        #expect(money.minorUnits == 1234)
        #expect(money.currencyCode == "USD")
        #expect(money.decimalValue == Decimal(string: "12.34"))
    }

    @Test(arguments: [
        ("12.34", "USD", Int64(1234)),
        ("12.345", "USD", 1235),      // half away from zero
        ("-12.345", "USD", -1235),
        ("0.1", "USD", 10),
        ("1500", "JPY", 1500),
        ("1500.5", "JPY", 1501),
        ("1.2345", "KWD", 1235)
    ])
    func decimalInitRoundsToMinorUnits(value: String, code: String, expected: Int64) throws {
        let decimal = try #require(Decimal(string: value))
        #expect(try Money(decimal, currencyCode: code).minorUnits == expected)
    }

    @Test func decimalArithmeticIsExact() throws {
        // 0.1 + 0.2 is not 0.3 in Double; it must be in Money.
        let sum = try Money(Decimal(string: "0.1")!, currencyCode: "USD")
            .adding(Money(Decimal(string: "0.2")!, currencyCode: "USD"))
        #expect(sum == (try Money(Decimal(string: "0.3")!, currencyCode: "USD")))
    }

    @Test func addingAndSubtracting() throws {
        let ten = try Money(minorUnits: 1000, currencyCode: "USD")
        let three = try Money(minorUnits: 300, currencyCode: "USD")
        #expect(try ten.adding(three).minorUnits == 1300)
        #expect(try three.subtracting(ten).minorUnits == -700)
        #expect(try three.subtracting(ten).isNegative)
        #expect(try ten.negated().minorUnits == -1000)
    }

    @Test func mixingCurrenciesThrows() throws {
        let dollars = try Money(minorUnits: 100, currencyCode: "USD")
        let pesos = try Money(minorUnits: 100, currencyCode: "MXN")
        #expect(throws: MoneyError.currencyMismatch("USD", "MXN")) {
            try dollars.adding(pesos)
        }
    }

    @Test func overflowThrowsInsteadOfTrapping() throws {
        let max = try Money(minorUnits: .max, currencyCode: "USD")
        let one = try Money(minorUnits: 1, currencyCode: "USD")
        #expect(throws: MoneyError.overflow) { try max.adding(one) }
        #expect(throws: MoneyError.overflow) { try Money(minorUnits: .min, currencyCode: "USD").negated() }
        #expect(throws: MoneyError.overflow) { try Money(Decimal(string: "1e30")!, currencyCode: "USD") }
    }

    @Test func sumOfManyAmounts() throws {
        let amounts = try (1...1_000).map { try Money(minorUnits: Int64($0), currencyCode: "USD") }
        #expect(try Money.sum(amounts, currencyCode: "USD").minorUnits == 500_500)
        #expect(try Money.sum([], currencyCode: "USD").isZero)
    }

    @Test func veryLargeAmountsKeepTheirValue() throws {
        let value = try #require(Decimal(string: "92233720368547758.07"))
        #expect(try Money(value, currencyCode: "USD").minorUnits == .max)
    }

    @Test func codableRoundTripAndValidation() throws {
        let money = try Money(minorUnits: -4280, currencyCode: "EUR")
        let data = try JSONEncoder().encode(money)
        #expect(try JSONDecoder().decode(Money.self, from: data) == money)

        let invalid = Data(#"{"minorUnits":1,"currencyCode":"ABC"}"#.utf8)
        #expect(throws: MoneyError.self) { try JSONDecoder().decode(Money.self, from: invalid) }
    }
}

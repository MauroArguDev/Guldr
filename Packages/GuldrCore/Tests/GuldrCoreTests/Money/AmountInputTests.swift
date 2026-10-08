//
//  AmountInputTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 8/10/26.
//

import Foundation
import Testing
@testable import GuldrCore

struct AmountInputTests {

    private func type(_ keys: String, currency: String = "USD") throws -> AmountInput {
        var input = try AmountInput(currencyCode: currency)
        for key in keys {
            switch key {
            case ".": input.appendDecimalSeparator()
            case "<": input.deleteBackward()
            default: input.appendDigit(Int(String(key))!)
            }
        }
        return input
    }

    @Test(arguments: [
        ("1234", Int64(123_400)),
        ("12.5", 1250),
        ("12.05", 1205),
        (".5", 50),
        ("0.99", 99),
        ("", 0)
    ])
    func typedKeysBecomeMinorUnits(keys: String, expected: Int64) throws {
        #expect(try type(keys).minorUnits == expected)
    }

    @Test func leadingZerosAreIgnored() throws {
        var input = try AmountInput(currencyCode: "USD")
        #expect(input.appendDigit(0) == false)
        #expect(input.isEmpty)
        #expect(try type("0007").integerDigits == "7")
    }

    @Test func fractionIsLimitedToTheCurrencyMinorUnits() throws {
        var input = try type("1.23")
        #expect(input.appendDigit(4) == false)
        #expect(input.minorUnits == 123)

        #expect(try type("1.2345", currency: "KWD").minorUnits == 1234)
    }

    @Test func currenciesWithoutMinorUnitsRejectTheDecimalKey() throws {
        var input = try AmountInput(currencyCode: "JPY")
        input.appendDigit(5)
        #expect(input.appendDecimalSeparator() == false)
        #expect(input.minorUnits == 5)
    }

    @Test func secondDecimalSeparatorIsRejected() throws {
        var input = try type("1.")
        #expect(input.appendDecimalSeparator() == false)
    }

    @Test func integerPartIsCapped() throws {
        var input = try type("1234567890")
        #expect(input.appendDigit(1) == false)
        #expect(input.integerDigits.count == AmountInput.maxIntegerDigits)
    }

    @Test func deleteBackwardWalksBackThroughFractionSeparatorAndDigits() throws {
        var input = try type("12.5")
        input.deleteBackward()
        #expect(input.fractionDigits == "")
        input.deleteBackward()
        #expect(input.fractionDigits == nil)
        input.deleteBackward()
        #expect(input.integerDigits == "1")
        input.deleteBackward()
        #expect(input.deleteBackward() == false)
        #expect(input.isEmpty)
    }

    @Test func invalidDigitIsRejected() throws {
        var input = try AmountInput(currencyCode: "USD")
        #expect(input.appendDigit(10) == false)
        #expect(input.appendDigit(-1) == false)
    }

    @Test func prefillsFromExistingMoney() throws {
        let input = try AmountInput(money: Money(minorUnits: 1250, currencyCode: "USD"))
        #expect(input.integerDigits == "12")
        #expect(input.fractionDigits == "5")
        #expect(input.minorUnits == 1250)

        let whole = try AmountInput(money: Money(minorUnits: 4200, currencyCode: "USD"))
        #expect(whole.fractionDigits == nil)
        #expect(whole.minorUnits == 4200)

        let cents = try AmountInput(money: Money(minorUnits: 5, currencyCode: "USD"))
        #expect(cents.integerDigits.isEmpty)
        #expect(cents.fractionDigits == "05")
        #expect(cents.minorUnits == 5)
    }

    @Test func displayTextFollowsTheLocale() throws {
        let input = try type("1234.5")
        #expect(input.displayText(locale: Locale(identifier: "en_US")) == "1,234.5")
        #expect(input.displayText(locale: Locale(identifier: "es_MX")) == "1,234.5")
        #expect(try type("12345.5").displayText(locale: Locale(identifier: "de_DE")) == "12.345,5")
        #expect(try type("").displayText(locale: Locale(identifier: "en_US")) == "0")
        #expect(try type("3.").displayText(locale: Locale(identifier: "en_US")) == "3.")
    }

    @Test func moneyCarriesTheCurrency() throws {
        let money = try type("9.99", currency: "eur").money
        #expect(money == (try Money(minorUnits: 999, currencyCode: "EUR")))
    }
}

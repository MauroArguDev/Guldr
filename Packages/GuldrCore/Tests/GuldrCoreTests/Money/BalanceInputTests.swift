//
//  BalanceInputTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 1/11/26.
//

import Foundation
import Testing
@testable import GuldrCore

struct BalanceInputTests {

    private func prefilled(_ cents: Int64) throws -> BalanceInput {
        try BalanceInput(prefilled: try Money(minorUnits: cents, currencyCode: "USD"))
    }

    @Test func anEmptyInputTypesLikeTheAddSheet() throws {
        var input = try BalanceInput(currencyCode: "USD")
        #expect(!input.isPrefilled)
        input.pressDigit(4)
        input.pressDigit(2)
        input.pressDecimalSeparator()
        input.pressDigit(5)
        #expect(input.amount.minorUnits == 4_250)
        let deleted = input.pressDelete()
        #expect(deleted && input.amount.minorUnits == 4_200)
    }

    @Test func theFirstKeyReplacesThePrefilledAmount() throws {
        var input = try prefilled(500_000)
        #expect(input.isPrefilled && input.amount.minorUnits == 500_000)
        let accepted = input.pressDigit(7)
        #expect(accepted && !input.isPrefilled)
        #expect(input.amount.minorUnits == 700)
        input.pressDigit(5)
        #expect(input.amount.minorUnits == 7_500)
    }

    @Test func zeroAndTheSeparatorAlsoReplaceIt() throws {
        var zero = try prefilled(500_000)
        // A leading zero is never typed, but the key still cleared the amount.
        let cleared = zero.pressDigit(0)
        #expect(cleared && zero.amount.isEmpty)

        var separator = try prefilled(500_000)
        let started = separator.pressDecimalSeparator()
        separator.pressDigit(5)
        #expect(started)
        #expect(separator.amount.minorUnits == 50)
    }

    @Test func deleteClearsThePrefilledAmount() throws {
        var input = try prefilled(500_000)
        let cleared = input.pressDelete()
        #expect(cleared && input.amount.isEmpty && !input.isPrefilled)
        let rejected = input.pressDelete()
        #expect(!rejected)
    }

    @Test func aZeroBalanceStartsEmpty() throws {
        let input = try prefilled(0)
        #expect(!input.isPrefilled && input.amount.isEmpty)
    }

    @Test func anUnknownCurrencyIsATypedError() {
        #expect(throws: MoneyError.unknownCurrency("XYZ")) {
            try BalanceInput(currencyCode: "XYZ")
        }
    }
}

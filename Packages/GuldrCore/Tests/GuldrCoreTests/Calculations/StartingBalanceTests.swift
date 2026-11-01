//
//  StartingBalanceTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 1/11/26.
//

import Foundation
import Testing
@testable import GuldrCore

/// What the user types is what they have today (ADR 016): the stored starting balance makes the
/// balance show exactly that, whatever was logged before.
struct StartingBalanceTests {

    private let utc = TimeZone(identifier: "UTC")!

    private func transaction(_ cents: Int64, _ kind: TransactionKind, currency: String = "USD") throws -> Transaction {
        Transaction(amount: try Money(minorUnits: cents, currencyCode: currency), kind: kind,
                    date: Date(timeIntervalSince1970: 1_790_000_000))
    }

    @Test func aNewUsersStartingBalanceIsWhatTheyTyped() throws {
        let net = try StartingBalance.loggedNet(of: [], currencyCode: "USD")
        #expect(net == 0)
        #expect(try StartingBalance.opening(forBalanceToday: 500_000, loggedNet: net) == 500_000)
    }

    @Test func theBalanceShowsExactlyWhatWasTypedAfterWeeksOfLogging() throws {
        let transactions = [
            try transaction(300_000, .income),
            try transaction(380_000, .expense),
            try transaction(99_900, .income, currency: "EUR")
        ]
        let net = try StartingBalance.loggedNet(of: transactions, currencyCode: "usd")
        #expect(net == -80_000)
        let opening = try StartingBalance.opening(forBalanceToday: 500_000, loggedNet: net)
        #expect(opening == 580_000)

        let month = YearMonth(containing: Date(timeIntervalSince1970: 1_790_000_000), timeZone: utc)
        let summary = try MonthSummary(transactions: transactions, month: month, currencyCode: "USD",
                                       openingBalance: opening, timeZone: utc)
        #expect(summary.balance.minorUnits == 500_000)
        #expect(summary.income.minorUnits == 300_000)
        #expect(summary.expenses.minorUnits == 380_000)
    }

    @Test func moreIncomeLoggedThanLeftGivesANegativeStartingBalance() throws {
        let net = try StartingBalance.loggedNet(of: [try transaction(900_000, .income)], currencyCode: "USD")
        #expect(try StartingBalance.opening(forBalanceToday: 100_000, loggedNet: net) == -800_000)
    }

    @Test func errorsAreTyped() throws {
        #expect(throws: MoneyError.unknownCurrency("XYZ")) {
            try StartingBalance.loggedNet(of: [], currencyCode: "XYZ")
        }
        #expect(throws: MoneyError.overflow) {
            try StartingBalance.opening(forBalanceToday: .max, loggedNet: -1)
        }
    }
}

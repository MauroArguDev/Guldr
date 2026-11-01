//
//  StartingBalance.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 1/11/26.
//

import Foundation

/// Turns what the user has today into a starting balance (ADR 016).
///
/// The user never types the starting balance itself: someone who has been logging for weeks can't know
/// what they had before the first transaction, but their banking app says what they have now. Guldr
/// stores that amount minus the net already logged, so the balance shows exactly what was typed.
public enum StartingBalance {

    /// Every income minus every expense in `currencyCode`, without any starting balance.
    public static func loggedNet(of transactions: some Sequence<Transaction>,
                                 currencyCode: String) throws(MoneyError) -> Int64 {
        let code = try Currency.validatedCode(currencyCode)
        var net = Tally()
        for transaction in transactions where transaction.currencyCode == code {
            switch transaction.kind {
            case .income: try net.add(transaction.amountMinorUnits)
            case .expense: try net.subtract(transaction.amountMinorUnits)
            }
        }
        return net.minorUnits
    }

    /// The starting balance that makes the balance equal `balanceToday`. Negative when more income was
    /// logged than the user still has.
    public static func opening(forBalanceToday balanceToday: Int64, loggedNet: Int64) throws(MoneyError) -> Int64 {
        let (opening, overflow) = balanceToday.subtractingReportingOverflow(loggedNet)
        guard !overflow else { throw .overflow }
        return opening
    }
}

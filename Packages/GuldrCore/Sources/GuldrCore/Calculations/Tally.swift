//
//  Tally.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 10/10/26.
//

/// A running total of minor units that throws instead of wrapping around on overflow. The
/// calculations sum thousands of amounts; an `Int64` overflow is unrealistic, but never silent.
struct Tally {

    private(set) var minorUnits: Int64 = 0

    mutating func add(_ amount: Int64) throws(MoneyError) {
        let (result, overflow) = minorUnits.addingReportingOverflow(amount)
        guard !overflow else { throw .overflow }
        minorUnits = result
    }

    mutating func subtract(_ amount: Int64) throws(MoneyError) {
        let (result, overflow) = minorUnits.subtractingReportingOverflow(amount)
        guard !overflow else { throw .overflow }
        minorUnits = result
    }

    func money(_ currencyCode: String) -> Money {
        Money.unchecked(minorUnits, currencyCode)
    }
}

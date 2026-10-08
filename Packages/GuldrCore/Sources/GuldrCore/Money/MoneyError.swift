//
//  MoneyError.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 8/10/26.
//

/// Errors raised by money operations. They are programming or data errors, never shown raw to the user.
public enum MoneyError: Error, Equatable, Sendable {
    /// The code is not an ISO 4217 currency known to the system.
    case unknownCurrency(String)
    /// Two amounts in different currencies were combined.
    case currencyMismatch(String, String)
    /// The result does not fit in `Int64` minor units.
    case overflow
}

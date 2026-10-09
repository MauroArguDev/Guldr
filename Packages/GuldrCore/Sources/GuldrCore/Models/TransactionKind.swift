//
//  TransactionKind.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 9/10/26.
//

/// Whether money goes out or comes in. Used by transactions and categories.
///
/// Models store the raw value as a `String`, which every store and CloudKit can map, and expose this
/// enum through a computed property.
public enum TransactionKind: String, CaseIterable, Codable, Sendable {
    case expense
    case income
}

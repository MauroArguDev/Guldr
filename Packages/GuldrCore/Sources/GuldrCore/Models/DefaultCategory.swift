//
//  DefaultCategory.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 9/10/26.
//

/// A category seeded on first launch (ADR 008), in the order of the add sheet's category grid.
public struct DefaultCategory: Equatable, Sendable {

    /// Stable identifier. Never changes, never shown, never translated.
    public let systemKey: String
    /// English source name, also the key of its translation in the app's String Catalog.
    public let name: String
    public let symbolName: String
    public let color: CategoryColor
    public let kind: TransactionKind

    public static let all: [DefaultCategory] = [
        DefaultCategory(systemKey: "food", name: "Food", symbolName: "fork.knife", color: .terracotta,
                        kind: .expense),
        DefaultCategory(systemKey: "transport", name: "Transport", symbolName: "car", color: .sky,
                        kind: .expense),
        DefaultCategory(systemKey: "housing", name: "Housing", symbolName: "house", color: .gold,
                        kind: .expense),
        DefaultCategory(systemKey: "health", name: "Health", symbolName: "heart", color: .green,
                        kind: .expense),
        DefaultCategory(systemKey: "shopping", name: "Shopping", symbolName: "bag", color: .plum,
                        kind: .expense),
        DefaultCategory(systemKey: "entertainment", name: "Entertainment", symbolName: "play", color: .wine,
                        kind: .expense),
        DefaultCategory(systemKey: "education", name: "Education", symbolName: "book", color: .indigo,
                        kind: .expense),
        DefaultCategory(systemKey: "other_expense", name: "Other", symbolName: "ellipsis.circle", color: .graphite,
                        kind: .expense),
        DefaultCategory(systemKey: "salary", name: "Salary", symbolName: "briefcase", color: .gold,
                        kind: .income),
        DefaultCategory(systemKey: "freelance", name: "Freelance", symbolName: "laptopcomputer", color: .teal,
                        kind: .income),
        DefaultCategory(systemKey: "other_income", name: "Other income", symbolName: "banknote", color: .olive,
                        kind: .income)
    ]

    public static func named(_ systemKey: String) -> DefaultCategory? {
        all.first { $0.systemKey == systemKey }
    }
}

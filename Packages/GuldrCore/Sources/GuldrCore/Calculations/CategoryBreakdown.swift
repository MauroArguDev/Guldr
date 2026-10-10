//
//  CategoryBreakdown.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import Foundation

/// Expenses per category for a period: the Charts donut and its legend (ADR 009).
///
/// At most `maxSlices` slices. The largest categories get their own slice; everything else (the
/// seeded "Other" category, the smallest categories and expenses without a category) is summed into
/// one "Other" slice, always last, so the donut never shows two "Other" slices. Archived categories
/// still count: reports keep their history (ADR 008). Other currencies are ignored (ADR 005).
public struct CategoryBreakdown: Equatable, Sendable {

    public enum SliceKind: Hashable, Sendable {
        case category(UUID)
        /// The combined slice, with the categories it contains (no ID for expenses without one).
        case other(categoryIDs: [UUID])
    }

    public struct Slice: Equatable, Sendable, Identifiable {
        public let kind: SliceKind
        public let total: Money
        /// Whole percent of the period's expenses. All slices add up to exactly 100.
        public let percentage: Int

        public var id: String {
            switch kind {
            case .category(let id): id.uuidString
            case .other: "other"
            }
        }
    }

    /// The seeded catch-all category, merged into the "Other" slice.
    public static let otherCategoryKey = "other_expense"
    public static let defaultMaxSlices = 7

    /// Largest first, with "Other" last.
    public let slices: [Slice]
    public let total: Money

    public init(transactions: some Sequence<Transaction>, period: DateInterval, currencyCode: String,
                maxSlices: Int = defaultMaxSlices) throws(MoneyError) {
        let code = try Currency.validatedCode(currencyCode)

        var byCategory: [UUID: Tally] = [:]
        var otherCategoryIDs: Set<UUID> = []
        var other = Tally()
        var total = Tally()
        for transaction in transactions where transaction.kind == .expense && transaction.currencyCode == code
            && transaction.date >= period.start && transaction.date < period.end {
            try total.add(transaction.amountMinorUnits)
            if let category = transaction.category, category.systemKey != Self.otherCategoryKey {
                try byCategory[category.id, default: Tally()].add(transaction.amountMinorUnits)
            } else {
                if let id = transaction.category?.id { otherCategoryIDs.insert(id) }
                try other.add(transaction.amountMinorUnits)
            }
        }

        var named = byCategory.map { (id: $0.key, minorUnits: $0.value.minorUnits) }
            .sorted { $0.minorUnits != $1.minorUnits ? $0.minorUnits > $1.minorUnits : $0.id.uuidString < $1.id.uuidString }
        let slots = max(1, maxSlices)
        if named.count + (other.minorUnits > 0 ? 1 : 0) > slots {
            for overflow in named.dropFirst(slots - 1) {
                otherCategoryIDs.insert(overflow.id)
                try other.add(overflow.minorUnits)
            }
            named = Array(named.prefix(slots - 1))
        }

        var parts = named.map { (kind: SliceKind.category($0.id), minorUnits: $0.minorUnits) }
        if other.minorUnits > 0 {
            parts.append((.other(categoryIDs: otherCategoryIDs.sorted { $0.uuidString < $1.uuidString }), other.minorUnits))
        }
        let percentages = Self.wholePercentages(parts.map(\.minorUnits))
        slices = zip(parts, percentages).map { part, percentage in
            Slice(kind: part.kind, total: Money.unchecked(part.minorUnits, code), percentage: percentage)
        }
        self.total = total.money(code)
    }

    /// The breakdown for one calendar month.
    public init(transactions: some Sequence<Transaction>, month: YearMonth, currencyCode: String,
                timeZone: TimeZone = .autoupdatingCurrent, maxSlices: Int = defaultMaxSlices) throws(MoneyError) {
        try self.init(transactions: transactions, period: month.dateInterval(in: timeZone),
                      currencyCode: currencyCode, maxSlices: maxSlices)
    }

    // MARK: - Private

    /// Largest remainder method: floor every share, then give the missing points to the largest
    /// remainders, so rounding never makes the legend add up to 99 or 101.
    static func wholePercentages(_ values: [Int64]) -> [Int] {
        let total = values.reduce(0, +)
        guard total > 0 else { return values.map { _ in 0 } }
        let exact = values.map { Double($0) * 100 / Double(total) }
        var result = exact.map { Int($0.rounded(.down)) }
        let missing = 100 - result.reduce(0, +)
        let order = exact.indices.sorted { lhs, rhs in
            let left = exact[lhs] - exact[lhs].rounded(.down)
            let right = exact[rhs] - exact[rhs].rounded(.down)
            return left != right ? left > right : lhs < rhs
        }
        for index in order.prefix(missing) {
            result[index] += 1
        }
        return result
    }
}

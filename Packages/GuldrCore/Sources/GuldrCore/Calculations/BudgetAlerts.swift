//
//  BudgetAlerts.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation

/// The shares of a category's monthly budget that send a notification (v1 plan, Phase 25).
public enum BudgetThreshold: Int, CaseIterable, Comparable, Sendable {
    case nearing = 80
    case reached = 100

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Integer math, so 80 % of $400.00 is met at exactly $320.00. A zero limit never alerts.
    func isMet(by line: BudgetStatus.Line) -> Bool {
        guard line.limit.minorUnits > 0 else { return false }
        return line.spent.minorUnits.multipliedReportingOverflow(by: 100).partialValue
            >= line.limit.minorUnits.multipliedReportingOverflow(by: Int64(rawValue)).partialValue
    }
}

/// One notification to send: a category crossed a threshold of its budget this month.
public struct BudgetAlert: Equatable, Sendable {
    public let categoryID: UUID
    public let month: YearMonth
    public let threshold: BudgetThreshold
    public let spent: Money
    public let limit: Money
}

/// Which thresholds were already notified, so each one is sent once per category per month.
///
/// Stored as plain strings in the App Group's defaults (`AppSettings.budgetAlertKeys`). Only the
/// current month's keys are kept: a new month starts fresh, and nothing grows without bound.
public struct BudgetAlertLedger: Equatable, Sendable {

    public private(set) var keys: Set<String>

    public init(keys: some Sequence<String> = []) {
        self.keys = Set(keys)
    }

    /// The alerts `status` calls for, and records them. A category that jumps past both thresholds in
    /// one save gets only the higher one; spending that drops back and rises again doesn't repeat it.
    public mutating func dueAlerts(for status: BudgetStatus) -> [BudgetAlert] {
        let prefix = Self.prefix(for: status.month)
        keys = keys.filter { $0.hasPrefix(prefix) }

        var alerts: [BudgetAlert] = []
        for line in status.lines {
            let met = BudgetThreshold.allCases.filter { $0.isMet(by: line) }
            guard let highest = met.max() else { continue }
            let highestKey = Self.key(month: status.month, categoryID: line.categoryID, threshold: highest)
            if !keys.contains(highestKey) {
                alerts.append(BudgetAlert(categoryID: line.categoryID, month: status.month, threshold: highest,
                                          spent: line.spent, limit: line.limit))
            }
            for threshold in met {
                keys.insert(Self.key(month: status.month, categoryID: line.categoryID, threshold: threshold))
            }
        }
        return alerts
    }

    /// "202610:<category UUID>:80".
    static func key(month: YearMonth, categoryID: UUID, threshold: BudgetThreshold) -> String {
        prefix(for: month) + "\(categoryID.uuidString):\(threshold.rawValue)"
    }

    private static func prefix(for month: YearMonth) -> String {
        "\(month.rawValue):"
    }
}

//
//  CSVExporter.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation

/// Transactions as an RFC 4180 CSV file (v1 plan, Phase 26): a header, then one record per transaction,
/// CRLF line endings, UTF-8.
///
/// Columns: `date` (ISO 8601 with the time and the offset), `title`, `category`, `type` (`expense` or
/// `income`), `amount` (signed: expenses negative, a period as the decimal separator, no symbol, the
/// currency's minor digits), `currency` (ISO 4217) and `note`. Headers and `type` stay in English so
/// formulas keep working in any language; `category` is the name the app shows (author's calls,
/// 2026-10-21).
public enum CSVExporter {

    public static let header = ["date", "title", "category", "type", "amount", "currency", "note"]

    /// One transaction's values, copied from the model on the main actor so the file can be written
    /// anywhere: SwiftData models can't leave their context.
    public struct Row: Equatable, Sendable {
        public let date: Date
        public let title: String
        public let category: String
        public let kind: TransactionKind
        public let amount: Money
        public let note: String

        public init(date: Date, title: String, category: String, kind: TransactionKind, amount: Money, note: String) {
            self.date = date
            self.title = title
            self.category = category
            self.kind = kind
            self.amount = amount
            self.note = note
        }

        /// `categoryName` names the transaction's category (`nil` for none), as the app shows it.
        public init(_ transaction: Transaction, categoryName: (Category?) -> String) {
            self.init(date: transaction.date, title: transaction.title, category: categoryName(transaction.category),
                      kind: transaction.kind, amount: transaction.amount, note: transaction.note)
        }
    }

    /// The file, built off the main actor so a long history doesn't stall the interface.
    @concurrent
    public static func data(for rows: [Row], timeZone: TimeZone = .autoupdatingCurrent) async -> Data {
        Data(text(for: rows, timeZone: timeZone).utf8)
    }

    /// The file's text, oldest first; equal dates keep the order given.
    public static func text(for rows: [Row], timeZone: TimeZone = .autoupdatingCurrent) -> String {
        let dates = ISO8601DateFormatter()
        dates.formatOptions = [.withInternetDateTime]
        dates.timeZone = timeZone

        var lines = [record(header)]
        let sorted = rows.enumerated().sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }
        for (_, row) in sorted {
            lines.append(record([
                dates.string(from: row.date),
                row.title,
                row.category,
                row.kind.rawValue,
                amountText(row.amount, kind: row.kind),
                row.amount.currencyCode,
                row.note
            ]))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// "Guldr-2026-10-21.csv", in the device's calendar day.
    public static func fileName(on date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        return "Guldr-\(day).csv"
    }

    // MARK: - Private

    /// RFC 4180: a field with a comma, a quote, CR or LF is quoted, and its quotes are doubled.
    static func field(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func record(_ fields: [String]) -> String {
        fields.map(field).joined(separator: ",")
    }

    /// "-42.80", "5000.00", "-1200" for yen: digits only, never the locale's separators.
    static func amountText(_ amount: Money, kind: TransactionKind) -> String {
        let digits = (try? Currency.minorUnitDigits(for: amount.currencyCode)) ?? 2
        let magnitude = amount.minorUnits.magnitude
        let scale = (0..<digits).reduce(UInt64(1)) { value, _ in value * 10 }
        let whole = magnitude / scale
        var text = String(whole)
        if digits > 0 {
            let fraction = String(magnitude % scale)
            text += "." + String(repeating: "0", count: digits - fraction.count) + fraction
        }
        let isNegative = kind == .expense ? amount.minorUnits > 0 : amount.minorUnits < 0
        return isNegative ? "-" + text : text
    }
}

//
//  ExportModel.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import Foundation
import GuldrCore
import Observation

/// Settings › Export: which transactions go in the file. Like the other screen models, the view owns the
/// `@Query` and calls `update`; the model never holds a context.
@Observable
final class ExportModel {

    enum Range: Hashable {
        case allTime
        case dates
    }

    var range: Range = .allTime {
        didSet { rebuild() }
    }
    /// The first and last day included, whole days in the device's time zone.
    var startDay: Date {
        didSet { rebuild() }
    }
    var endDay: Date {
        didSet { rebuild() }
    }

    /// The file to share; `nil` while no transaction is in the range.
    private(set) var file: ExportFile?
    /// How many transactions the range includes.
    private(set) var includedCount = 0

    init(timeZone: TimeZone = .autoupdatingCurrent, now: @escaping () -> Date = { .now }) {
        self.timeZone = timeZone
        self.now = now
        let today = now()
        endDay = today
        startDay = YearMonth(containing: today, timeZone: timeZone).dateInterval(in: timeZone).start
    }

    /// Copies every transaction once; the range then only filters the copies.
    func update(transactions: [Transaction]) {
        rows = transactions.map { CSVExporter.Row($0, categoryName: Self.name(of:)) }
        rebuild()
    }

    // MARK: - Private

    @ObservationIgnored private let timeZone: TimeZone
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var rows: [CSVExporter.Row] = []

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func rebuild() {
        let included: [CSVExporter.Row]
        switch range {
        case .allTime:
            included = rows
        case .dates:
            // Either order works: the earlier day starts the range and the later one ends it.
            let first = calendar.startOfDay(for: min(startDay, endDay))
            let lastDay = calendar.startOfDay(for: max(startDay, endDay))
            let end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
            included = rows.filter { $0.date >= first && $0.date < end }
        }
        includedCount = included.count
        file = included.isEmpty ? nil : ExportFile(rows: included, timeZone: timeZone,
                                                   name: CSVExporter.fileName(on: now(), timeZone: timeZone))
    }

    private static func name(of category: Category?) -> String {
        category?.displayName ?? String(localized: "Uncategorized")
    }
}

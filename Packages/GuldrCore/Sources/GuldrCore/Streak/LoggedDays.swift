//
//  LoggedDays.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import SwiftData

/// Reading and writing the logged days (ADR 012). Writes are inserted into the caller's context and saved
/// with the caller's own save, so a transaction and the day it logs are stored together or not at all.
public enum LoggedDays {

    /// Whether `day` can still be logged at `now`: today, or yesterday until today ends.
    public static func canLog(_ day: LocalDay, now: Date, timeZone: TimeZone) -> Bool {
        let today = LocalDay(containing: now, timeZone: timeZone)
        return day == today || day == today.adding(days: -1)
    }

    /// After a **new** transaction dated `date`: logs its day if it's still open and isn't logged yet.
    /// Returns whether a day was added. Editing a transaction never calls this.
    @discardableResult
    public static func recordTransaction(dated date: Date, now: Date, timeZone: TimeZone,
                                         in context: ModelContext) throws -> Bool {
        try record(LocalDay(containing: date, timeZone: timeZone), source: .transaction, now: now,
                   timeZone: timeZone, in: context)
    }

    /// "No spending" for today or an open yesterday. Returns whether a day was added.
    @discardableResult
    public static func markNoSpending(_ day: LocalDay, now: Date, timeZone: TimeZone,
                                      in context: ModelContext) throws -> Bool {
        try record(day, source: .noSpending, now: now, timeZone: timeZone, in: context)
    }

    /// Every logged day with how it was logged; a day logged both ways reads as a transaction.
    public static func all(in context: ModelContext) throws -> [LocalDay: LoggedDaySource] {
        var days: [LocalDay: LoggedDaySource] = [:]
        for logged in try context.fetch(FetchDescriptor<LoggedDay>()) {
            guard let day = logged.day else { continue }
            if days[day] != .transaction { days[day] = logged.source }
        }
        return days
    }

    /// The streak as of `now`.
    public static func streak(in context: ModelContext, now: Date, timeZone: TimeZone) throws -> LoggingStreak {
        LoggingStreak(loggedDays: try all(in: context), today: LocalDay(containing: now, timeZone: timeZone))
    }

    /// Once, when the store first opens with `SchemaV2`: every transaction created on its own day or the
    /// next one becomes a logged day, so people who have been logging keep their streak. Backfilled
    /// history doesn't count, as it wouldn't have then. Saves; returns the number of days added.
    @discardableResult
    public static func importHistory(in context: ModelContext, timeZone: TimeZone) throws -> Int {
        var existing = Set(try all(in: context).keys)
        var added = 0
        for transaction in try context.fetch(FetchDescriptor<Transaction>()) {
            let day = LocalDay(containing: transaction.date, timeZone: timeZone)
            let created = LocalDay(containing: transaction.createdAt, timeZone: timeZone)
            guard created == day || created == day.adding(days: 1), existing.insert(day).inserted else { continue }
            context.insert(LoggedDay(day: day, source: .transaction, loggedAt: transaction.createdAt))
            added += 1
        }
        if added > 0 { try context.save() }
        return added
    }

    // MARK: - Private

    private static func record(_ day: LocalDay, source: LoggedDaySource, now: Date, timeZone: TimeZone,
                               in context: ModelContext) throws -> Bool {
        guard canLog(day, now: now, timeZone: timeZone) else { return false }
        let key = day.rawValue
        let descriptor = FetchDescriptor<LoggedDay>(predicate: #Predicate { $0.dayKey == key })
        guard try context.fetchCount(descriptor) == 0 else { return false }
        context.insert(LoggedDay(day: day, source: source, loggedAt: now))
        return true
    }
}

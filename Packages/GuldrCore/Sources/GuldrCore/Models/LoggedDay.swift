//
//  LoggedDay.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation
import SwiftData

extension SchemaV2 {

    /// A day that counts for the logging streak (ADR 012): written when a new transaction dated that day
    /// is saved, or the day is marked "No spending", before the end of the next day. Once written it
    /// stays, even if that transaction is later deleted.
    ///
    /// CloudKit rules (ADR 007): every stored property has a default and nothing is unique. A duplicate
    /// day (two devices in v1.1) is harmless, since days are read as a set.
    @Model
    public final class LoggedDay {

        public var id = UUID()
        /// `LocalDay.rawValue`, e.g. `20261023`, in the device's time zone when it was logged.
        public var dayKey = 0
        public var sourceRawValue = LoggedDaySource.transaction.rawValue
        public var loggedAt = Date.now

        public init(day: LocalDay, source: LoggedDaySource, loggedAt: Date = .now) {
            self.dayKey = day.rawValue
            self.sourceRawValue = source.rawValue
            self.loggedAt = loggedAt
        }

        /// `nil` for a key that isn't a valid day.
        public var day: LocalDay? { LocalDay(rawValue: dayKey) }

        /// Falls back to `.transaction` for a raw value written by a newer version of the app.
        public var source: LoggedDaySource { LoggedDaySource(rawValue: sourceRawValue) ?? .transaction }
    }
}

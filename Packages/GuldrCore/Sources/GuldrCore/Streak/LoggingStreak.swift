//
//  LoggingStreak.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation

/// How a day was logged (ADR 012).
public enum LoggedDaySource: String, Sendable {
    /// A new transaction dated that day was saved by the end of the next day.
    case transaction
    /// The user marked the day "No spending".
    case noSpending
}

/// The logging streak as of today, derived from the logged days alone (ADR 012). Nothing is stored but
/// the days, so the count, the freezes and the best run can't drift from the data.
///
/// Days up to two days ago are final. Yesterday can still be repaired and today is still open, so a day
/// that isn't logged yet never breaks the streak before its time. A final missed day spends a freeze
/// while one is held, which keeps the run alive without adding to it; otherwise the run ends.
public struct LoggingStreak: Equatable, Sendable {

    /// What a day looks like in the streak's calendar.
    public enum DayState: Equatable, Sendable {
        case logged
        case noSpending
        /// Missed, covered by a freeze.
        case frozen
        /// Missed and final: it ended the run, or there was no run to end.
        case missed
        /// Yesterday, not logged yet: a transaction dated that day or "No spending" still counts.
        case repairable
        /// Today, not logged yet.
        case open
        /// Before the first logged day, or after today.
        case outside
    }

    /// The counts that are celebrated (author's call, 2026-10-23): many early, when each day feels biggest.
    public static let milestones = [3, 7, 14, 30, 60, 100, 180, 365]
    /// One freeze per this many consecutive logged days...
    public static let daysPerFreeze = 7
    /// ...up to this many held (author's call, 2026-10-23).
    public static let maxFreezes = 2

    public let today: LocalDay
    /// Logged days in the current run, including today once logged. Frozen days don't add.
    public let current: Int
    /// The longest run ever.
    public let best: Int
    public let freezesHeld: Int
    /// The first logged day of the current run, which tells one run from the next; `nil` without a run.
    public let runStart: LocalDay?

    public init(loggedDays: [LocalDay: LoggedDaySource], today: LocalDay) {
        self.today = today
        var states: [LocalDay: DayState] = [:]
        var current = 0
        var best = 0
        var freezes = 0
        var loggedInARow = 0
        var runStart: LocalDay?
        let yesterday = today.adding(days: -1)

        if let first = loggedDays.keys.min(), first <= today {
            var day = first
            while day <= today {
                defer { day = day.adding(days: 1) }
                if let source = loggedDays[day] {
                    states[day] = source == .noSpending ? .noSpending : .logged
                    if current == 0 { runStart = day }
                    current += 1
                    loggedInARow += 1
                    if loggedInARow.isMultiple(of: Self.daysPerFreeze), freezes < Self.maxFreezes { freezes += 1 }
                    best = max(best, current)
                } else if day == today {
                    states[day] = .open
                } else if day == yesterday {
                    states[day] = .repairable
                } else if current > 0, freezes > 0 {
                    states[day] = .frozen
                    freezes -= 1
                    loggedInARow = 0
                } else {
                    states[day] = .missed
                    current = 0
                    loggedInARow = 0
                    runStart = nil
                }
            }
        }
        // Yesterday can be marked even before any history: it would start the first run.
        if loggedDays[yesterday] == nil, states[yesterday] == nil { states[yesterday] = .repairable }
        if loggedDays[today] == nil { states[today] = .open }

        self.current = current
        self.best = best
        self.freezesHeld = freezes
        self.runStart = runStart
        self.states = states
    }

    public func state(of day: LocalDay) -> DayState {
        states[day] ?? .outside
    }

    public var isTodayLogged: Bool {
        state(of: today) == .logged || state(of: today) == .noSpending
    }

    /// Yesterday isn't logged and logging it now would keep a run alive.
    public var isYesterdayAtRisk: Bool {
        current > 0 && state(of: today.adding(days: -1)) == .repairable
    }

    /// The milestone the current count sits on, if any; celebrated once per run.
    public var reachedMilestone: Int? {
        Self.milestones.contains(current) ? current : nil
    }

    public var nextMilestone: Int? {
        Self.milestones.first { $0 > current }
    }

    // MARK: - Private

    private let states: [LocalDay: DayState]
}

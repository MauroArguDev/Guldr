//
//  StreakCalendar.swift
//  GuldrCore
//
//  Created by Mauricio Argumedo on 23/10/26.
//

import Foundation

/// The streak sheet's calendar: whole weeks up to the one containing today, starting on the locale's
/// first weekday, so the grid lines up with the user's own calendar.
public enum StreakCalendar {

    /// The weeks shown (author's plan, Phase 29): about a month, enough to see a freeze or a repair.
    public static let weekCount = 5

    /// `count` weeks of 7 days, oldest first, the last one containing `today`. `firstWeekday` is
    /// `Calendar.firstWeekday` (1 = Sunday). Days after today are included, for the grid's shape.
    public static func weeks(endingWith today: LocalDay, count: Int = weekCount, firstWeekday: Int) -> [[LocalDay]] {
        let offsetIntoWeek = (today.weekday - firstWeekday + 7) % 7
        let start = today.adding(days: -offsetIntoWeek - 7 * (count - 1))
        return (0..<count).map { week in
            (0..<7).map { start.adding(days: week * 7 + $0) }
        }
    }
}

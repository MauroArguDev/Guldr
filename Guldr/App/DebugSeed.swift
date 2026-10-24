//
//  DebugSeed.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 15/10/26.
//

#if DEBUG
import Foundation
import GuldrCore
import OSLog
import SwiftData

/// Debug builds only: fills an empty store with generated transactions, budgets for the current month
/// and two years of logged days (every 13th missed), to try the screens, the streak and the achievements
/// with a heavy history. Pass the launch argument `-seedTransactions 5000`
/// (Xcode › Scheme › Arguments, or `xcrun simctl launch … -seedTransactions 5000`). For screenshots,
/// `-demoData` loads the mockups' six months instead, moved to end this month, in the language and currency
/// of the device's locale (`PreviewData.Flavor`). A store that already has transactions is left alone, so
/// relaunching never duplicates them.
enum DebugSeed {

    static func applyIfRequested(to container: ModelContainer,
                                 arguments: [String] = ProcessInfo.processInfo.arguments) {
        let isDemo = arguments.contains("-demoData")
        let count = arguments.firstIndex(of: "-seedTransactions")
            .flatMap { arguments.indices.contains($0 + 1) ? Int(arguments[$0 + 1]) : nil } ?? 0
        guard isDemo || count > 0 else { return }
        let context = ModelContext(container)
        do {
            guard try context.fetchCount(FetchDescriptor<Transaction>()) == 0 else { return }
            if isDemo {
                try PreviewData.populate(context, endingAt: .now, flavor: .matching(.autoupdatingCurrent))
                logger.info("Loaded the demo data")
            } else {
                try insert(count, into: context)
                logger.info("Seeded \(count) transactions")
            }
        } catch {
            logger.error("Seeding failed: \(error)")
        }
    }

    // MARK: - Private

    private static let logger = Logger(subsystem: "com.argudev.guldr", category: "DebugSeed")
    private static let titles = ["Groceries", "Coffee", "Rent", "Gas", "Pharmacy", "Dinner out", "Books",
                                 "Transit pass", "Café con leche", "Streaming", "Salary", "Freelance"]

    /// Two years back from now, every default category, USD. Deterministic, so runs compare.
    private static func insert(_ count: Int, into context: ModelContext) throws {
        let categories = try context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder)]))
        guard !categories.isEmpty else { return }
        let span: TimeInterval = 2 * 365 * 86_400
        let now = Date.now
        var generator = SplitMix64(seed: 2026)
        for index in 0..<count {
            let category = categories[index % categories.count]
            let date = now.addingTimeInterval(-Double.random(in: 0..<span, using: &generator))
            let cents = Int64.random(in: 100...(category.kind == .income ? 500_000 : 30_000), using: &generator)
            context.insert(Transaction(amount: try Money(minorUnits: cents, currencyCode: "USD"), kind: category.kind,
                                       title: titles[index % titles.count], date: date, category: category))
        }
        // $3,000 for each expense category this month: some end up over, most within.
        let month = YearMonth(containing: now)
        for category in categories where category.kind == .expense {
            context.insert(Budget(month: month, limit: try Money(minorUnits: 300_000, currencyCode: "USD"),
                                  category: category))
        }
        let today = LocalDay(containing: now, timeZone: .autoupdatingCurrent)
        for offset in -730 ... 0 where !offset.isMultiple(of: 13) {
            context.insert(LoggedDay(day: today.adding(days: offset), source: .transaction))
        }
        try context.save()
    }

    /// Deterministic random numbers (SplitMix64).
    private struct SplitMix64: RandomNumberGenerator {
        var state: UInt64

        init(seed: UInt64) {
            state = seed
        }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            return value ^ (value >> 31)
        }
    }
}
#endif

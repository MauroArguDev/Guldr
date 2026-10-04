# 006 — GuldrCore local package

- **Status:** Accepted
- **Date:** 2026-10-04

## Context

Unit tests currently live in `GuldrTests`, a test bundle hosted in the app. Running them needs an iOS simulator. On GitHub's runners the simulator takes 2–8 minutes to become usable, so every pull request that touches code waits 5–11 minutes for a test that itself runs in milliseconds.

Most of Guldr's logic does not depend on UIKit or on a device: money and formatting, month math, summaries, budget status, chart series, filtering, CSV export, notification thresholds. The app and the widget both need it.

## Decision

**Move the domain into a local Swift package, `Packages/GuldrCore`, tested with `swift test` on macOS.**

- **The package contains** the SwiftData models and schema, `Money` and the formatters, `YearMonth`, the calculations (`MonthSummary`, `BudgetStatus`, `CategoryBreakdown`, `MonthlySeries`, `TransactionQuery`), `CSVExporter`, notification threshold logic and the persistence factory.
- **The app keeps** views, view models, navigation and everything that talks to the system: LocalAuthentication, UserNotifications, WidgetKit, sharing. The widget extension keeps its views and timeline provider.
- **Platforms:** iOS 26 and macOS 26. macOS is only there so tests run natively on the Mac and on CI without a simulator. Nothing in the package may import UIKit.
- **Isolation:** the package keeps Swift's default `nonisolated` isolation (unlike the app targets' `MainActor`). Its value types are `Sendable` and callable from any context, including the widget's timeline provider and background export.
- **Tests:** `GuldrCoreTests` with Swift Testing and in-memory SwiftData containers. A `core-tests` CI job runs them and becomes a required check. `GuldrTests` stays small: only checks that need the app bundle, such as `AppGroupID`.

## Alternatives considered

- **Keep everything in the app target** — simplest structure, but every test pays the simulator cost, and the widget can only reuse code by sharing target membership file by file.
- **A framework target inside the Xcode project** — gives sharing between app and widget, but its tests still run on a simulator, and it adds project-file configuration that the author has to maintain by hand.
- **One package per feature** — more boundaries than a single-developer app needs today. It can be split later along the same seams.

## Consequences

- Logic tests run in seconds locally (`swift test --package-path Packages/GuldrCore`) and in about one or two minutes on CI. Most pull requests get feedback much faster.
- App and widget share exactly the same models and calculations, so the widget can never compute a different balance than the app.
- Public API needs explicit `public` modifiers, which makes the boundary between domain and UI visible in code review.
- The SwiftData schema lives in the package, so migrations are tested there too.
- Adding the package to the project and linking it to the targets is done once by the author in Xcode.
- Validated with a throwaway spike on 2026-10-04: a package with a SwiftData `@Model`, an in-memory container and a `#Predicate` query ran under `swift test` on macOS in about 21 seconds from a cold build, with no simulator.

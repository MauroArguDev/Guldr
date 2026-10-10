# 010 — App settings in the App Group's UserDefaults

- **Status:** Accepted
- **Date:** 2026-10-10

## Context

First launch (v1 plan, Phase 16) has to remember two values: the **active currency** ([ADR 005](005-money-representation.md): new transactions use it, and totals, budgets, charts and widgets include only transactions in it) and **whether first launch was completed**. More preferences will follow in Settings (Face ID lock, budget notifications).

The widget needs the active currency to total the right transactions, so the value must be readable from the extension, not only from the app. All financial data lives in the SwiftData store in the App Group ([ADR 007](007-persistence-and-widget-data.md)).

## Decision

**Preferences live in the App Group's `UserDefaults` (`UserDefaults(suiteName: <App Group>)`), behind an `AppSettings` type in `GuldrCore`.** Financial data stays in SwiftData.

- `AppSettings` exposes typed values (`activeCurrencyCode`, `hasCompletedOnboarding`) instead of raw keys, validates the currency on write and on read (an unknown stored code reads as none), and stores the currency before the first-launch flag, so a completed first launch always has a currency.
- The app opens it next to the store in `AppDataLoader`; failing to open the suite is the same `PersistenceError.appGroupUnavailable` as for the store.
- `UserDefaults` does not notify SwiftUI, so the app wraps it in an `@Observable` `Preferences` that keeps the current values and writes every change through.
- Tests use a throwaway suite per test.

## Alternatives considered

- **A singleton `Settings` model in SwiftData** — the widget already reads the store and CloudKit would sync it in v1.1, but a single-row model is a known problem with CloudKit: two devices each create their row before syncing and the app has to merge duplicates. It also turns reading two values into a fetch, and a store migration for every new preference.
- **`@AppStorage` on `UserDefaults.standard`** — the simplest, but the widget cannot read the app's standard defaults, so the currency would have to be copied somewhere shared later.

## Consequences

- The app and the widget read the same values synchronously, with no store fetch.
- Preferences do not sync with iCloud. When sync arrives in v1.1, the active currency can be mirrored to `NSUbiquitousKeyValueStore` if users expect it to follow them; first launch should stay per device.
- New preferences are added as typed properties on `AppSettings` and mirrored in `Preferences`, never read with string keys elsewhere.

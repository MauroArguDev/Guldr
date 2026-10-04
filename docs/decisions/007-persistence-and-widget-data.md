# 007 — Persistence and widget data access

- **Status:** Accepted
- **Date:** 2026-10-04

## Context

Guldr is local-first: all data lives on the device. The app and the widget extension run in different processes and both need the same numbers: balance, month income and expenses, budget usage.

FinTrack Pro had three problems here:
- it created the container with `fatalError` on failure;
- it wrote a JSON snapshot to `UserDefaults` for the widget, which duplicated the summary logic and could go stale;
- it had no schema versioning.

iCloud sync is planned for v1.1 ([roadmap](../ROADMAP.md)), so the v1.0 store has to be ready for CloudKit without enabling it.

## Decision

**One SwiftData store in the App Group container, opened read-write by the app and read-only by the widget.**

- **Location:** `<App Group container>/Library/Application Support/Guldr.store`. The group ID is read from the `AppGroupID` Info.plist key.
- **Factory:** `PersistenceController` in `GuldrCore` builds the container for three cases: app (read-write), widget (read-only, `allowsSave: false`) and in-memory (tests and previews). CloudKit is explicitly off: `cloudKitDatabase: .none`.
- **Failures:** creating the container throws a typed `PersistenceError` (`appGroupUnavailable`, `storeCreationFailed`). The app shows a calm error screen with a retry and a support link. It never crashes and never silently falls back to an in-memory store, which would make the user's data look lost.
- **Versioning:** the models are declared in `SchemaV1: VersionedSchema` with a `GuldrMigrationPlan` from day one, so every future change is a planned migration.
- **Widget freshness:** after any save that affects totals, the app calls one `DataChangeNotifier`, which asks WidgetKit to reload timelines (and later re-evaluates budget notifications). The widget computes its entry with the same `GuldrCore` calculations as the app.
- **CloudKit readiness:** models follow the CloudKit rules now (no unique attributes, optional relationships, default values). Enabling sync in v1.1 means changing the configuration and adding the iCloud capability, plus a new ADR.

## Alternatives considered

- **Snapshot in `UserDefaults` written by the app (FinTrack Pro's approach)** — tiny and fast for the widget, but it duplicates the summary format, goes stale if the app is killed before writing, and needs a required-reason API declaration. Rejected.
- **Snapshot file in the App Group** — same staleness and duplication problems, without the `UserDefaults` limits.
- **Store in the app's own container and no widget access** — the widget would only show placeholder data.

## Consequences

- One source of truth. The widget always shows what the store contains when its timeline is built.
- SQLite in WAL mode handles one writer (the app) and one reader (the widget) across processes. The widget never writes, which avoids conflicts.
- The widget's memory budget is small. Its queries fetch only the current month and use the same predicates as the app, which keeps them light at personal-finance scale. This is verified in the quality pass with 5,000 transactions.
- The widget does not need `UserDefaults` for data, so its privacy manifest stays minimal.
- Deleting all data (Settings) deletes the store files in the App Group and recreates an empty store.

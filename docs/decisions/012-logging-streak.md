# 012 — Logging streak

- **Status:** Accepted
- **Date:** 2026-10-23

## Context

The habit loop (v1 plan, [Habit loop design](../plan/v1.0.md#habit-loop-design)) rewards logging every day with a streak: a count of consecutive days with something logged, shown on Home, in the medium widget and in the daily reminder. Achievements (Phase 30) will read the same days.

A streak in a finance app has two traps:
- **Rewarding fake data.** Backfilling a month in one sitting, or logging nothing on purpose, must not look like daily logging.
- **Being punished by tidying up.** Deleting a duplicate transaction or travelling across time zones must not change days that were honestly logged.

The rules below also have to be computable from the store alone, so the widget and the app agree, and they must survive iCloud sync in v1.1.

## Decision

**A day counts once it is logged in time, and that fact is stored as a `LoggedDay` record. The streak, its freezes and its milestones are derived from those records by a pure function in `GuldrCore`.** Author's calls, 2026-10-23.

### What counts

A day **D** counts when either of these happens before the end of D + 1 (device time):
- a **new** transaction dated D is saved;
- D is marked **"No spending"**, which is offered for today, and for yesterday while it is still open.

So yesterday can be repaired this morning with a real entry, but a month backfilled at once doesn't count, and nothing can be marked ahead of time. Editing an existing transaction never logs a day.

### Storage

`LoggedDay` is a new SwiftData model, CloudKit-compatible:

| Property | Type | Meaning |
|---|---|---|
| `id` | `UUID` | Identity. |
| `dayKey` | `Int` | The local day as `yyyymmdd` (`LocalDay`), in the device's time zone at the moment it was logged. |
| `sourceRawValue` | `String` | `transaction` or `noSpending`. |
| `loggedAt` | `Date` | When it was recorded. |

All properties have defaults and there's no unique constraint, so a duplicate (from sync in v1.1) is harmless: days are read as a set.

**Why stored:**
- Deleting the transaction that logged a day doesn't unlog it.
- A day logged in Mexico City stays that day after a flight to Madrid.
- "No spending" has nowhere else to live.

**Schema and migration:**
- The model joins `SchemaV2`, and `GuldrMigrationPlan` gets a lightweight V1 → V2 stage.
- The unchanged models are shared by both versions.
- "Delete all data" deletes every `LoggedDay`.

**History:** existing data is imported once. When the app first opens with V2, every transaction whose `createdAt` falls on its own day or the next one is recorded as a logged day (flag in `AppSettings`). People who have been logging start with the streak they earned; backfilled history still doesn't count.

### The streak

`LoggingStreak` walks the logged days from the first one to today. Days up to two days ago are final. Yesterday is still repairable and today is open, so neither breaks anything yet.

- **Current length:** consecutive logged days in the current run. A day covered by a freeze keeps the run alive but doesn't add to it.
- **Freezes:**
  - one is earned for every 7 consecutive logged days, up to 2 held;
  - a final missed day spends one automatically;
  - with none left, the run ends;
  - they are derived from history, so there's no counter to drift, and they're never bought.
- **Best:** the longest run ever, kept when a run ends.
- **Day states**, for the calendar: logged (transaction), no spending, frozen, missed, repairable (yesterday), open (today).
- **Milestones:** 3, 7, 14, 30, 60, 100, 180 and 365 days. Each is celebrated once per run, keyed by the run's first day in `AppSettings`, so a new run can celebrate 7 again.

### Where it shows

- **Home:** a chip in the header.
- **Streak sheet:** the current and best streaks, 5 weeks of days, the freezes held, the next milestone and "No spending".
- **Medium widget:** one line; the count holds no amounts, so the lock doesn't hide it.
- **Daily reminder:** its copy names the streak from day 3 and mentions a repairable yesterday. "No spending today" is an action on the notification.

The action opens the app (`.foreground`): a notification action that runs in the background could launch the app without its scene, and writing to the store from there would bypass the main context the screens read. Opening briefly also shows the streak go up.

Settings › "Show streak" hides the chip, the widget line and the streak copy. Days are still recorded, so turning it back on loses nothing.

## Alternatives considered

- **Computing from `Transaction.date` and `createdAt` alone.** No new model, but deleting a transaction or changing the time zone rewrites the past, and "No spending" would still need storage.
- **Stored counters** (current streak, freezes). Simple to read, but they drift from the data on every edge case: deletion, a reset, sync merging two devices. Deriving them from the days can't drift.
- **Counting any day with a transaction dated on it.** Backfilling a month would build a month-long streak.
- **No repair, freezes only.** Logging last night's dinner this morning is the honest, common case; it shouldn't cost a freeze.
- **Background "No spending" action.** No app launch, but no safe way to write to the store the screens observe.

## Consequences

- The store's schema changes for the first time. The V1 → V2 stage is the first real migration and is tested by opening a V1 store from disk.
- The streak logic is pure and tested in `GuldrCore`: the repair window, freezes, DST, travel and a performance check over 5 years.
- Achievements (Phase 30, ADR 013) read the same `LoggedDay` records, for example for complete months.
- v1.1 sync merges `LoggedDay` records from several devices as a set.

# 013 — Achievements

- **Status:** Accepted
- **Date:** 2026-10-23

## Context

The habit loop (v1 plan, [Achievements and sharing](../plan/v1.0.md#achievements-and-sharing)) adds long-term goals on top of the streak ([ADR 012](012-logging-streak.md)): medals in bronze, silver and gold for consistency, a ledger kept up to date, budgets kept and money saved. Phase 31 will share them.

Achievements in a finance app have one trap the streak doesn't: a goal about **money** ("save 20 % this month") rewards **logging less**, since an expense that isn't logged makes the month look better. Achievements must never pay for incomplete data.

## Decision

**A fixed catalog in `GuldrCore`, evaluated by pure functions over the store. Money achievements only count complete months. An earned tier is stored once and kept.** Author's calls, 2026-10-23.

### Catalog

| Family | Achievement | Measures | Bronze / Silver / Gold |
|---|---|---|---|
| Consistency | Unbroken | The best streak ever | 7 / 30 / 100 days |
| Consistency | Days logged | Logged days in total | 30 / 100 / 365 |
| Ledger up to date | Complete month | Complete months | 1 / 3 / 12 |
| Ledger up to date | Bookkeeper | Transactions in the store | 100 / 500 / 1,000 |
| Budget | Within budget | Complete months with budgets, none over its limit | 1 / 3 / 12 |
| Budget | Steady hand | The longest run of consecutive months within budget | 2 / 3 / 6 |
| Reserve | Saver | The best savings rate in a complete month | 10 / 20 / 30 % |
| Reserve | In the black | The longest run of consecutive complete months saving more than zero | 3 / 6 / 12 |

The catalog is data (`AchievementCatalog`). Adding an achievement means one entry, its measure and its tests.

### Complete month

A month is complete when:
- it is over;
- at least **90 %** of its days, rounded up, are logged or covered by a freeze, as `LoggingStreak` counts them. A 30-day month needs 27.

Within budget, Steady hand, Saver and In the black only look at complete months.

### Evaluation

- `AchievementEvaluator` turns transactions, budgets and the logged days into one value per achievement. It uses the active currency only, and months in the device's time zone. Bookkeeper counts transactions in any currency.
- A tier is reached when the value meets its threshold.
- The evaluator is pure and cheap: transactions are grouped by month once, and 5,000 of them stay within the calculation budget.

### Kept forever

- An earned tier is stored as an `EarnedAchievement` record (achievement id, tier, date).
- The shown tier is the higher of the stored one and the one the data reaches now, so deleting a transaction never takes a medal away.
- "Delete all data" deletes the records.
- Records have defaults only and no unique constraint, so they stay CloudKit-compatible; duplicates collapse to the highest tier.
- The model joins `SchemaV3`, with a lightweight V2 → V3 stage.

### History and unlocks

- **History:** the first evaluation after installing the version records everything the history already earns, without a moment for each, so existing users start with their medals. A flag in `AppSettings` remembers it.
- **New tiers:** they're queued and shown one at a time in the app (a card like the streak's milestone), once no sheet and no streak milestone is showing.
- **Notifications:** none (author's call). Tiers earned while the app was closed, such as a month that ended, show on the next open.

### Medals

- A coin in the tier's color, with the achievement's SF Symbol in `OnGold`.
- Gold uses `GoldFill`; bronze and silver are new tokens, `TierBronze` and `TierSilver` (author's call, 2026-10-23).
- Unearned medals show on `Track` with their progress, never as a hidden "?".

## Alternatives considered

- **Money achievements on any month.** Simpler, and it would reward not logging expenses.
- **Recomputing medals from data every time, no storage.** Nothing to store, but deleting a duplicate transaction could take a medal back, which feels like punishment.
- **Storing achievements in `AppSettings`.** No migration, but they'd sit apart from the data they describe and wouldn't sync with it in v1.1.
- **Game Center achievements.** Native UI, but it ties a finance app to a gaming account and sends progress off the device.

## Consequences

- A second schema change in the same release cycle: V1 → V2 → V3 are all lightweight stages, tested from a V1 store.
- The catalog and evaluator are covered by tests in `GuldrCore`.
- Phase 31's share cards read the same catalog and the earned records.

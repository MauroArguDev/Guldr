# 008 — Categories and month keys

- **Status:** Accepted; category colors superseded by [009](009-category-color-palette.md)
- **Date:** 2026-10-04

## Context

**Categories.** FinTrack Pro defined each category with an emoji and a hex color. That clashes with Guldr's design system: icons are SF Symbols in icon chips, colors come only from the `GuldrColors` catalog, and hex in code is forbidden. Its seeding used `@Attribute(.unique)`, which CloudKit does not allow. Deleting a category orphaned the history attached to it.

**Months.** Budgets are monthly. FinTrack Pro keyed them with a `"yyyy-MM"` string built from `Date.now`, and computed "this month" separately in each view model.

## Decision

### Categories

- **Appearance:** a category has a `symbolName` (SF Symbol) and a `colorToken` that is one of `chart1`…`chart7` from `GuldrColors`. The picker shows only these seven colors, so every category works in both appearances and in the analytics donut.
- **Kinds:** each category is for expenses or for income.
- **Default set**, seeded on first launch:
  - expenses: Food, Transport, Housing, Health, Shopping, Entertainment, Education, Other;
  - income: Salary, Freelance, Other income.
- **Stable keys:** each seeded category has a stable `systemKey` (for example, `food`). Seeding checks these keys, so running it twice never duplicates anything, without needing unique attributes. Names of seeded categories are localized from their key until the user renames them.
- **Archive, don't delete:** archived categories disappear from pickers and budgets but keep their past transactions and totals. A category with no transactions can be deleted for good.
- **Custom categories:** created in Settings with a name, a symbol and a color token, and reorderable through `sortOrder`.

### Month keys

- `YearMonth` (in `GuldrCore`) is the only way code talks about a month. It is stored as an integer `year * 100 + month` (for example, `202610`) and converts to a date range in the user's current calendar and time zone.
- `Budget.yearMonth` stores that integer.
- Transactions store only their `date`. Which month a transaction belongs to is computed when querying, through `YearMonth.dateRange`. There is no duplicated month field that could drift when a date is edited.

## Alternatives considered

- **Emoji and free hex colors** — maximum freedom, but breaks the design system and dark mode contrast.
- **Deleting categories with cascade or nullify** — either loses history or leaves transactions without a category in reports.
- **Month as a `"yyyy-MM"` string** — works, but compares as text and invites parsing in many places.
- **Month as a `Date` (start of month)** — depends on the time zone in which it was created and is easy to compare wrongly.
- **Storing `yearMonth` on each transaction** — faster grouping, but a second source of truth that must be kept in sync with `date`.

## Consequences

- Categories always look right in light, dark and tinted widgets, and the donut colors match the list icons.
- Reports stay correct after archiving.
- A transaction made late at night while traveling belongs to the month of the time zone the user is in when viewing it. This is acceptable for a personal app and documented here.
- Month navigation, budget lookup and summaries share one tested type, `YearMonth`, instead of ad hoc date math.

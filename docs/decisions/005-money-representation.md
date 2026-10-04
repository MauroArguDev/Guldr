# 005 — Money representation

- **Status:** Accepted
- **Date:** 2026-10-04

## Context

Guldr stores, adds and compares amounts of money. FinTrack Pro used `Double`, which cannot represent most decimal fractions exactly (`0.1 + 0.2 != 0.3`), and it had no currency on transactions: `USD` was hard-coded in the formatter.

The representation has to be exact, cheap to sum over thousands of transactions, easy to filter in SwiftData predicates, and safe to sync with CloudKit in v1.1. Currencies differ in their minor units: two decimals for USD, EUR or MXN, none for JPY, three for KWD.

## Decision

**Store amounts as integer minor units with an ISO 4217 currency code, and compute with a `Money` value type.**

- `Transaction.amountMinorUnits: Int64` — the absolute value in the currency's smallest unit (`$12.34` → `1234`). The sign comes from `kind` (expense or income), never from the number.
- `Transaction.currencyCode: String` — ISO 4217 (`"USD"`, `"MXN"`, `"EUR"`). `Budget` stores the same pair.
- `Money` (in `GuldrCore`) wraps `minorUnits: Int64` and `currencyCode`. Arithmetic is only allowed between equal currencies and throws a typed error otherwise. `Decimal` is used only at the edges: parsing keypad input and formatting text.
- The number of minor units for a currency comes from Foundation's currency formatting rules, never from a hard-coded table (checked: USD 2, JPY 0, KWD 3).

**One active currency in v1.** The user picks a currency at first launch, defaulting to the device locale. New transactions use it. Totals, budgets, charts and widgets include only transactions in the active currency. The list still shows every transaction with its own currency. Changing the active currency in Settings is allowed, with a warning that totals only include transactions in the new currency. Converting between currencies is out of scope.

## Alternatives considered

- **`Double`** — rejected. Rounding errors accumulate in sums and comparisons, which is unacceptable for a finance app.
- **`Decimal` stored by SwiftData** — exact and convenient in code, but it is a Foundation struct persisted through Codable support. Predicates and sums on it are less straightforward than on integers, and its CloudKit mapping is one more thing to verify for v1.1. Integers have none of these questions.
- **Several currencies added together with exchange rates** — needs a rate source (network, privacy, staleness) and makes every total ambiguous. Not worth it for a personal, local-first v1.

## Consequences

- Sums and comparisons are exact and fast. A predicate such as "expenses this month" is a plain integer filter.
- Every conversion between minor units and display text goes through `Money` and `MoneyFormatter`. They are the only places that know about decimals, and they are fully unit-tested.
- `Int64` minor units cover any realistic personal balance: the maximum is about 92 quadrillion in minor units.
- Changing the active currency does not rewrite history. If multi-currency totals come later, the data already carries the currency of every amount.

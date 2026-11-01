# 016 — Starting balance: a setting per currency, set from what the user has today

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

Home's balance is the all-time net: every income minus every expense in the active currency (`MonthSummary`). A new user starts at zero, so the balance goes negative with the first expense and matches nothing real. [ADR 015](015-gold-accounts-cards-receipts.md) adds a free starting balance in v1.0's build 2 (v1 plan, 34.12). This ADR answers three questions:

- where the starting balance is stored;
- what it means for someone who has already been logging for weeks;
- what counts it.

## Decision

The author's calls, 2026-11-01:

- **A setting, not a model.** It's stored in the App Group's `UserDefaults` through `AppSettings` ([ADR 010](010-app-settings-storage.md)), next to the active currency, as a dictionary from currency code to minor units. There's one value per currency, since every amount carries its currency ([ADR 005](005-money-representation.md)).
- **The user always enters what they have today,** zero or more, never a negative amount.
  - **Stored value:** Guldr stores the entered amount minus the net of the transactions already logged in that currency.
    - For a new user it's simply the amount.
    - For someone who has been logging, Home shows exactly what they typed.
  - **It can be negative:** the stored value is below zero when more income was logged than is left. The user never sees it.
- **Not a transaction.** Only the balance includes it: the balance is the starting balance plus income minus expenses. These ignore it:
  - the month's income and expenses, and the savings rate;
  - analytics and budgets;
  - achievements, the monthly recap and the streak;
  - the CSV.
- **Where it's asked:**
  - a second onboarding screen;
  - once on Home, for users who finished onboarding before this version;
  - Settings › Adjust balance at any time.

  **Delete all data** clears it with the other settings.

## Alternatives considered

- **A minimal `Account` model** (SchemaV4): it would sync with iCloud by itself and become the first account directly. But it moves the account design ADR 015 leaves for v1.1 into a TestFlight build, with a schema migration.
- **An income transaction named "Starting balance":** it would inflate the month's income, the savings rate, money achievements, analytics and the CSV.
- **Asking what the user had before their first transaction:** someone who has logged for weeks can't know it. What they have today is on their banking app.
- **Negative amounts from the keypad:** debts are modeled properly with credit cards in v1.2.

## Consequences

- **Overflow:** `MonthSummary` adds the starting balance into the balance's tally, so an overflow still throws instead of wrapping.
- **The widget:** it already reads `AppSettings`, so its balance includes the starting balance. Changing it reloads the widget's timeline, as saving a transaction does.
- **Editing old transactions:** the starting balance stays fixed. Editing or deleting an old transaction still changes the balance, as before.
- **Changing currency:** a currency without a value starts from zero. Settings › Adjust balance sets it for the active currency.
- **v1.1:** `UserDefaults` doesn't sync, so the iCloud plan must carry the starting balances, either through iCloud's key-value store or by moving them into the account model, and decide what happens when two devices disagree.
- **v1.2:** each currency's starting balance becomes the opening balance of its first account, in a one-time migration.

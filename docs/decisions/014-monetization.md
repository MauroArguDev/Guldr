# 014 — Monetization: a one-time Gold unlock and optional tips

- **Status:** Accepted
- **Date:** 2026-10-23

## Context

v1.0 and v1.1 are free, with no in-app purchases. Guldr should eventually earn something, but the author's goal is visibility and reputation, not revenue: income only needs to be modest, and the model must never cost the app its reviews or its privacy promise.

Three facts shape the choice:

- **No recurring costs.** There are no servers, and iCloud sync (v1.1) uses CloudKit's private database, which counts against the user's own iCloud storage, not the developer's.
- **The audience.** People who pick a local-first, no-account finance app tend to dislike subscriptions and ads, and reviews of small apps punish both.
- **The privacy label.** Guldr ships as **Data Not Collected**. Ads or a purchase server would change that.

## Decision

**The core stays free forever. From v1.2, Guldr Gold is a one-time, lifetime unlock, plus optional tips. No subscription, no ads.** Author's call, 2026-10-23.

### Products

| Product | StoreKit type | Starting price |
|---|---|---|
| Guldr Gold | Non-consumable, Family Sharing on | about $4.99 USD |
| Tips | Three consumables | about $0.99, $2.99 and $4.99 USD |

Final prices are set in the v1.2 plan; Apple derives the regional ones.

### Always free

- Adding, editing, searching and categorizing transactions, with no limits.
- Budgets, Home, the basic analytics, the streak and its freezes.
- iCloud sync, CSV export and CSV import.
- Face ID lock, hiding amounts, accessibility and both languages.
- Share cards: they are how people discover Guldr.
- **Anything that was free in an earlier version stays free.** Nothing is moved behind Gold.

### Gold

Additions, never limits on the free app: alternate app icons, savings goals, PDF reports, advanced analytics (custom ranges, year over year, trends per category), the large widget and extra Lock Screen styles, and a **Patron** medal. Any tip also earns the Patron medal, so a tip gets something back.

### Timing

Gold ships in v1.2, never in the same release as iCloud sync, so paying is never confused with keeping data safe.

## Alternatives considered

- **Subscription** — no recurring cost justifies it, and it is the model this audience reviews worst.
- **Paid upfront** — fewer downloads, which works against the visibility goal, and no way to try the app first.
- **Ads** — they need tracking or at least a third-party SDK, which breaks the privacy label.
- **Tips only** — few people tip without getting something back; Gold gives a clear reason to pay.
- **Gold in v1.1, with sync** — it would look like charging for the backup.

## Consequences

- StoreKit 2 verifies purchases on the device (`Transaction.currentEntitlements`, signed transactions). There is no server and no receipt validation endpoint, so the app still makes no network requests of its own.
- Purchases are processed by Apple and Guldr receives no user data, so the label is expected to stay **Data Not Collected**. The App Privacy answers are reviewed again when v1.2 ships.
- Gold checks live in one entitlement service behind a protocol, tested with fakes and a StoreKit configuration file, so no view decides access on its own.
- Family Sharing cannot be turned off for a product once it is on. It is a one-way choice made at creation.
- The Patron medal is not derived from the store, unlike every achievement in [ADR 013](013-achievements.md). The v1.2 plan decides how it is stored and shown.
- App Store Connect setup belongs to the author: the Paid Applications Agreement, banking and tax forms, and enrollment in the App Store Small Business Program (15 % commission instead of 30 %).
- The always-free list is a public promise. Changing it needs a new ADR that supersedes this one.

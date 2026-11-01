# Roadmap

What Guldr ships, in what order, and what it deliberately does not do.

## v1.0 — Local-first MVP

Step-by-step delivery, from the data layer to the App Store: [`plan/v1.0.md`](plan/v1.0.md).

### Foundations
- [x] Project bootstrap: CI, widget target, App Group, design system, icon, privacy manifest, localization, SwiftLint ([runbook](setup/BOOTSTRAP.md))

### Data
- [x] SwiftData models for transactions, categories and budgets, CloudKit-compatible, with `currencyCode` on every transaction
- [x] Shared `ModelContainer` in the App Group, readable by the widget

### Features
- [x] **Transactions:** add, edit and delete income and expenses; categories; searchable, grouped list
- [x] **Dashboard:** balance, monthly income and expenses, recent transactions
- [x] **Budgets:** monthly budget per category with progress and over-budget state
- [x] **Charts:** spending by category and monthly trend with Swift Charts
- [x] **Widgets:** small and medium home screen widgets
- [x] **Face ID lock** on launch and when returning from the background
- [x] **Budget notifications:** local alerts when a budget is close to or over its limit
- [x] **CSV export** of transactions
- [x] **Daily reminder:** one opt-in local notification a day, skipped once the day is logged
- [x] **Logging streak:** consecutive logged days with repair, earned freezes and milestones, on Home and in the widget
- [x] **Achievements:** bronze, silver and gold coins for consistency, complete months, budgets and savings; money achievements only count complete months
- [x] **Share cards and monthly recap:** an image of an achievement or of the month, with no amounts
- [ ] **Starting balance:** what the user has today, asked in onboarding and once on Home for existing users, so the balance doesn't start from zero. An opening balance, not a transaction: income, the savings rate and achievements ignore it ([ADR 015](decisions/015-gold-accounts-cards-receipts.md))

### Quality
- [x] English and Spanish
- [x] Accessibility: VoiceOver, Dynamic Type, Reduce Motion
- [ ] Release checklist from the [Definition of Done](WORKFLOW.md#release)

### Release
- [ ] TestFlight (requires the paid Apple Developer Program)
- [ ] App Store submission

## v1.1 — Your data, safe on every device

One theme: nothing the user logs can be lost, and it follows them to every iPhone they own. Planned after the v1.0 launch in its own plan document, with a new ADR for sync.

### Sync and backup
- [ ] **iCloud sync** through CloudKit's private database (`iCloud.com.argudev.guldr`). The v1.0 models are already CloudKit-compatible ([ADR 007](decisions/007-persistence-and-widget-data.md)), so there is no data migration and existing data uploads when sync turns on. The work is what a second device brings:
  - merge the duplicate default categories each device seeds before the first sync arrives, moving their transactions and budgets to one survivor;
  - merge duplicate budgets for the same category and month;
  - decide which settings follow the iCloud account (active currency, onboarding) and which stay per device (Face ID lock, reminder time);
  - refresh the widget, budget alerts and streak when remote changes arrive;
  - show the sync state, and handle iCloud being off, full or switched to another account;
  - warn that **Delete all data** erases every device;
  - design the models planned for v1.2 (accounts, credit cards, transfers, savings goals) before the CloudKit schema is deployed to production: after that, fields can only be added, never renamed or removed.
- [ ] **CSV import** of Guldr's own export format: a backup and restore that doesn't depend on iCloud.
- [ ] Privacy copy updated (README, privacy policy, App Store text): data stays on the device and in the user's own iCloud. The App Store label stays **Data Not Collected**.

### Features
- [ ] **Multi-currency notice:** Home says when transactions in other currencies are left out of the totals, for example "3 transactions in EUR aren't included".
- [ ] **Recurring transactions and subscriptions:** rent, subscriptions and salary, created when they are due, editable one at a time or for the whole series. Subscriptions get a reminder before each charge and a yearly total. Entered and removed by hand; nothing is detected automatically. Free ([ADR 015](decisions/015-gold-accounts-cards-receipts.md)).

### Launch follow-up
- [ ] Fixes from TestFlight, Xcode Organizer (crashes, energy) and App Store reviews.

### Candidates, if time allows (one or two)
- [ ] Interactive widget: **No spending today** and a quick add, through App Intents.
- [ ] Lock Screen widgets for the streak or the month's spending, respecting **Hide amounts in widgets**.

## v1.2 — Guldr Gold

Monetization arrives here, never in the same release as sync, so paying is never confused with keeping data safe. The model and the list of what stays free forever: [ADR 015](decisions/015-gold-accounts-cards-receipts.md), which supersedes [ADR 014](decisions/014-monetization.md).

### Monetization
- [ ] **Guldr Gold:** a one-time, lifetime unlock (non-consumable, Family Sharing on), around $4.99 USD.
- [ ] **Tips:** three optional consumable tips, around $0.99, $2.99 and $4.99 USD.
- [ ] StoreKit 2 with on-device verification and no server; a StoreKit configuration file for tests.
- [ ] App Store Connect (author): Paid Applications Agreement, banking and tax forms, App Store Small Business Program.

### Free for everyone
- [ ] **Two accounts** (for example cash and a bank account), so the balance matches something real. The v1.0 starting balance becomes the first account's opening balance.
- [ ] **Transfers** between accounts, which are neither income nor expenses.
- [ ] **Bank statement import** from CSV, with column mapping.

### Gold
- [ ] **Unlimited accounts.** If Gold ends, extra accounts stay visible and counted; only adding to them needs Gold.
- [ ] **Credit cards:** statement closing day, payment due date, the payment that avoids interest and a reminder before the due date. Paying the card is a transfer, not an expense.
- [ ] Alternate app icons (gold, stone, white).
- [ ] Savings goals with progress.
- [ ] PDF reports, monthly and yearly.
- [ ] Advanced analytics: custom date ranges, year over year, trends per category.
- [ ] Extra widgets: the large size and more Lock Screen styles. Small and medium stay free.
- [ ] **Patron** medal in Achievements, also earned by any tip.

## v1.3 — Private AI

### Gold
- [ ] **Receipt scanning:**
  - a photo of a receipt fills the add sheet with the total, a title, the date and a suggested category, and the user confirms;
  - the suggested category learns from the user's corrections;
  - runs on the device with Vision and Foundation Models, and photos are never stored;
  - full extraction needs an iPhone with Apple Intelligence; other iPhones read the text and a heuristic total, and the Gold screen says so before the purchase.

## Later

Ideas, not commitments:

- Apple Watch companion
- Interest-free installments on credit cards (*meses sin intereses*)
- Itemized receipts split across categories
- Open-source `GuldrCore` under a permissive license, with the app itself staying closed

## Out of scope

| Not doing | Why |
|---|---|
| Siri and App Shortcuts | Adds surface without improving the core flow. App Intents are used only where widgets need them. |
| iPad and Mac | iPhone-first; a good iPad layout is its own project. |
| Languages beyond English and Spanish | Two languages done well beat several done poorly. |
| Paid streak freezes, leaderboards, social feeds | The streak and achievements exist to keep the user's own data complete; buying or comparing them would reward the game instead of the logging. Sharing is a user-made image with no amounts, not a feed. |
| Networking, user accounts, third-party analytics | Local-first and private by design: data never leaves the device (iCloud in v1.1 stays in the user's own account). |
| Bank connections and automatic detection of subscriptions | They need networking and the user's bank credentials. Everything is entered by hand or imported from CSV. |
| Exchange rates from a network API | It would break "no networking" and the Data Not Collected label. Totals stay per currency, and v1.1 says what they leave out. |
| Subscriptions | Guldr has no recurring costs to pass on: no servers, and iCloud sync uses the user's own storage. A one-time unlock and optional tips instead ([ADR 015](decisions/015-gold-accounts-cards-receipts.md)). |
| Paying for data, sync, export, import, privacy, accessibility or the streak | Keeping and protecting your own data is never a paid feature ([ADR 015](decisions/015-gold-accounts-cards-receipts.md)). |

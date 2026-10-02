# Roadmap

What Guldr ships, in what order, and what it deliberately does not do.

## v1.0 — Local-first MVP

### Foundations
- [ ] Project bootstrap: CI, widget target, App Group, design system, icon, privacy manifest, localization, SwiftLint ([runbook](setup/BOOTSTRAP.md))

### Data
- [ ] SwiftData models for transactions, categories and budgets, CloudKit-compatible, with `currencyCode` on every transaction
- [ ] Shared `ModelContainer` in the App Group, readable by the widget

### Features
- [ ] **Transactions:** add, edit and delete income and expenses; categories; searchable, grouped list
- [ ] **Dashboard:** balance, monthly income and expenses, recent transactions
- [ ] **Budgets:** monthly budget per category with progress and over-budget state
- [ ] **Charts:** spending by category and monthly trend with Swift Charts
- [ ] **Widgets:** small and medium home screen widgets
- [ ] **Face ID lock** on launch and when returning from the background
- [ ] **Budget notifications:** local alerts when a budget is close to or over its limit
- [ ] **CSV export** of transactions

### Quality
- [ ] English and Spanish
- [ ] Accessibility: VoiceOver, Dynamic Type, Reduce Motion
- [ ] Release checklist from the [Definition of Done](WORKFLOW.md#release)

### Release
- [ ] TestFlight (requires the paid Apple Developer Program)
- [ ] App Store submission

## v1.1 — iCloud sync

- [ ] Sync through CloudKit (`iCloud.com.argudev.guldr`). The v1.0 models are already CloudKit-compatible so this is a capability change, not a migration.

## Later

Ideas, not commitments:

- Import bank statements from CSV
- Savings goals with progress
- Recurring transactions and subscriptions
- Multiple accounts (cash, bank, card)
- PDF reports
- Apple Watch companion

## Out of scope

| Not doing | Why |
|---|---|
| Siri and App Shortcuts | Adds surface without improving the core flow. App Intents are used only where widgets need them. |
| iPad and Mac | iPhone-first; a good iPad layout is its own project. |
| Languages beyond English and Spanish | Two languages done well beat several done poorly. |
| Networking, accounts, third-party analytics | Local-first and private by design: data never leaves the device (iCloud in v1.1 stays in the user's own account). |

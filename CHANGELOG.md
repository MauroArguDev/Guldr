# Changelog

Notable changes to Guldr, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [semantic versioning](https://semver.org) (see [WORKFLOW.md › Versioning](docs/WORKFLOW.md#versioning)).

## [1.0.0] — Unreleased

The first release: a local-first personal finance app for iPhone, on iOS 26 and later.

### Money
- **Transactions:** add, edit and delete income and expenses, with a keypad-first add sheet, a description and a date. The list is grouped by day, with search and an all / income / expenses filter.
- **Categories:** a default set, plus your own with a name, a symbol and a color; a category in use is archived instead of lost.
- **Currencies:** every transaction keeps its currency. Totals, budgets and charts use the active one, which you can change at any time.
- **Home:** the balance; this month's income, expenses and savings rate; the budget at a glance; recent transactions.
- **Budgets:** a monthly limit per category with a ring and per-category progress, over-budget alerts, and last month's budgets copied in one tap.
- **Analytics:** income against expenses over 1, 3, 6 or 12 months, and spending by category, with Audio Graphs for VoiceOver.
- **CSV export** of all transactions or a date range, ready for any spreadsheet.

### Habit
- **Daily reminder:** one opt-in notification a day at your time, skipped once the day is logged. You can act on it directly with **Add expense** or **No spending today**.
- **Logging streak:**
  - days in a row on Home and in the medium widget, with a five-week calendar;
  - a missed day can be repaired until the end of the next day;
  - freezes are earned every 7 days, up to 2;
  - milestones from 3 to 365 days.
- **Achievements:** eight achievements in bronze, silver and gold for consistency, an up-to-date ledger, budgets kept and money saved. Money achievements only count complete months, and earned medals are kept.
- **Share cards:**
  - an image of an achievement or of a month in review, for Stories (9:16) or posts (1:1);
  - never shows an amount.

### Privacy
- Everything stays on your iPhone: no account, no servers, no analytics, no tracking. The App Store label is **Data Not Collected**. See the [privacy policy](docs/PRIVACY.md).
- **Face ID lock** when Guldr opens or comes back, immediately or after 1, 5 or 15 minutes. It also covers the app switcher's snapshot and keeps amounts out of budget alerts.
- **Hide amounts in widgets**, independent of the lock.

### Everywhere
- **Widgets:** small and medium Home Screen widgets with the balance, the month and the streak.
- **Languages:** English and Spanish.
- **Accessibility:**
  - VoiceOver labels and actions throughout;
  - Dynamic Type up to the largest accessibility size;
  - Reduce Motion respected;
  - text contrast that meets WCAG AA in light and dark.

[1.0.0]: https://github.com/MauroArguDev/Guldr/releases/tag/v1.0.0

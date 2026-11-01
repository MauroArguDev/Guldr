# 015 — Gold grows: more accounts, credit cards and receipt scanning

- **Status:** Accepted
- **Date:** 2026-11-01
- **Supersedes:** [014](014-monetization.md)

## Context

[ADR 014](014-monetization.md) made Guldr Gold a one-time unlock, from v1.2, that only **adds** things: icons, savings goals, reports, advanced analytics and extra widgets. The roadmap put multiple accounts in the free app.

Planning v1.1 to v1.3, the author proposed five features on 2026-11-01:

1. A starting balance, so Home doesn't start from zero.
2. Multiple bank accounts.
3. Credit cards with statement and payment dates.
4. Subscriptions with reminders, entered by hand.
5. Receipt scanning that reads the total, a title and a category.

The goal hasn't changed: visibility and reputation first, modest income second. The free app must stay generous enough to earn reviews and recommendations. Gold, though, was mostly cosmetic, a weak reason to pay. Cards and receipt scanning are the features people would pay for. Limiting accounts breaks 014's "additions, never limits" rule, so this ADR replaces it.

## Decision

**Everything in ADR 014 stands, except the free and Gold lists below and one new rule for limits.** These things don't change:

- a lifetime Gold unlock with Family Sharing, plus three tips;
- no subscription and no ads;
- Gold from v1.2, never in the same release as sync;
- on-device StoreKit 2.

Author's call, 2026-11-01.

### Always free

Everything 014 listed, plus:

- **Starting balance** (v1.0): what the user has today, asked in onboarding and once on Home for existing users. It's an opening balance, not a transaction.
- **Recurring transactions and subscriptions** (v1.1):
  - entered and removed by hand, never detected;
  - a reminder before each charge and a yearly total.
- **Up to two accounts** (v1.2), for example cash and a bank account, with **transfers** between them.

### Gold

Everything 014 listed, plus:

- **Unlimited accounts** (v1.2).
- **Credit cards** (v1.2):
  - the statement closing day and the payment due date;
  - the payment that avoids interest, which is the balance at the last statement;
  - a reminder before the due date.
- **Receipt scanning** (v1.3):
  - a photo of a receipt fills the add sheet with the total, a title, the date and a suggested category, and the user confirms;
  - it runs on the device with Vision and Foundation Models;
  - the suggested category learns from the user's corrections.

### Limits

- **A limit only applies to a feature that is new when it ships,** never to one that was free before. 014's promise stands: nothing free moves behind Gold.
- **Data past a limit is never hidden or deleted.** If Gold ends (a refund, or leaving Family Sharing), extra accounts and cards stay visible and counted in every total. Only adding new ones, or logging to them, needs Gold again.
- **The Gold screen appears only when the user reaches for a Gold feature:** a third account, a credit card or the scan button. There are no prompts at launch and no reminders to buy.
- **Receipt scanning states what the device can do.**
  - Foundation Models needs an iPhone with Apple Intelligence.
  - Other iPhones read only the text and a heuristic total.
  - The Gold screen says so before the purchase.

## Alternatives considered

- **One free account** (the author's first idea): the free app would stay what v1.0 already is. Most people need cash and a bank account from day one, so the limit would read as a penalty and cost reviews.
- **Unlimited free accounts** (014 and the earlier roadmap): Gold would rest on icons and reports, too little to justify paying.
- **Free receipt scanning:** it's a convenience, not keeping data safe. It's also the most visible reason to buy Gold.
- **Subscriptions in Gold:** subscription tracking is one of the most searched features in the category. Keeping it free brings downloads, which serves the visibility goal.
- **OCR or AI in the cloud:** it would break "no networking" and the **Data Not Collected** label. Running on the device is the selling point: AI that never sees your data, and no server cost that would justify a subscription.
- **Every Gold feature in v1.2:** one release too large to finish and test well. Cards (v1.2) and receipts (v1.3) each get their own launch.

## Consequences

- **v1.1 designs the account model before the CloudKit schema is deployed to production,** including the fields cards need. After that, fields can only be added.
- **The v1.0 starting balance becomes the opening balance of the first account** in v1.2. The v1.0 plan chooses where it's stored with this in mind.
- **Transfers and card payments are neither income nor expenses.** In v1.2 they stay out of:
  - the month's totals and the savings rate;
  - budgets and analytics;
  - money achievements and the CSV's income and expense columns.
- **The entitlement service from 014 also decides the account limit.** Tests cover reaching the limit and Gold ending.
- **Receipt scanning:**
  - **Camera permission:** it needs `NSCameraUsageDescription`, which the author adds in Xcode.
  - **Images:** photos are read and discarded, never stored.
  - **App Privacy:** the answers are checked again for v1.3.
- **Notifications:** subscription and card reminders share iOS's limit of 64 pending local notifications with the budget alerts and the daily reminder. Only the nearest ones are scheduled.
- **Prices:** set in the v1.2 plan, as in 014.
- **Changing these lists** needs a new ADR that supersedes this one.

# 004 — Rewrite instead of evolving FinTrack Pro

- **Status:** Accepted
- **Date:** 2026-10-01

## Context

Guldr replaces FinTrack Pro, a personal finance app built between May and June 2026 (34 commits). FinTrack Pro reached a working MVP — dashboard, transactions, budgets, charts, Face ID, widget and Siri intents — and taught a lot, but several of its foundations conflict with where the product is going:

- **Data model:** amounts stored as `Double`, `@Attribute(.unique)` on every model (incompatible with CloudKit), no currency stored per transaction and `USD` hard-coded in the formatter.
- **Error handling:** `fatalError` when the `ModelContainer` cannot be created.
- **Project setup:** Swift 5 language mode, iPhone and iPad targets, iOS 17.6 minimum, identifiers tied to the old name (`com.argudev.FinTrackPro`).
- **Scope:** Siri intents and a third language (French) added surface without improving the core flow.
- **Process:** a `develop` branch plus long-lived `feature/*` branches, no CI, and project documentation kept out of the repository.
- **Identity:** a new name and a new design system (warm minimalism, one gold accent, system typography) replace the old visual language and its four custom font families.

## Decision

Start a new project, Guldr, from an empty Xcode template and rebuild the features one by one. FinTrack Pro stays in `~/Documents/Portfolio/Old_FinTrackPro` as read-only reference: each feature is ported by reading the old code, writing down what changes and why, rewriting it, testing it and opening a PR.

## Alternatives considered

- **Refactor FinTrack Pro in place** — renaming targets and bundle IDs, migrating the data model away from `@Attribute(.unique)`, dropping iPad and Siri and switching to Swift 6 all at once would touch nearly every file. The history would mix two products and the result would be harder to review than a clean start.
- **Fork the repository** — keeps old history, but carries over the same structure, identifiers and branch model that the rewrite is meant to leave behind.

## Consequences

- Constraints that were retrofits in FinTrack Pro are rules from the first commit: CloudKit-compatible models, `currencyCode` on every transaction, typed errors instead of `fatalError`, Swift 6 concurrency, iPhone only, English and Spanish.
- Trunk-based workflow: short-lived branches, pull requests with CI, rebase merges into a protected `main`. No `develop` branch.
- Documentation, ADRs and the bootstrap runbook are public, so the reasoning behind the code is part of the portfolio.
- Out of scope by decision: Siri and App Shortcuts, iPad, French (see the [roadmap](../ROADMAP.md)).
- The cost is time: features that already worked in FinTrack Pro are rebuilt instead of reused. The old code shortens that work but is never copied without review.

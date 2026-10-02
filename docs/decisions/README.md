# Architecture decisions

Each file records one decision that shapes the project: the context, what was chosen, the alternatives and the consequences. They explain *why* the code looks the way it does.

## How to add one

1. Copy [`000-template.md`](000-template.md) to `NNN-short-title.md`, using the next free number.
2. Fill it in with status **Proposed** and open it in a PR, alone or with the change it justifies.
3. Set the status to **Accepted** before merging and add it to the index below.
4. Accepted ADRs are not rewritten. If a decision changes, write a new ADR and mark the old one **Superseded by NNN**.

## Index

| # | Decision | Status |
|---|---|---|
| [001](001-ios-26-minimum.md) | iOS 26 as the minimum deployment target | Accepted |
| [002](002-identifiers.md) | App identifiers | Accepted |
| [003](003-concurrency-defaults.md) | Swift concurrency defaults | Accepted |
| [004](004-rewrite-from-fintrack-pro.md) | Rewrite instead of evolving FinTrack Pro | Accepted |

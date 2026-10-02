# 003 — Swift concurrency defaults

- **Status:** Accepted
- **Date:** 2026-10-01

## Context

The Xcode 27 app template enables the newer Swift concurrency settings by default. Recorded from the app target's build settings on 2026-10-01:

| Setting | Value |
|---|---|
| `SWIFT_VERSION` | `6.0` |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` |
| `SWIFT_APPROACHABLE_CONCURRENCY` | `YES` |
| `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` | `YES` |
| `SWIFT_STRICT_CONCURRENCY` | unset (Swift 6 mode implies `complete`) |

The test targets were created with Swift 5.0 and were moved to 6.0 during project setup so every target compiles under the same rules.

Guldr is a UI-driven app: views, view models and the SwiftData `mainContext` all live on the main actor. Real background work is limited (CSV export, widget timeline reloads, possibly large aggregations for charts).

## Decision

Keep all the defaults, in every target:

- **Swift 6 language mode** — data races are compile-time errors, not warnings.
- **`MainActor` default isolation** — code is main-actor isolated unless it opts out. This matches where most of the app's code runs and removes `@MainActor` annotations from every view model.
- **Approachable Concurrency** — `nonisolated async` functions run on the caller's actor by default (`nonisolated(nonsending)`), and conformances can be inferred as isolated. Work only leaves the main actor when it is explicitly marked `@concurrent`.
- **Member import visibility** — a file must import the module whose members it uses, which keeps dependencies explicit.

## Alternatives considered

- **Swift 5 mode with strict concurrency warnings** — easier to start, but warnings get ignored and become a migration later. Starting clean costs little in a new codebase.
- **`nonisolated` default isolation** — the classic model, but every view model and UI-facing type would need `@MainActor`, and forgetting one is a common source of errors.

## Consequences

- Background work is explicit and easy to spot in review: it is the code marked `@concurrent` or `nonisolated`.
- Pure value types and helpers used off the main actor (formatters, calculation engines, export) must be marked `nonisolated` so they can be called from anywhere.
- The widget extension (Phase 3) must use the same settings; verify after creating the target.
- `@unchecked Sendable` is never used without a comment explaining why the type is safe.

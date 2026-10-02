# 002 — App identifiers

- **Status:** Accepted
- **Date:** 2026-10-01

## Context

Bundle identifiers, App Groups and iCloud containers are effectively permanent: once an app ships to the App Store its bundle ID cannot change, and data stored in an App Group or iCloud container is tied to that exact identifier. They need to be decided once, before the first target is signed.

Apple also imposes structure: an app extension's bundle ID must be prefixed by its host app's ID, App Groups start with `group.` and iCloud containers with `iCloud.`.

## Decision

Use the developer's reverse-DNS prefix `com.argudev` and derive every identifier from the app's bundle ID:

| Identifier | Value |
|---|---|
| App bundle ID | `com.argudev.guldr` |
| Widget bundle ID | `com.argudev.guldr.widget` |
| App Group | `group.com.argudev.guldr` |
| iCloud container (v1.1) | `iCloud.com.argudev.guldr` |

All lowercase. Code reads the App Group from the `AppGroupID` Info.plist key, set from `APP_GROUP_ID` in `Config/Shared.xcconfig`, so the string is defined in exactly one place.

## Alternatives considered

- **A personal-name prefix (`com.mauricioargumedo`)** — works, but `argudev` is the publishing brand used across GitHub and portfolio projects, so it groups all apps under one recognizable prefix.
- **Mixed case (`com.argudev.Guldr`, Xcode's default)** — identifiers are case-sensitive in some places and not in others; lowercase avoids subtle mismatches between targets, entitlements and the portal.

## Consequences

- Every future app by the same developer follows the same `com.argudev.<app>` pattern.
- The iCloud container is reserved now but **not** added in v1.0: enabling the iCloud capability would make SwiftData sync automatically before the models and UX are ready for it.
- Test targets keep Xcode's defaults (`com.argudev.GuldrTests`, `com.argudev.GuldrUITests`) because they never ship.
- Changing any of these after release means a new app record and a data migration, so they are treated as fixed.

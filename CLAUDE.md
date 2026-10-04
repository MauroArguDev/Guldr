# Guldr — instructions for Claude Code

## Project
Local-first personal finance app. iOS 26+, iPhone only, SwiftUI, SwiftData, MVVM with @Observable.
Targets: Guldr (app), GuldrWidget (widget extension). App Group: `group.com.argudev.guldr`, read from Info.plist key `AppGroupID`.

## Rules
- English only, everywhere in the project: code, identifiers, comments, docs, ADRs, commit messages, PRs, error and alert strings, logs. Spanish exists only as translations in the String Catalog (source language: English). This applies even when the conversation is in another language.
- Never commit or push to `main`. Every change goes through a branch and a PR (see `docs/WORKFLOW.md`).
- Read the relevant ADR in `docs/decisions/` before changing architecture. New non-obvious decisions get a new ADR.
- SwiftData models must stay CloudKit-compatible: no `@Attribute(.unique)`, all relationships optional, every property has a default value.
- Every transaction stores `currencyCode`.
- No `fatalError` in production paths; surface typed errors.
- No Siri / AppShortcutsProvider. App Intents are allowed for widgets.
- No secrets in the repo. Future keys go in `Config/Secrets.xcconfig` (gitignored).
- Swift 6 strict concurrency; never silence warnings with `@unchecked Sendable` without a comment explaining why.
- Never hand-edit `Guldr.xcodeproj/project.pbxproj`. Targets, capabilities, signing and build configuration changes are done by the user in Xcode; ask for them.
- The project uses synchronized folders: files created under `Guldr/` join the app target automatically.

## Working style
- One logical step at a time; build after every step, never pile up unverified files.
- Architecture, UX and Xcode configuration decisions belong to the author: propose, don't decide.
- Explain the reasoning behind non-trivial code so the author can defend it in an interview.
- Follow the Definition of Done in `docs/WORKFLOW.md`.

## Design system
- Visual source of truth: `docs/design/DESIGN.md` (values in `docs/design/tokens.json`).
- Before building or changing a screen, read DESIGN.md and its mockup in `docs/design/mockups/`.
- Colors only from the `GuldrColors` asset catalog (`Color(.goldFill)` etc.). Never hard-coded hex.
- Do not invent colors, sizes or radii. If something is missing, ask, then document it in DESIGN.md.
- Native components first (TabView, NavigationStack, sheets, segmented Picker).
- Every view gets previews in light and dark.

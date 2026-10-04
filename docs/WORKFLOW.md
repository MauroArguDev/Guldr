# Workflow

How work moves from an idea to `main` in Guldr, and what "done" means.

## Local setup

```bash
git clone https://github.com/MauroArguDev/Guldr.git
cd Guldr
git config core.hooksPath .githooks
open Guldr.xcodeproj
```

The hooks in `.githooks/` reject commits on `main` and pushes to `main`. They are the local half of the branch protection; the GitHub ruleset is the remote half.

## Language

Everything in the repository is written in English: code, identifiers, comments, documentation, ADRs, commit messages, pull requests, error and alert strings, and logs. User-facing text is written in English in code and translated to Spanish in the String Catalog; no other file contains Spanish.

## Branches

`main` is always buildable and is never committed to directly. Every change starts on a short-lived branch named `type/short-description`:

| Type | Use |
|---|---|
| `feat` | New user-facing behavior |
| `fix` | Bug fix |
| `refactor` | Code change with no behavior change |
| `test` | Tests only |
| `docs` | Documentation only |
| `style` | Formatting, lint fixes |
| `chore` | Project configuration, tooling, dependencies |
| `ci` | GitHub Actions |

Examples: `feat/budget-ring`, `fix/widget-refresh`, `chore/swiftlint`.

## Commits

- [Conventional Commits](https://www.conventionalcommits.org/), in English, imperative mood, lowercase: `feat: add monthly budget ring`.
- One logical step per commit. A commit should build on its own.
- Explain the *why* in the body when it isn't obvious from the diff.

## Pull requests

1. Push the branch and open a PR against `main`. The template asks for what, why, how to test, light/dark screenshots and the checklist below.
2. CI must be green (see [Continuous integration](#continuous-integration)).
3. Merge with `gh pr merge --rebase --delete-branch`. Only rebase merging is enabled, so history stays linear.
4. `git switch main && git pull`.

## Testing

- **Framework:** Swift Testing (`@Test`, `#expect`). The project has no UI test target: UI is verified with light/dark previews and on device (see the Definition of Done), which keeps CI fast.
- **Persistence:** tests that touch SwiftData use an in-memory container, never the on-disk store:

  ```swift
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  let container = try ModelContainer(for: Transaction.self, configurations: config)
  ```

- **Priorities:**

  | Area | What to cover | Priority |
  |---|---|---|
  | Financial calculations | Balance, monthly income and expenses, budget usage, over-budget | High |
  | ViewModels | Validation, save paths, edge cases (zero, negative, very large amounts) | High |
  | Formatting | Currency and dates in English and Spanish | Medium |
  | Services | Biometrics, notifications and export behind protocols, tested with fakes | Medium |
  | Views | Previews build in light and dark | Low |

- **Goal:** every logic change comes with tests; aim for 60%+ coverage of ViewModels and services.
- **Run:**

  ```bash
  xcodebuild test -project Guldr.xcodeproj -scheme Guldr \
    -destination "platform=iOS Simulator,name=iPhone 17,OS=latest"
  ```

## Continuous integration

The workflow uses the [`prepare-simulator`](../.github/actions/prepare-simulator/action.yml) action, which selects a pinned Xcode, boots the simulator and waits until `xcodebuild` lists it as a destination before anything is built. On a cold runner the simulator can report as booted before `xcodebuild` sees it; the wait (up to 30 attempts, about 10 minutes; ~6 minutes observed) and `-destination-timeout 120` absorb that race.

### `CI` — required on every pull request

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs on pull requests against `main`, on pushes to `main` and on demand.

| Job | Runner | What it does |
|---|---|---|
| `changes` | `ubuntu-latest` | Lists the files the PR changes. If they are only Markdown or under `docs/`, the macOS job is skipped. |
| `test` | `macos-26`, Xcode 26.6 | Boots the iPhone 17 simulator, runs `build-for-testing`, then `test-without-building` for `GuldrTests`, and fails if zero tests ran. Timeout: 25 minutes. On failure it uploads the `.xcresult` bundle as an artifact for 7 days. |

- **Required:** the `main` ruleset blocks merging until `test` succeeds. A `test` job skipped for a docs-only PR reports success, so documentation changes are not blocked.
- **Pushes to `main` always run `test`**, whatever changed.
- **Concurrency:** a new push to a PR cancels its run in progress; runs on `main` always finish.
- **Speed:** code coverage, indexing and parallel simulator clones are disabled in CI.
- **Security:** the workflow token is read-only (`contents: read`), checkout does not persist credentials, third-party actions are pinned to a commit SHA, and [Dependabot](../.github/dependabot.yml) proposes weekly updates for them.

### Reproduce CI locally

```bash
UDID=$(xcrun simctl list devices available -j \
  | jq -r '[.devices[][] | select(.name == "iPhone 17")] | last | .udid')
xcrun simctl bootstatus "$UDID" -b

xcodebuild build-for-testing -project Guldr.xcodeproj -scheme Guldr \
  -destination "id=$UDID" -only-testing:GuldrTests -derivedDataPath DerivedData \
  -enableCodeCoverage NO COMPILER_INDEX_STORE_ENABLE=NO CODE_SIGNING_ALLOWED=NO

xcodebuild test-without-building -project Guldr.xcodeproj -scheme Guldr \
  -destination "id=$UDID" -only-testing:GuldrTests -derivedDataPath DerivedData \
  -enableCodeCoverage NO -parallel-testing-enabled NO
```

### When Xcode changes

- The pinned version lives in `XCODE_VERSION` in the workflow and must exist on the `macos-26` runner image. Bump it when GitHub ships a newer Xcode.
- The project file must stay in a format the CI Xcode can open (currently `objectVersion = 77`). In Xcode, keep **Minimize Project References** and **Strictly Validate** unchecked in the project's File Inspector.

## Linting

[SwiftLint](https://github.com/realm/SwiftLint) runs on every build through the `SwiftLintBuildToolPlugin` from [SwiftLintPlugins](https://github.com/SimplyDanny/SwiftLintPlugins), attached to the `Guldr`, `GuldrWidgetExtension` and `GuldrTests` targets. The version is pinned in `Package.resolved`, so Xcode, every developer and CI use the same one.

- Rules live in [`.swiftlint.yml`](../.swiftlint.yml): the default rules plus a few opt-ins (`empty_count`, `first_where`, `toggle_bool`…), lines up to 140 characters (error at 200).
- **Zero warnings** is the bar: a pull request does not add SwiftLint warnings.
- The first build after cloning asks to **Trust & Enable** the plugin in Xcode. CI skips that prompt with `-skipPackagePluginValidation`.
- Disable a rule inline only with a comment explaining why: `// swiftlint:disable:next rule_name — reason`.

## Definition of Done

### Feature

- [ ] Builds without warnings
- [ ] Logic covered by tests
- [ ] Uses design-system tokens only (no hard-coded colors, sizes or radii)
- [ ] Handles empty, loading and error states
- [ ] No hard-coded user-facing strings; English and Spanish in the String Catalog
- [ ] Interactive elements have accessibility labels; decorative ones are hidden from VoiceOver

### Screen

- [ ] Everything in *Feature*
- [ ] Matches its mockup in `docs/design/mockups/`
- [ ] Light and dark previews
- [ ] Correct layout on the smallest (iPhone SE) and largest (Pro Max) screens
- [ ] Correct layout at the largest accessibility Dynamic Type size
- [ ] Usable end to end with VoiceOver
- [ ] Checked in English and Spanish with no truncated strings
- [ ] Respects Reduce Motion

### Release

- [ ] Every v1.0 item in the [roadmap](ROADMAP.md) is checked
- [ ] No crashes in a 10-minute session on a real device
- [ ] Privacy manifest up to date
- [ ] README with screenshots and demo GIF
- [ ] Version tagged on `main`

## Architecture decisions

Non-obvious decisions are recorded as ADRs in [`decisions/`](decisions/), using [`000-template.md`](decisions/000-template.md).

- Write one when a choice constrains future work, has real alternatives, or would make someone ask "why is it like this?".
- Number them sequentially (`005-…`) and add them to the [index](decisions/README.md).
- ADRs are not edited after they are accepted; a new ADR supersedes the old one.

## Working with Claude Code

Claude Code is a pair programmer on this project, guided by [`CLAUDE.md`](../CLAUDE.md).

| Practice | Why |
|---|---|
| One file or one logical step per request | Keeps context small and output precise |
| Describe inputs, outputs and constraints | "Receives X, shows Y, uses token Z" beats "build the budget screen" |
| Build after every step | Never pile up unverified files |
| Generate first, refactor in a separate step | Smaller, reviewable diffs |
| Ask for the reasoning behind non-trivial code | Every line must be defensible in a code review |

What stays with the author: architecture and UX decisions, Xcode configuration (targets, signing, capabilities), visual review of previews, and App Store Connect.

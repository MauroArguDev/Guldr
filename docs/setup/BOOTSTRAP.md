# Guldr — Project bootstrap

> Runbook to set up Guldr from scratch, meant to be executed **by the author and Claude Code together**. Location in the repo: `docs/setup/BOOTSTRAP.md`.
> Written for **Xcode 27**; some menus may be named slightly differently.

## Progress

| Phase | Topic | Branch | Status | PR |
|---|---|---|---|---|
| 0 | Preparation | — | ✅ Done | — |
| 1 | Foundations and repo | `chore/project-foundations` | 🟡 In progress | — |
| 2 | CI | `ci/github-actions` | ⬜ Pending | — |
| 3 | Widget target | `feat/widget-target` | ⬜ Pending | — |
| 4 | Signing, App Group and configuration | `chore/build-configuration` | ⬜ Pending | — |
| 5 | Structure and design system | `feat/design-system` | ⬜ Pending | — |
| 6 | App icon | `feat/app-icon` | ⬜ Pending | — |
| 7 | Privacy and localization | `chore/privacy-and-localization` | ⬜ Pending | — |
| 8 | SwiftLint | `chore/swiftlint` | ⬜ Pending | — |

---

## How to use this document

### Who does each step

- **🧑 YOU**: done in the Xcode, Icon Composer or GitHub UI. Claude Code cannot do it safely.
- **🤖 CLAUDE CODE**: files, terminal, git and checks.
- **✅ VERIFY**: a command that confirms the previous work is correct before moving on.

Every step has a `Phase.Step` ID (for example **1.12**) so it can be referenced: *"continue from 4.9"*.

### How to mark progress

| Mark | Meaning |
|---|---|
| `- [ ]` | Pending |
| `- [x]` | Done and verified |
| `- [x] … — ⏭️ skipped: <reason>` | Not applicable or deliberately skipped; the reason is mandatory |

In the **Progress** table: ⬜ Pending · 🟡 In progress · ✅ Done. When a phase's PR is opened, put its link in the **PR** column.

Rules:

1. A step is marked `[x]` only when it is **done and verified**, not when it starts.
2. Claude Code marks its 🤖 and ✅ steps as soon as it finishes them. 🧑 steps are marked by Claude Code **after the author confirms** in the chat and, when possible, after checking with a command.
3. Marks travel with the work: the last commit before opening each phase's PR is `docs: update bootstrap progress for phase N`.
4. Steps that happen after the PR is opened (CI, merge, final checks) are marked in the first commit of the **next phase**, together with the ✅ status of the finished phase.
5. Phase 0 marks go into the Phase 1 PR.
6. Findings worth keeping are recorded under the step as `Result: …`.

### How to run it

Open Claude Code at the repo root and say:

> "Read `docs/setup/BOOTSTRAP.md` and continue from the first unchecked step. Stop at every 🧑 YOU step and wait for my confirmation."

### PR cycle

Every phase from 1 onward ends with the same cycle, listed step by step inside the phase:

```bash
git push -u origin <branch>
gh pr create --base main --title "<PR title>" --fill
gh pr checks --watch                  # from Phase 2 on
gh pr merge --rebase --delete-branch
git switch main && git pull
```

---

## Instructions for Claude Code

1. Run **one phase at a time**, in order. Do not start the next one until the author asks.
2. Always start from the **first unchecked step**. If a checked step does not look done, stop and ask.
3. At every **🧑 YOU** step, explain in one line what the author must do and **wait for confirmation**. Never simulate or skip it.
4. **Never hand-edit `Guldr.xcodeproj/project.pbxproj`.** Targets, capabilities, signing, build configurations and memberships are changed in Xcode (🧑 steps). If a step seems to require touching the `.pbxproj`, stop and ask.
5. The project uses **synchronized folders**: every file created under `Guldr/` joins the app target automatically. Widget membership = 🧑 step.
6. Use exactly the **branch names and commit messages** of each phase. Conventional Commits, one logical step per commit.
7. **Never commit or push directly to `main`**, not even in Phase 1: branch → PR → green CI (from Phase 2) → `gh pr merge --rebase --delete-branch`. Check the current branch before every commit. Stage files by explicit path, never `git add .`.
8. **English only** in everything written to the project: code, comments, docs, ADRs, commits, PRs, alerts and logs. Spanish exists only as translations in the String Catalog.
9. Build and test with `xcodebuild` and the simulator defined in Phase 0 (`$SIM`). Do not open Xcode.
10. If a ✅ VERIFY step fails, stop, explain what failed and propose a fix before continuing.
11. The design package is at `~/Downloads/Guldr/GuldrDesign/` (or zipped at `~/Downloads/Guldr/GuldrDesign.zip`). Check both.
12. The previous project, `~/Documents/Portfolio/Old_FinTrackPro`, is reference only. Its blueprint lives in git history: `git -C ~/Documents/Portfolio/Old_FinTrackPro show e50a32c^:fintrack-pro-blueprint.md`.

---

## Project values

| Key | Value |
|---|---|
| Name | `Guldr` |
| Local path | `~/Documents/Portfolio/Guldr` |
| Repo | `MauroArguDev/Guldr` (public) |
| Apple account | `argudev@icloud.com` — Personal Team `XRC983479Z` (free; TestFlight and the App Store require the Apple Developer Program) |
| App bundle ID | `com.argudev.guldr` |
| Widget bundle ID | `com.argudev.guldr.widget` |
| App Group | `group.com.argudev.guldr` |
| iCloud (1.1, **not** used yet) | `iCloud.com.argudev.guldr` |
| Minimum iOS | 26.0 |
| Destinations | iPhone only |
| Description | `Your gold, in order. Local-first personal finance app for iOS.` |

---

## Phase 0 — Preparation · no commits

Project changes from this phase are not committed here: they go into the first commit of Phase 1, on its branch.

**🧑 YOU — Tools**

- [x] **0.1** In **Xcode 27 ▸ Settings ▸ Accounts**, add `argudev@icloud.com` and check that its team appears.
  Result: *Personal Team* `XRC983479Z`. With a free account the App Group (Phase 4) may not be available.
- [x] **0.2** Install GitHub CLI: `brew install gh`
- [x] **0.3** Authenticate (interactive, Claude Code cannot do it): `gh auth login`
- [x] **0.4** Point the command line tools to Xcode (without this, `xcodebuild` and `simctl` do not work):
  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ```

**🧑 YOU — Project**

- [x] **0.5** Create the project: **File ▸ New ▸ Project ▸ iOS ▸ App**, saved in `~/Documents/Portfolio` (Xcode creates the `Guldr/` folder).

  | Field | Value |
  |---|---|
  | Product Name | `Guldr` |
  | Team | your Personal Team |
  | Organization Identifier | `com.argudev` |
  | Interface | SwiftUI |
  | Language | Swift |
  | Testing System | Swift Testing with XCTest UI Tests |
  | Storage | **None** (the `ModelContainer` is written by hand in the data layer) |

- [x] **0.6** **Target Guldr ▸ General ▸ Supported Destinations**: iPhone only. Remove iPad, Mac and Vision.
- [x] **0.7** **Target Guldr ▸ General ▸ Minimum Deployments**: **iOS 26.0**.
- [x] **0.8** **Project Guldr ▸ Build Settings ▸ iOS Deployment Target**: **26.0**.
- [x] **0.9** **GuldrTests** and **GuldrUITests ▸ Build Settings**: *iOS Deployment Target* = **26.0** and *Targeted Device Family* = **iPhone**.
- [x] **0.10** **Project Guldr ▸ File Inspector ▸ Project Format**: the oldest compatible format offered (ideally *Xcode 26.0-compatible*), so CI can open it if the runner still has Xcode 26.
  Result: *Compatibility: Xcode 16.0* (`preferredProjectObjectVersion = 77`), but the file still declares `objectVersion = 110`. Phase 2 CI confirms whether an older Xcode opens it.
- [x] **0.11** **Product ▸ Scheme ▸ Manage Schemes**: check **Shared** on the `Guldr` scheme.
- [x] **0.12** Copy this file to `docs/setup/BOOTSTRAP.md` and open Claude Code in `~/Documents/Portfolio/Guldr`.

**🤖 CLAUDE CODE**

- [x] **0.13** Find an available iPhone simulator and use it as `$SIM` throughout this document:
  ```bash
  xcrun simctl list devices available | grep -E "iPhone [0-9]+" | head -5
  ```
  Result: `SIM="iPhone 17"` (same as CI). Destination: `platform=iOS Simulator,name=$SIM,OS=latest`.
- [x] **0.14** Record the project's concurrency settings, for ADR 003:
  ```bash
  xcodebuild -project Guldr.xcodeproj -target Guldr -showBuildSettings 2>/dev/null \
    | grep -E "SWIFT_VERSION|SWIFT_DEFAULT_ACTOR_ISOLATION|SWIFT_APPROACHABLE_CONCURRENCY|SWIFT_STRICT_CONCURRENCY"
  ```
  Result (Xcode 27.0): `SWIFT_VERSION = 6.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`; `SWIFT_STRICT_CONCURRENCY` unset (equivalent to `complete` in Swift 6).

**✅ VERIFY**

- [x] **0.15** Every deployment target is `26.0` and every device family is `1` (read-only):
  ```bash
  grep -E "IPHONEOS_DEPLOYMENT_TARGET|TARGETED_DEVICE_FAMILY" Guldr.xcodeproj/project.pbxproj | sort | uniq -c
  ```
  Result: 8 configurations at `26.0` and 6 families at `1`.
- [x] **0.16** Shared scheme:
  ```bash
  test -f Guldr.xcodeproj/xcshareddata/xcschemes/Guldr.xcscheme && echo "shared scheme OK"
  ```
- [x] **0.17** The project builds:
  ```bash
  xcodebuild -project Guldr.xcodeproj -scheme Guldr -destination "platform=iOS Simulator,name=$SIM,OS=latest" build | tail -3
  ```

---

## Phase 1 — Foundations and GitHub repo · branch `chore/project-foundations`

The repo already has the `Initial commit` Xcode generated on `main`. Everything in this phase goes on a branch; `main` on GitHub points at that commit and is never pushed to directly.

**🤖 CLAUDE CODE — Branch and project**

- [x] **1.1** `git switch -c chore/project-foundations`
- [x] **1.2** Commit 1: `chore: target ios 26 on iphone only and share scheme` (the `.pbxproj` and the shared scheme from Phase 0).
  Result: also includes two changes made in Xcode during Phase 0: portrait-only orientation on iPhone and Swift 6.0 in the test targets.

**🤖 CLAUDE CODE — `.gitignore`**

- [x] **1.3** Replace `.gitignore` with a project-specific one (no CocoaPods, Carthage, fastlane or Playgrounds sections):
  ```gitignore
  # Xcode
  xcuserdata/
  *.xcuserstate
  DerivedData/
  build/
  *.xcresult
  *.ipa
  *.dSYM
  *.dSYM.zip

  # SPM (root only; Package.resolved inside the project is committed)
  .build/
  /.swiftpm/

  # macOS
  .DS_Store

  # Secrets (future APIs)
  Config/Secrets.xcconfig
  .env

  # Claude Code (local only)
  .claude/settings.local.json
  CLAUDE.local.md
  ```
- [x] **1.4** ✅ Xcode user data is ignored:
  ```bash
  git check-ignore -q Guldr.xcodeproj/xcuserdata && echo "xcuserdata ignored OK"
  ```
- [x] **1.5** Commit 2: `chore: replace gitignore with project-specific rules`

**🤖 CLAUDE CODE — Git hooks**

- [x] **1.6** Create `.githooks/pre-commit`:
  ```sh
  #!/bin/sh
  branch="$(git symbolic-ref --short HEAD 2>/dev/null)"
  if [ "$branch" = "main" ]; then
    echo "error: direct commits to main are not allowed. Create a branch: git switch -c type/short-description" >&2
    exit 1
  fi
  ```
- [x] **1.7** Create `.githooks/pre-push`:
  ```sh
  #!/bin/sh
  while read -r local_ref local_sha remote_ref remote_sha; do
    if [ "$remote_ref" = "refs/heads/main" ]; then
      echo "error: pushing to main is not allowed. Open a pull request instead." >&2
      exit 1
    fi
  done
  ```
- [x] **1.8** Make them executable and enable them:
  ```bash
  chmod +x .githooks/pre-commit .githooks/pre-push
  git config core.hooksPath .githooks
  ```
- [x] **1.9** ✅ The hook blocks commits on `main` (the commit must fail):
  ```bash
  git switch main && git commit --allow-empty -m "hook test"; git switch -
  ```
  Result: commit on `main` rejected; a simulated push to `refs/heads/main` rejected, a push to any other branch allowed.
- [x] **1.10** Commit 3: `chore: add git hooks that block commits and pushes to main`

**🤖 CLAUDE CODE — README, CLAUDE.md and PR template**

- [x] **1.11** Create [`README.md`](../../README.md): tagline, status, requirements, how to run (including `git config core.hooksPath .githooks`), v1.0 scope and links to `docs/`.
- [x] **1.12** Create [`CLAUDE.md`](../../CLAUDE.md): project summary, rules (English only, never commit to `main`, ADRs first, CloudKit-compatible models, `currencyCode`, no `fatalError`, no Siri, no secrets, Swift 6 concurrency, never hand-edit the `.pbxproj`, synchronized folders) and working style. The design system section is added in Phase 5.
- [x] **1.13** Create [`.github/pull_request_template.md`](../../.github/pull_request_template.md): what, why, how to test, light/dark screenshots and a checklist (Definition of Done, tests, previews, String Catalog, docs).
- [x] **1.14** Commit 4: `docs: add readme, claude instructions and pr template`

**🤖 CLAUDE CODE — WORKFLOW and ROADMAP**

- [x] **1.15** Create [`docs/WORKFLOW.md`](../WORKFLOW.md) (based on sections 8, 9, 12 and 13 of the FinTrack Pro blueprint, adapted): local setup, language, branches, commits, pull requests, testing, Definition of Done (feature, screen, release), architecture decisions and working with Claude Code.
- [x] **1.16** Create [`docs/ROADMAP.md`](../ROADMAP.md): v1.0 as a checklist, v1.1 iCloud sync, later ideas, and what is out of scope and why.
- [x] **1.17** Commit 5: `docs: add workflow and roadmap`
  Result: followed by commit `docs: require english across the project`, which adds the English-only rule to `CLAUDE.md` and `docs/WORKFLOW.md` (rule set on 2026-10-01).

**🤖 CLAUDE CODE — ADRs**

- [x] **1.18** Create [`docs/decisions/000-template.md`](../decisions/000-template.md): status, date, context, decision, alternatives considered, consequences.
- [x] **1.19** Create [`docs/decisions/README.md`](../decisions/README.md): what an ADR is, how to add one, and an index table.
- [x] **1.20** Draft `docs/decisions/001-ios-26-minimum.md`: current native design and Foundation Models without `#available`; supports iPhone 11 / SE (2nd gen) and later.
- [x] **1.21** Draft `docs/decisions/002-identifiers.md`: the identifier table and why it uses `com.argudev` instead of the app's domain.
- [x] **1.22** Draft `docs/decisions/003-concurrency-defaults.md`: the settings from step 0.14 and whether they are kept.
- [x] **1.23** Draft `docs/decisions/004-rewrite-from-fintrack-pro.md`: why rewrite instead of migrating (new name and design, no Siri, EN/ES without FR, trunk-based without `develop`, public docs).

**🧑 YOU — Review the ADRs**

- [x] **1.24** Review each ADR and adapt it to your own voice and reasoning: they are your interview answers. Set the status to **Accepted** when you agree with it.
  Result: all four reviewed, adapted and set to Accepted on 2026-10-01.

**🤖 CLAUDE CODE**

- [x] **1.25** Add ADRs 001–004 to the index in `docs/decisions/README.md`.
- [x] **1.26** Commit 7: `docs: add adr template and first decisions`
- [x] **1.27** Mark Phase 0 and Phase 1 progress so far. Commit 8: `docs: add project bootstrap runbook`

**🤖 CLAUDE CODE — GitHub repo**

- [x] **1.28** Create the repo **without** pushing:
  ```bash
  gh repo create MauroArguDev/Guldr --public --source=. --remote=origin \
    --description "Your gold, in order. Local-first personal finance app for iOS."
  ```
  Result: done before Phase 1 (the repo already existed on GitHub with `main` = `Initial commit`); verified on 2026-10-01.
- [ ] **1.29** Push only the branch: `git push -u origin chore/project-foundations`
- [x] **1.30** Create `main` on GitHub pointing at the `Initial commit`, through the API:
  ```bash
  gh api repos/MauroArguDev/Guldr/git/refs -f ref=refs/heads/main -f sha="$(git rev-parse main)"
  ```
  Result: done before Phase 1 (the repo already existed on GitHub with `main` = `Initial commit`); verified on 2026-10-01.
- [x] **1.31** Make `main` the default branch: `gh repo edit MauroArguDev/Guldr --default-branch main`
  Result: done before Phase 1; verified on 2026-10-01.
- [x] **1.32** Track the remote `main` locally: `git fetch origin && git branch -u origin/main main`
  Result: `main` already tracks `origin/main`.

**🧑 YOU — GitHub protection**

- [x] **1.33** **Settings ▸ Rules ▸ Rulesets ▸ New ruleset ▸ New branch ruleset**:
  - **Ruleset name:** `Protect main` · **Enforcement status:** Active · **Bypass list:** empty
  - **Target branches:** Add target ▸ Include default branch
  - ☑ Restrict deletions
  - ☑ Require linear history
  - ☑ Require a pull request before merging: required approvals `0`, ☑ Require conversation resolution before merging, allowed merge methods: **Rebase** only
  - ☑ Block force pushes
  - ☐ Require status checks to pass (enabled in step 2.14, once the CI check exists)
  - Everything else unchecked.

  Result: ruleset `Protect main` (id `24347142`) active with no bypass; rules: deletion, non_fast_forward, pull_request (0 approvals, thread resolution, rebase only), required_linear_history. Verified through the API on 2026-10-01.
- [x] **1.34** **Settings ▸ General ▸ Pull Requests**: keep only *Allow rebase merging* and enable *Automatically delete head branches*.
  Result: only rebase merging enabled, head branches deleted automatically, update-branch suggestion on, auto-merge off. Verified through the API on 2026-10-01.

**🤖 CLAUDE CODE — PR cycle** (no CI yet)

- [ ] **1.35** `gh pr create --base main --title "chore: add project foundations" --fill`
- [ ] **1.36** `gh pr merge --rebase --delete-branch`
- [ ] **1.37** `git switch main && git pull`

**✅ VERIFY**

- [ ] **1.38** History: `git log --oneline` → `Initial commit` + 8 commits.
- [ ] **1.39** No user data: `git ls-files | grep -c xcuserdata` → `0`.
- [ ] **1.40** Hooks enabled: `git config core.hooksPath` → `.githooks`.
- [ ] **1.41** Public repo with `main` as default:
  ```bash
  gh repo view MauroArguDev/Guldr --json visibility,defaultBranchRef -q '.visibility + " " + .defaultBranchRef.name'   # PUBLIC main
  ```
- [ ] **1.42** Ruleset active: `gh api repos/MauroArguDev/Guldr/rulesets -q '.[].name'`

---

## Phase 2 — CI · branch `ci/github-actions`

**🤖 CLAUDE CODE**

- [ ] **2.1** `git switch -c ci/github-actions`
- [ ] **2.2** Mark the remaining Phase 1 steps and its ✅ status in the **Progress** table.
- [ ] **2.3** Create `.github/workflows/ci.yml`:
  ```yaml
  name: CI

  on:
    pull_request:
      branches: [main]
    push:
      branches: [main]

  concurrency:
    group: ci-${{ github.ref }}
    cancel-in-progress: true

  jobs:
    test:
      runs-on: macos-latest
      timeout-minutes: 30
      steps:
        - uses: actions/checkout@v4

        - uses: maxim-lobanov/setup-xcode@v1
          with:
            xcode-version: latest-stable

        - name: Show Xcode and simulators
          run: |
            xcodebuild -version
            xcrun simctl list devices available | grep iPhone | head -5

        - name: Build and test
          run: |
            set -o pipefail
            xcodebuild test \
              -project Guldr.xcodeproj \
              -scheme Guldr \
              -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
              -skipPackagePluginValidation \
              CODE_SIGNING_ALLOWED=NO \
              | xcbeautify
  ```
  - `CODE_SIGNING_ALLOWED=NO`: simulator tests need no certificates.
  - `-skipPackagePluginValidation`: lets SwiftLint (Phase 8) run on CI without the manual "Trust" prompt.
  - If the runner has no "iPhone 17", the "Show Xcode and simulators" step lists what it has: adjust `-destination`.
  - Once Xcode 27 is available on the runner, pin `xcode-version: '27'`.
- [ ] **2.4** Commit: `ci: run build and tests on pull requests`
- [ ] **2.5** Add a **Continuous integration** section to `docs/WORKFLOW.md`: what runs, on which runner, and how to reproduce it locally.
- [ ] **2.6** Add the CI badge to `README.md`.
- [ ] **2.7** Commit: `docs: document ci workflow`
- [ ] **2.8** Commit: `docs: update bootstrap progress for phase 2`

**🤖 CLAUDE CODE — PR cycle**

- [ ] **2.9** `git push -u origin ci/github-actions`
- [ ] **2.10** `gh pr create --base main --title "ci: add GitHub Actions workflow" --fill`
- [ ] **2.11** `gh pr checks --watch` → CI green.
- [ ] **2.12** `gh pr merge --rebase --delete-branch`
- [ ] **2.13** `git switch main && git pull`

**🧑 YOU**

- [ ] **2.14** In the `main` ruleset (step 1.33), enable **Require status checks to pass → `test`**. The check appears in the list after its first run.

**✅ VERIFY**

- [ ] **2.15** Latest run is green: `gh run list --limit 1` → `completed / success`.
- [ ] **2.16** The ruleset requires the check:
  ```bash
  gh api repos/MauroArguDev/Guldr/rules/branches/main -q '.[].type'   # includes required_status_checks
  ```

---

## Phase 3 — Widget target · branch `feat/widget-target`

**🤖 CLAUDE CODE**

- [ ] **3.1** `git switch -c feat/widget-target`
- [ ] **3.2** Mark the remaining Phase 2 steps and its ✅ status in the **Progress** table.

**🧑 YOU**

- [ ] **3.3** **File ▸ New ▸ Target ▸ iOS ▸ Widget Extension**:

  | Field | Value |
  |---|---|
  | Product Name | `GuldrWidget` |
  | Bundle Identifier | change it to **`com.argudev.guldr.widget`** |
  | Include Live Activity | No |
  | Include Control | No |
  | Include Configuration App Intent | No |
  | Embed in Application | Guldr |

- [ ] **3.4** Answer **Activate** in the scheme dialog.
- [ ] **3.5** **GuldrWidget ▸ General ▸ Minimum Deployments**: iOS 26.0.
- [ ] **3.6** **GuldrWidget ▸ General ▸ Supported Destinations**: iPhone only.
- [ ] **3.7** **Product ▸ Scheme ▸ Manage Schemes**: check **Shared** on the widget scheme.

**🤖 CLAUDE CODE**

- [ ] **3.8** Confirm the widget scheme name (`GuldrWidgetExtension` or `GuldrWidget`): `xcodebuild -list -project Guldr.xcodeproj`
- [ ] **3.9** ✅ Build the app:
  ```bash
  xcodebuild -project Guldr.xcodeproj -scheme Guldr -destination "platform=iOS Simulator,name=$SIM,OS=latest" build | tail -3
  ```
- [ ] **3.10** ✅ Build the widget:
  ```bash
  xcodebuild -project Guldr.xcodeproj -scheme GuldrWidgetExtension -destination "platform=iOS Simulator,name=$SIM,OS=latest" build | tail -3
  ```
- [ ] **3.11** Commit: `feat: add widget extension target`
- [ ] **3.12** Commit: `docs: update bootstrap progress for phase 3`

**🤖 CLAUDE CODE — PR cycle**

- [ ] **3.13** `git push -u origin feat/widget-target`
- [ ] **3.14** `gh pr create --base main --title "feat: add GuldrWidget extension target" --fill`
- [ ] **3.15** `gh pr checks --watch` → CI green.
- [ ] **3.16** `gh pr merge --rebase --delete-branch`
- [ ] **3.17** `git switch main && git pull`

---

## Phase 4 — Signing, App Group and configuration · branch `chore/build-configuration`

**🤖 CLAUDE CODE**

- [ ] **4.1** `git switch -c chore/build-configuration`
- [ ] **4.2** Mark the remaining Phase 3 steps and its ✅ status in the **Progress** table.

**🧑 YOU — Signing and App Group**

- [ ] **4.3** **Target Guldr ▸ Signing & Capabilities**: *Automatically manage signing* with your team.
- [ ] **4.4** **Target GuldrWidget ▸ Signing & Capabilities**: *Automatically manage signing* with your team.
- [ ] **4.5** **Target Guldr ▸ + Capability ▸ App Groups**: `group.com.argudev.guldr`.
- [ ] **4.6** **Target GuldrWidget ▸ + Capability ▸ App Groups**: `group.com.argudev.guldr`.
  > **Do not add iCloud**: SwiftData would turn on CloudKit sync automatically.
- [ ] **4.7** Run the app on your iPhone to confirm signing works.

**🤖 CLAUDE CODE**

- [ ] **4.8** ✅ Two entitlements files contain the App Group:
  ```bash
  grep -rl "group.com.argudev.guldr" --include="*.entitlements" .   # 2 files
  ```
- [ ] **4.9** Commit: `chore: enable app group for app and widget`

**🧑 YOU — Info.plist**

- [ ] **4.10** **Target Guldr ▸ Info**: `Privacy - Face ID Usage Description` = `Guldr uses Face ID to keep your financial data private.`
- [ ] **4.11** **Target Guldr ▸ Info**: `AppGroupID` (String) = `$(APP_GROUP_ID)`.
- [ ] **4.12** **Target GuldrWidget ▸ Info**: `AppGroupID` (String) = `$(APP_GROUP_ID)`.

**🤖 CLAUDE CODE**

- [ ] **4.13** Commit: `chore: add face id usage description and app group info key`

**🤖 CLAUDE CODE — xcconfig**

- [ ] **4.14** Create `Config/Shared.xcconfig`:
  ```
  MARKETING_VERSION = 1.0.0
  CURRENT_PROJECT_VERSION = 1
  IPHONEOS_DEPLOYMENT_TARGET = 26.0
  APP_GROUP_ID = group.com.argudev.guldr
  ```
- [ ] **4.15** Create `Config/Debug.xcconfig` and `Config/Release.xcconfig`, each with a single line: `#include "Shared.xcconfig"`.

**🧑 YOU**

- [ ] **4.16** Drag the `Config/` folder into the project in Xcode **without selecting any target**.
- [ ] **4.17** **Project Guldr ▸ Info ▸ Configurations**: `Debug.xcconfig` for Debug and `Release.xcconfig` for Release, on the project and both targets.
- [ ] **4.18** In each target's Build Settings, if `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` or `IPHONEOS_DEPLOYMENT_TARGET` show in bold, select them and press **Delete** so they inherit from the xcconfig.

**🤖 CLAUDE CODE**

- [ ] **4.19** ✅ Values come from the xcconfig:
  ```bash
  for t in Guldr GuldrWidgetExtension; do
    xcodebuild -project Guldr.xcodeproj -target $t -showBuildSettings 2>/dev/null \
      | grep -E " (MARKETING_VERSION|APP_GROUP_ID|IPHONEOS_DEPLOYMENT_TARGET) ="
  done
  ```
- [ ] **4.20** Commit: `chore: move version and app group settings to xcconfig`

**🤖 CLAUDE CODE — First test**

- [ ] **4.21** Replace the sample test in `GuldrTests`:
  ```swift
  import Testing
  @testable import Guldr

  struct ConfigurationTests {
      @Test func appGroupIDIsConfigured() {
          let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String
          #expect(id == "group.com.argudev.guldr")
      }
  }
  ```
- [ ] **4.22** ✅ Run `xcodebuild test` with `$SIM`. If it fails, ask the author to confirm the test target has **Host Application = Guldr**.
- [ ] **4.23** Commit: `test: verify app group id is configured`
- [ ] **4.24** Commit: `docs: update bootstrap progress for phase 4`

**🤖 CLAUDE CODE — PR cycle**

- [ ] **4.25** `git push -u origin chore/build-configuration`
- [ ] **4.26** `gh pr create --base main --title "chore: configure signing, app group and build settings" --fill`
- [ ] **4.27** `gh pr checks --watch` → CI green.
- [ ] **4.28** `gh pr merge --rebase --delete-branch`
- [ ] **4.29** `git switch main && git pull`

---

## Phase 5 — Structure and design system · branch `feat/design-system`

**🤖 CLAUDE CODE**

- [ ] **5.1** `git switch -c feat/design-system`
- [ ] **5.2** Mark the remaining Phase 4 steps and its ✅ status in the **Progress** table.

**🤖 CLAUDE CODE — Folder structure**

- [ ] **5.3** Create the structure:
  ```
  Guldr/
  ├── App/
  ├── Core/DesignSystem/
  ├── Core/Extensions/
  ├── Data/Models/
  ├── Data/Persistence/
  ├── Features/Dashboard/
  ├── Features/Transactions/
  ├── Features/Budget/
  ├── Features/Charts/
  ├── Features/Settings/
  └── Resources/
  ```
- [ ] **5.4** Move `GuldrApp.swift` and `ContentView.swift` to `Guldr/App/`.
- [ ] **5.5** Move `Guldr/Assets.xcassets` to `Guldr/Resources/`.
- [ ] **5.6** Add a `.gitkeep` to every folder left empty.
- [ ] **5.7** ✅ Build.
- [ ] **5.8** Commit: `refactor: organize project into feature-based folders`

**🤖 CLAUDE CODE — Design specification**

- [ ] **5.9** Copy the design package, without the `xcode/` folder:
  ```bash
  SRC=~/Downloads/Guldr/GuldrDesign
  [ -d "$SRC" ] || unzip -q ~/Downloads/Guldr/GuldrDesign.zip -d ~/Downloads/Guldr
  mkdir -p docs/design
  rsync -a --exclude xcode "$SRC"/ docs/design/
  ```
  Expected in `docs/design/`: `DESIGN.md`, `tokens.json`, `mockups/`, `icon/`, `wordmark/`, `fonts/`.
- [ ] **5.10** In `docs/design/DESIGN.md`, in the *Folder map* table, replace `xcode/GuldrColors.xcassets` with `Guldr/Resources/GuldrColors.xcassets`.
- [ ] **5.11** Append to `CLAUDE.md`:
  ```markdown
  ## Design system
  - Visual source of truth: `docs/design/DESIGN.md` (values in `docs/design/tokens.json`).
  - Before building or changing a screen, read DESIGN.md and its mockup in `docs/design/mockups/`.
  - Colors only from the `GuldrColors` asset catalog (`Color(.goldFill)` etc.). Never hard-coded hex.
  - Do not invent colors, sizes or radii. If something is missing, ask, then document it in DESIGN.md.
  - Native components first (TabView, NavigationStack, sheets, segmented Picker).
  - Every view gets previews in light and dark.
  ```
- [ ] **5.12** Commit: `docs: add guldr design system specification`

**🤖 CLAUDE CODE — Architecture**

- [ ] **5.13** Create `docs/ARCHITECTURE.md`: targets (app and widget), App Group and `Config/*.xcconfig`, folder structure and each layer's responsibility, MVVM with `@Observable`, and a Mermaid diagram. Persistence and widget sections are completed in their phases.
- [ ] **5.14** Link `docs/ARCHITECTURE.md` from `README.md` and `CLAUDE.md`.
- [ ] **5.15** Commit: `docs: add architecture overview`

**🤖 CLAUDE CODE — Colors**

- [ ] **5.16** Copy the color catalog into the target:
  ```bash
  cp -R ~/Downloads/Guldr/GuldrDesign/xcode/GuldrColors.xcassets Guldr/Resources/
  ```

**🧑 YOU**

- [ ] **5.17** Select `Guldr/Resources/GuldrColors.xcassets` and in **File Inspector ▸ Target Membership** also check **GuldrWidgetExtension**.
- [ ] **5.18** Confirm in Build Settings that `Generate Swift Asset Symbol Extensions` = Yes.

**🤖 CLAUDE CODE**

- [ ] **5.19** ✅ 21 colors + `Contents.json`:
  ```bash
  ls Guldr/Resources/GuldrColors.xcassets | wc -l    # 22
  ```
- [ ] **5.20** Commit: `feat: add guldr color asset catalog`

**🤖 CLAUDE CODE — Wordmark**

- [ ] **5.21** Copy the SVGs into the app catalog:
  ```bash
  D=Guldr/Resources/Assets.xcassets/Wordmark.imageset
  mkdir -p $D
  cp docs/design/wordmark/guldr-wordmark-dark.svg docs/design/wordmark/guldr-wordmark-light.svg $D/
  ```
- [ ] **5.22** Create `Wordmark.imageset/Contents.json`:
  ```json
  {
    "images" : [
      { "filename" : "guldr-wordmark-dark.svg", "idiom" : "universal" },
      {
        "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
        "filename" : "guldr-wordmark-light.svg",
        "idiom" : "universal"
      }
    ],
    "info" : { "author" : "xcode", "version" : 1 },
    "properties" : { "preserves-vector-representation" : true }
  }
  ```
- [ ] **5.23** ✅ Build.
- [ ] **5.24** Commit: `feat: add vector wordmark asset`

**Visual check** (not committed)

- [ ] **5.25** 🤖 In `ContentView`, add temporary light and dark previews with `Image(.wordmark)` and a text in `Color(.goldFill)`, and build.
- [ ] **5.26** 🧑 Review the previews in Xcode and confirm they look right.
- [ ] **5.27** 🤖 Revert the change: `git restore Guldr/App/ContentView.swift`

**✅ VERIFY**

- [ ] **5.28** No raw hex values in Swift:
  ```bash
  grep -rn "#[0-9A-Fa-f]\{6\}" Guldr --include="*.swift" | wc -l   # 0
  ```

**🤖 CLAUDE CODE — PR cycle**

- [ ] **5.29** Commit: `docs: update bootstrap progress for phase 5`
- [ ] **5.30** `git push -u origin feat/design-system`
- [ ] **5.31** `gh pr create --base main --title "feat: add design system foundations" --fill`
- [ ] **5.32** `gh pr checks --watch` → CI green.
- [ ] **5.33** `gh pr merge --rebase --delete-branch`
- [ ] **5.34** `git switch main && git pull`

---

## Phase 6 — App icon with Icon Composer · branch `feat/app-icon`

**🤖 CLAUDE CODE**

- [ ] **6.1** `git switch -c feat/app-icon`
- [ ] **6.2** Mark the remaining Phase 5 steps and its ✅ status in the **Progress** table.

**🧑 YOU — Icon Composer**

- [ ] **6.3** Open **Xcode ▸ Open Developer Tool ▸ Icon Composer ▸ File ▸ New**.
- [ ] **6.4** Drag `docs/design/icon/guldr-glyph-gold.svg` into the sidebar.
- [ ] **6.5** Select the icon's root row → **Fill: Solid `#111111`**.
- [ ] **6.6** Select the group and tune Liquid Glass: specular on, low translucency, neutral shadow.
- [ ] **6.7** Compare with `docs/design/icon/preview-default-1024.png` until the gold looks matte.
- [ ] **6.8** **Default** appearance: `#111111` background, gold glyph.
- [ ] **6.9** **Dark** appearance: same as Default.
- [ ] **6.10** **Mono** appearance: white layer fill.
- [ ] **6.11** Save as **`Guldr/Resources/Guldr.icon`** (it joins the app target through the synchronized folder).
- [ ] **6.12** **Target Guldr ▸ General ▸ App Icons**: `Guldr`.

**🤖 CLAUDE CODE**

- [ ] **6.13** Delete the template's empty icon: `rm -rf Guldr/Resources/Assets.xcassets/AppIcon.appiconset`
- [ ] **6.14** ✅ Build.
- [ ] **6.15** Commit: `feat: add app icon from icon composer`

**🧑 YOU**

- [ ] **6.16** Run on your iPhone and check the icon in light mode.
- [ ] **6.17** Check the icon in dark mode.
- [ ] **6.18** Check the icon in tinted mode.

**🤖 CLAUDE CODE — PR cycle**

- [ ] **6.19** Commit: `docs: update bootstrap progress for phase 6`
- [ ] **6.20** `git push -u origin feat/app-icon`
- [ ] **6.21** `gh pr create --base main --title "feat: add app icon" --fill`
- [ ] **6.22** `gh pr checks --watch` → CI green.
- [ ] **6.23** `gh pr merge --rebase --delete-branch`
- [ ] **6.24** `git switch main && git pull`

---

## Phase 7 — Privacy and localization · branch `chore/privacy-and-localization`

**🤖 CLAUDE CODE**

- [ ] **7.1** `git switch -c chore/privacy-and-localization`
- [ ] **7.2** Mark the remaining Phase 6 steps and its ✅ status in the **Progress** table.

**🤖 CLAUDE CODE — Privacy manifest**

- [ ] **7.3** Create `Guldr/Resources/PrivacyInfo.xcprivacy`:
  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
      <key>NSPrivacyTracking</key>
      <false/>
      <key>NSPrivacyTrackingDomains</key>
      <array/>
      <key>NSPrivacyCollectedDataTypes</key>
      <array/>
      <key>NSPrivacyAccessedAPITypes</key>
      <array>
          <dict>
              <key>NSPrivacyAccessedAPIType</key>
              <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
              <key>NSPrivacyAccessedAPITypeReasons</key>
              <array>
                  <string>CA92.1</string>
                  <string>1C8F.1</string>
              </array>
          </dict>
      </array>
  </dict>
  </plist>
  ```
  The widget's manifest is added in the PR that decides how it reads data (widget ADR).
- [ ] **7.4** ✅ `plutil -lint Guldr/Resources/PrivacyInfo.xcprivacy`
- [ ] **7.5** Commit: `chore: add privacy manifest`

**🤖 CLAUDE CODE — String Catalog**

- [ ] **7.6** Create `Guldr/Resources/Localizable.xcstrings`:
  ```json
  {
    "sourceLanguage" : "en",
    "strings" : {},
    "version" : "1.0"
  }
  ```

**🧑 YOU**

- [ ] **7.7** Open `Localizable.xcstrings` in Xcode and press **+ ▸ Spanish (es)**. This adds Spanish to the project.
- [ ] **7.8** Build once so Xcode extracts the existing strings.

**🤖 CLAUDE CODE**

- [ ] **7.9** ✅ Spanish is in the project (read-only):
  ```bash
  grep -c '"es"' Guldr.xcodeproj/project.pbxproj   # > 0
  ```
- [ ] **7.10** Commit: `feat: add english and spanish string catalog`

**🤖 CLAUDE CODE — PR cycle**

- [ ] **7.11** Commit: `docs: update bootstrap progress for phase 7`
- [ ] **7.12** `git push -u origin chore/privacy-and-localization`
- [ ] **7.13** `gh pr create --base main --title "chore: add privacy manifest and localization" --fill`
- [ ] **7.14** `gh pr checks --watch` → CI green.
- [ ] **7.15** `gh pr merge --rebase --delete-branch`
- [ ] **7.16** `git switch main && git pull`

---

## Phase 8 — SwiftLint · branch `chore/swiftlint`

**🤖 CLAUDE CODE**

- [ ] **8.1** `git switch -c chore/swiftlint`
- [ ] **8.2** Mark the remaining Phase 7 steps and its ✅ status in the **Progress** table.
- [ ] **8.3** Create `.swiftlint.yml`:
  ```yaml
  included:
    - Guldr
    - GuldrWidget
    - GuldrTests
  excluded:
    - docs
  opt_in_rules:
    - empty_count
    - explicit_init
    - first_where
    - sorted_first_last
    - toggle_bool
    - unused_optional_binding
  line_length:
    warning: 140
    error: 200
  identifier_name:
    excluded: [id, x, y]
  ```

**🧑 YOU**

- [ ] **8.4** **File ▸ Add Package Dependencies** → `https://github.com/SimplyDanny/SwiftLintPlugins`, **without** linking it to any target.
- [ ] **8.5** **Target Guldr ▸ Build Phases ▸ Run Build Tool Plug-ins ▸ +** ▸ `SwiftLintBuildToolPlugin`.
- [ ] **8.6** Same on **GuldrWidgetExtension**.
- [ ] **8.7** Same on **GuldrTests**.
- [ ] **8.8** Accept **Trust & Enable**.

**🤖 CLAUDE CODE**

- [ ] **8.9** Add a **Linting** section to `docs/WORKFLOW.md`.
- [ ] **8.10** Add the "zero SwiftLint warnings" rule to `CLAUDE.md`.
- [ ] **8.11** Commit: `chore: add swiftlint build plugin and configuration`
- [ ] **8.12** ✅ Build with `-skipPackagePluginValidation` and list the warnings.
- [ ] **8.13** Fix the warnings in template code. If anything changed, commit: `style: fix swiftlint warnings in template code`

**🤖 CLAUDE CODE — PR cycle**

- [ ] **8.14** Commit: `docs: update bootstrap progress for phase 8`
- [ ] **8.15** `git push -u origin chore/swiftlint`
- [ ] **8.16** `gh pr create --base main --title "chore: add SwiftLint" --fill`
- [ ] **8.17** `gh pr checks --watch` → CI green with the plugin active.
- [ ] **8.18** `gh pr merge --rebase --delete-branch`
- [ ] **8.19** `git switch main && git pull`

---

## Summary

| Phase | Branch | PR | Commits |
|---|---|---|---|
| 0 | — | — | — |
| 1 | `chore/project-foundations` | chore: add project foundations | 8 |
| 2 | `ci/github-actions` | ci: add GitHub Actions workflow | 3 |
| 3 | `feat/widget-target` | feat: add GuldrWidget extension target | 2 |
| 4 | `chore/build-configuration` | chore: configure signing, app group and build settings | 5 |
| 5 | `feat/design-system` | feat: add design system foundations | 6 |
| 6 | `feat/app-icon` | feat: add app icon | 2 |
| 7 | `chore/privacy-and-localization` | chore: add privacy manifest and localization | 3 |
| 8 | `chore/swiftlint` | chore: add SwiftLint | 2–3 |

## Final verification (🤖 CLAUDE CODE)

Done on the data layer branch, together with the remaining Phase 8 marks.

```bash
git log --oneline | head -40
gh run list --limit 3
xcodebuild test -project Guldr.xcodeproj -scheme Guldr -destination "platform=iOS Simulator,name=$SIM,OS=latest" | tail -5
ls docs docs/design docs/decisions
```

- [ ] `main` protected (ruleset + local hooks) and CI green; no direct commits on `main`
- [ ] App and widget run on the iPhone
- [ ] App Group shared; iCloud **not** added
- [ ] Version and App Group come from `Config/*.xcconfig`; the `AppGroupID` test passes
- [ ] `GuldrColors` in both targets; vector wordmark with a dark variant
- [ ] `Guldr.icon` assigned and checked in light, dark and tinted
- [ ] Privacy manifest and EN/ES String Catalog
- [ ] SwiftLint active on the targets
- [ ] README, CLAUDE.md, WORKFLOW, ROADMAP, ARCHITECTURE, DESIGN, ADR 000–004
- [ ] Everything in the repository is in English

## Next: data layer · branch `feat/data-layer`

- [ ] `Transaction`, `Category` and `Budget` models, CloudKit-compatible, with `currencyCode`.
- [ ] A `ModelContainer` shared through the App Group, without `fatalError`.
- [ ] Tests for the calculations: balance, monthly income and expenses, budget usage.
- [ ] ADRs for SwiftData, the shared container and `currencyCode`.
- [ ] Persistence section in `docs/ARCHITECTURE.md`.

`Old_FinTrackPro` is reference only: explain the old code, note what changes and why, write it, test it and open the PR.

## When v1.0 ships · branch `docs/release-1.0`

- [ ] Final `README.md`: badges, 10-second GIF, screenshots (dashboard, charts, widget, add transaction), stack and diagram.
- [ ] `docs/PRIVACY.md`: privacy policy (data stays on device), for the URL App Store Connect requires.
- [ ] `CHANGELOG.md` starting at `v1.0.0`.
- [ ] Tag `v1.0.0` after the merge.

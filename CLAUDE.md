# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## ⚠️ Path Structure — Read First

The repo root is **not** the Xcode project. All source, tests, and builds live one level deeper:

| What | Path from repo root |
|---|---|
| Source files | `TheRecruitingCompass/TheRecruitingCompass/` |
| Unit tests | `TheRecruitingCompass/TheRecruitingCompassTests/` |
| UI tests | `TheRecruitingCompass/TheRecruitingCompassUITests/` |
| Xcode project | `TheRecruitingCompass/TheRecruitingCompass.xcodeproj` |

**All `xcodebuild` commands must run from `TheRecruitingCompass/` (the Xcode project wrapper), not the repo root.**

When editing or creating source files, always use the full double-nested path, e.g.:
- ✅ `TheRecruitingCompass/TheRecruitingCompass/Features/Auth/Views/LoginView.swift`
- ❌ `TheRecruitingCompass/Features/Auth/Views/LoginView.swift` (wrong — one level too shallow)

---

## Build & Test

`make build`, `make test`, `make test-unit`, `make test-unit-fast` (see `Makefile`), or `xcodebuild build -scheme TheRecruitingCompass` from `TheRecruitingCompass/`; tests go through `scripts/run-ios-tests.sh` (below).

- **Simulator names churn** between Xcode betas — run `xcrun simctl list devices available | grep iPhone` and target by `id=` rather than assuming `name=iPhone 17` exists.
- CI uses `platform=iOS Simulator,OS=latest,name=iPhone 16` with explicit boot; `OS=latest` prevents xcodebuild from selecting unstable simulator clones.
- **Run every simulator test through `scripts/run-ios-tests.sh`, never a raw `xcodebuild test`.** This Mac gets
  overrun when two runs boot simulators at once, so the script takes one machine-wide lock (shared by every agent,
  worktree and the nightly) and waits its turn. It builds first, outside the lock, then tests serially
  (`-parallel-testing-enabled NO`, `-collect-test-diagnostics never`) on the shared `TRC Agent iPhone` and shuts it down
  afterwards, pass or fail. Examples: `scripts/run-ios-tests.sh --only TheRecruitingCompassTests/FooTests`,
  `--ui`, `--destination 'name=iPad Air 11-inch (M4)'`, `-- <extra xcodebuild args>`; `--help` lists the rest.
  The last line is `run-ios-tests: ** TEST SUCCEEDED **` or `** TEST FAILED **`; exit 75 = gave up waiting for the
  lock, 124 = stalled 20 min, 70 = invalid run (simulator error, not a test result). `make test-*` uses it too.
  Never `simctl shutdown all`, `erase all` or `killall` CoreSimulator — other runs share the Mac. Name any
  hand-made throwaway simulator `trc-<issue>`/`agent-<label>` so the hourly sweep (`scripts/sim_sweep.py`) can delete
  it; `~/.config/recruiting-compass/sim-sweep-keep` exempts a device from the sweep and from shutdown.
  `python3 scripts/sim_sweep.py --tests-running` shows who holds the lock.
  Never rename or delete DerivedData, and never shut down keep-listed devices (including Perf iPhone 17).
  When waiting on a run, match the script's final line, not `started`, with one monitor per run. On exit 124,
  report the stall instead of retrying in a loop.
- **~3700 unit tests.** The full suite exceeds 10 minutes — run the affected test classes via `--only` for fast evidence and trust the exit code.

### Environment Configuration

DEBUG runs read `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `API_BASE_URL` from a **local (unshared) scheme's** Run environment variables; archived builds read only `Release.xcconfig` (gitignored). Full setup: `docs/CONFIGURATION.md`.

**App Store builds go through Xcode Cloud** — `ci_scripts/ci_post_clone.sh` writes `Release.xcconfig` from the workflow
environment. Local archives (beta Xcode) are for internal TestFlight only; App Store Connect rejects them.

**`API_BASE_URL` is required**, not optional — family creation (signup/onboarding) has no direct-Supabase fallback and throws without it, and the dashboard Action Items widget silently shows empty.

---

## Architecture Overview

Schools is the **clean-architecture reference**. Other features still use feature-MVVM. See `docs/CLEAN_ARCHITECTURE.md`.

Views call `SchoolsFactory.makeListViewModel()` (etc.). Do not construct `SchoolsRepositoryImpl` in a view.

`SchoolsManaging` and `SchoolsServiceImpl` remain as typealiases so unconverted features keep compiling.

**MVVM rules (non-Schools features, until converted):**
- **Service** = Data fetching only (no UI state, no @Published)
- **ViewModel** = State management (@Observable, plain properties, async methods)
- **View** = Display state + call ViewModel methods (no business logic)
- **@MainActor** = Required on all ViewModels; Services are NOT @MainActor
- **Protocol-based DI** = All services have protocol interfaces for testing

---

## Accessibility (WCAG AA Compliant)

**Requirements:**
- All interactive elements have `.accessibilityLabel()`
- Form fields grouped with `.accessibilityElement(children: .combine)`
- Decorative icons hidden with `.accessibilityHidden(true)`
- Use semantic fonts (.title, .body, .caption) - NEVER `.system(size: 14)`
- Button hit targets minimum 44x44pt

---

## Creating New Screens

**Xcode project:** This repo uses `PBXFileSystemSynchronizedRootGroup`; new .swift files are included automatically. Do **not** run `scripts/add_files_to_xcode.rb` — it corrupts the project file.

Start from `TheRecruitingCompass/UI/Screens/_ScreenTemplate/`; workflow in `TheRecruitingCompass/UI/Screens/HOW_TO_CREATE_SCREENS.md`.

---

## Project Guidelines

- **Never save working files to root** - use `planning/`, `docs/`, etc.
- Test files mirror source structure

---

## Releases & Versioning

The app is live; old versions stay installed for months. Follow `docs/RELEASE.md`; the `release` skill (`/release`)
walks a release stage by stage from `scripts/release/release-status.mjs`. Rules that affect everyday work:
- **New web-API `URLRequest`s must call `request.addClientHeaders()`** (Supabase requests get them automatically).
- **Server changes are expand-then-contract** — never remove/rename a column, endpoint or response field that an
  iOS version ≥ `app_config.ios_minimum_version` still reads.
- `MARKETING_VERSION` stays numeric `X.Y.Z`; bump it with `fastlane bump_version type:patch|minor|major`, never by hand.
- User-visible features get a `WhatsNewCatalog` entry + `fastlane/metadata/en-US/release_notes.txt` text — drafted per
  release by the `whats-new` skill (`.claude/skills/whats-new`) from `scripts/release/changes-since-release.sh`.

---

## Documentation & References

- `docs/RELEASE.md` - Release checklist, versioning, update gate, hotfixes
- `docs/CODE_PATTERNS.md` - Reusable code patterns
- `docs/TROUBLESHOOTING.md` - Common issues & solutions

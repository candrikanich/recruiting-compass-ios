# One lock for every iOS simulator test run (approved 2026-10-22)

## Why

An audit on 2026-10-21 found nine overlapping controls for simulators and test concurrency on Chris's Mac:
the sim-janitor mod, a new block-concurrent-xcodebuild hook, the hourly `sim_sweep.py`, the keep-list, persistent
sims, the nightly's `--tests-running` poll, the Makefile/`run_ui_tests_resilient.sh`/`shutdown_test_simulator.sh`
trio, the train skill's `/tmp/trc-ios-sim.lock`, and prose rules in three CLAUDE.md files plus memory.
None was real mutual exclusion — each checked, then acted — so two agents could both see "idle" and cold-boot
simulators together, which exhausted memory and stalled everything (2026-10-15, 2026-10-20). The nightly ran
anyway after a 1h wait; the hook blocked builds and quoted text; the web repo's `claude/ios.md` still said
`simctl shutdown all`.

## Decisions (Chris)

1. Script lives in this repo: `scripts/run-ios-tests.sh`.
2. Builds stay outside the lock; only simulator time is serialized.
3. The 2026-10-21 hook is folded into this plan.
4. One shared agent simulator (`TRC Agent iPhone`) replaces clone-per-issue.

## What shipped

- `scripts/lib/ios-test-lock.sh`: `lockf` on `~/Library/Application Support/recruiting-compass/ios-test.lock`,
  held by a child that watches the acquiring PID (a killed run frees it within a second), plus an owner file.
- `scripts/run-ios-tests.sh`: build → lock (waits, 2h default, exit 75 on timeout) → orphaned runtime-service
  cleanup + swap warning → boot → serial test run without diagnostics collection → 20-min stall kill (124) →
  launch-error retry (3 attempts) → shutdown (keep-list and already-booted sims respected). Agent sim runtime comes
  from `~/.config/recruiting-compass/agent-sim-runtime` (iOS 18.6 on Chris's Mac), else newest.
- Makefile test targets, the nightly, and `record-marketing-clips.sh` take the same lock; `run_ui_tests_resilient.sh`
  and `shutdown_test_simulator.sh` are folded in and removed.
- `sim_sweep.py`: counts the lock as a live run, reports its holder in `--tests-running`, kills orphaned
  MTLCompilerService/SetStoreUpdateService when nothing is booted and no run is live.
- Outside the repo: the global hook now blocks only raw `xcodebuild test`/`test-without-building` (quote- and
  heredoc-aware) and points at the script; sim-janitor keeps only session-end cleanup of hand-booted sims;
  global CLAUDE.md, `trc-ios-dev`, the train skill and the web repo's `claude/ios.md` point at the script.

## Not covered

- Xcode ⌘U runs don't take the lock (the script warns when it sees a stray `xcodebuild test`).
- GitHub-hosted iOS CI runs on its own machines.
- Two runs from the *same* worktree share DerivedData; the second build can hit "database is locked".

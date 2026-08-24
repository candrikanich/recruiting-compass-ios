# Handoff — Sport Recruiting Calendar: post-merge state + follow-ups

**Date:** 2026-08-23 · **For:** the next fresh session.
Read memory `sport-recruiting-calendar-shipped.md` first, then this.

## Where things stand (all MERGED)
- **web → develop:** gender field (#434), calendar data+resolver+rewire+refresh (#442), deferred
  cleanup = metric-grouping + services-v2 + positions-drop (#443).
- **iOS → main:** gender field (#52), calendar registry+widget+grad-year parity (#54), deferred
  cleanup = metric-grouping + services-v2 + prune (merged earlier).
- Feature branches `feat/sport-recruiting-calendar` + `feat/deferred-cleanup` **deleted** (both
  repos), worktrees removed. Only `main` (iOS) / primary checkout (web) remain.
- Phase 5 routine `trig_01MaTg3LFwpGLBz8LdKFK5nJ` is live; its script is on develop; first fire
  **2026-11-01** (Feb/May/Aug/Nov). Manage: https://claude.ai/code/routines/trig_01MaTg3LFwpGLBz8LdKFK5nJ

## #1 priority for next session: QA the calendar in a real app
Nothing here was device/browser-verified — unit + build/type-check green only. Verify:
- The `RecruitingCalendar` widget renders on the dashboard AND timeline (web + iOS), per sport.
- Current-period banner shows the MOST-RESTRICTIVE window (e.g. a baseball athlete on 2027-07-04
  shows "Dead", not "Contact").
- M/W toggle appears only for gender-split sports with unset gender; FBS/FCS only for Football.
- Disclaimer + working link to the official NCAA PDF; staleness banner logic.
- Non-baseball athletes: timeline tasks are no longer suppressed by baseball dead periods.

## Pre-existing issues — RESOLVED / TRIAGED 2026-08-23 (web branch `fix/ncaa-milestone-division-scoping`, `5ec04359`, unpushed)
1. **`division:"DI"` milestone — FIXED.** Root cause was the *opposite* of the old note: the
   production `Division` union (`~/utils/recruitingCalendar/types.ts`) is `"D1"|"D2"|"D3"` and
   every caller passes `"D1"`, but the NCAA entries were tagged `"DI"` (the legacy
   `~/types/timeline` encoding) → `matchesDivision` never matched → hidden for D1 athletes. Fix:
   retagged "NCAA Eligibility Center Registration" → `"D1"`; **deleted** the generic "D1 Contact
   Period Begins" entry (contact periods are now sport-specific on each `SportCalendar`); corrected
   the backwards comment. Both dates are already past, so no immediate UI change — unblocks next
   season's transcription. Also fixed the `server/utils` re-export to a relative path (killed the
   recurring unimport WARN). Tests 48/48, type-check + pre-push hook clean.
2. **Web pre-push hook crash — NOT REPRODUCIBLE.** On develop tip (`42cf229d`) the full hook
   (`lint` + `type-check`) runs clean, exit 0, no Abort trap 6. Was a transient node crash; no
   deterministic fix. `--no-verify` no longer needed.
3. **`LogMetricModal.spec.ts` failures — NOT REPRODUCIBLE.** 25/25 pass on develop tip. Gone
   (flake resolved since the handoff). E2E / claude-review CI still routinely red (flake/infra),
   non-blocking, unchanged.
4. **iOS `upcomingMilestones` = sport milestones only** — web merges generic SAT/ACT/deadline lists
   that don't exist on iOS. Accepted platform difference; if iOS should show test/deadline dates,
   that's a new feature (port the generic lists + the grad-year bucket already exists).

## Calendar-quality follow-ups (low priority)
- Data confidence: most 2026-27 dates are single-source (MEDIUM) — the annual refresh routine +
  re-transcription (see `docs/recruiting-calendar-refresh.md`) is the plan. When 2027-28 PDFs drop
  (routine will open an issue), re-transcribe BOTH platforms byte-identically + bump `SEASON`.
- `OTHER_WSOCCER` Jul 28–31 window has a source-doc description/date ambiguity, preserved faithfully
  at MEDIUM confidence — re-check against next year's PDF.
- ~~iOS widget: no live-clock injection seam~~ **DONE 2026-08-23** — added an injectable `now: Date
  = Date()` to `RecruitingCalendarWidget` feeding `todayISO`. Note: the view's period/staleness
  computed props are still `private`, so this only enables deterministic rendering / future snapshot
  tests — the repo has no SwiftUI view-inspection harness, so no unit coverage was added.
- ~~iOS `@State` M/W & FBS/FCS toggles don't reset on sport/gender change~~ **DONE 2026-08-23** —
  added `.onChange(of: sport)` (resets both toggles) + `.onChange(of: gender)` (resets Women's) in
  `RecruitingCalendarWidget`. Self-contained (doesn't rely on a caller applying `.id`).
- Data confidence + `OTHER_WSOCCER` ambiguity above remain the only open calendar-quality items,
  both blocked on next year's PDFs (routine-driven).

## Carried-over backlog (migrated from the now-retired baseball-deprecation deferred handoff)
That handoff's items 1–4 (services v2, metric grouping, NCAA calendar, positions-drop) are all DONE
+ merged. These remain open and are device/discovery-gated:
- **Recruiting services DEFERRED-4** — 4 sport services need a real profile URL captured on-device
  before adding to the registry (byte-identical both platforms): TopDrawerSoccer (Soccer), Junior
  Golf Scoreboard (Golf), TrackWrestling + FloWrestling (Wrestling). Also confirm on-device the
  Athletic.net `/athlete/{id}` + Elite Prospects `/player/{id}` bare-id→slug 301 redirects still
  work (an agent fetch hit 403 bot-protection), and note Concept2 / Tennis Recruiting profiles may
  be login/privacy-gated (link still valid, just say so in UI copy).
- **Minor, probably skip:** iOS template `{{sport}}` reads only `prefs.primary_sport` while web
  reads the FK first then prefs (never diverges in practice); `category`-on-`MetricDef` is a known
  anti-pattern (use the per-sport group map); iOS `MetricDef` has no `icon` field by design.

## Retired references
- `planning/2026-08-23-baseball-deprecation-deferred-handoff.md` — **deleted 2026-08-23**; open
  items migrated above.
- `planning/2026-08-02-ios-audit-remediation-plan.md` — **RETIRED (not recreating).** Missing for
  many sessions; the two localization specs that cite it (`docs/superpowers/specs/2026-08-05-*`)
  already document it as lost-with-a-deleted-worktree and are explicitly self-contained. No live
  plan depends on it.

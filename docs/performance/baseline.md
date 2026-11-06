# iOS Performance Baseline

Tracking issue: #244. Budgets (device, Release build) live there and in the performance pass plan.

How to reproduce everything on this page: [Running it](#running-it).

## Status

| Layer | State |
|---|---|
| Network per screen (#240) | Recorded 2026-10-02 — see below; re-measured after the #269–#271 fixes |
| Memory, simulator (#239) | Recorded 2026-10-02, stable across two runs |
| Cold launch, simulator (#239) | Recorded 2026-10-02 — 2.48 s, three runs within 3.5% |
| Scroll hitches | Recorded on device 2026-10-06 — all four screens under budget (#242) |
| Device (Instruments) | Recorded 2026-10-05/06 — one budget miss: School Detail map hang (#286) |
| Field (Organizer, Sentry hangs) | Blocked until 1.0 has been live 14 days (#243) |

## Network per screen — 2026-10-02

Commit `a5a9b608` plus the perf test. iPhone 17 simulator, iOS 27.2, Debug build, local Supabase stack. Account:
the demo family plus the large-account seed — 68 schools, 248 interactions, 122 notifications, 33 events.

"launch" is sign-in through a settled Dashboard. Each later row is opening that screen from the previous one.

| Screen | Source | Requests | Response KB | Largest response |
|---|---|---|---|---|
| launch → Dashboard | app → Supabase | 60 | 383.8 | `schools` — 88.0 KB |
| launch → Dashboard | app → web API | 8 | 6.3 | `/api/schools/recommendations` — 1.6 KB |
| Schools list | app → Supabase | 5 | 268.7 | `interactions` — 156.6 KB |
| Recruiting Timeline | app → Supabase | 11 | 58.8 | `task` — 13.2 KB |
| Recruiting Timeline | app → web API | 3 | 1.5 | `/api/athlete/what-matters-now` — 1.1 KB |
| Notifications | app → Supabase | 2 | 50.7 | `notifications` — 50.6 KB |

The web API's own calls to Supabase (36 on launch, 14 on Timeline) are left out: the web checkout used for the
run was not on `main`, so they are not a fair picture of production.

### Findings

Each was confirmed in the raw gateway log, then traced to code.

| # | Finding | Evidence | Where | Issue |
|---|---|---|---|---|
| 1 | The full four-grade task set loads twice on launch and a third time when Timeline opens. Each load sends 4 `task` + 4 **identical** `athlete_task` queries. | launch: `task` ×8 (88.3 KB), `athlete_task` ×8 (28.4 KB); Timeline: ×4 + ×4 (58.4 KB) | `TasksServiceImpl.fetchAllTasksWithStatus` fetches `athlete_task` once per grade; `DashboardView` owns its own `TimelineViewModel` and loads it from `.task` and from `onChange(of: selectedAthleteId)` | #269 |
| 2 | The signed-in user's row is read 12 times in about two seconds on launch, and `user_preferences` 6 times. | `users?select=*` ×6, narrow `users` selects ×6, `user_preferences` ×6 | `SupabaseManager.fetchUserProfile` plus per-feature single-column reads (`graduation_year`, `nux_progress`, `phase_milestone_data`) | #270 |
| 3 | Schools list downloads every interaction and every event for the family with `select=*` and no limit. Payload grows with account age. | `interactions` 156.6 KB for 248 rows; `events` 23.5 KB; `schools` `select=*` 88.0 KB for 68 rows | `SchoolsListViewModel.refreshInteractionDerivedIds` | #271 |

Written off:

- **Notifications has no limit** — deliberate. PR #77 removed the 100-row cap to match the web inbox, and the
  query already selects a column list. 50.6 KB at 122 rows; revisit if field data shows large inboxes.
- **`get_ios_version_policy` on most screens** — the update gate; 0.1 KB per call.

Web parity (read from web code, not measured): the web dashboard uses explicit column lists and a row limit for
schools and interactions (`useDashboardData.ts`), and serves tasks from a cached `/api/tasks` with an explicit
column list. The web schools store also uses `select("*")`, so finding 3's `schools` payload applies to both
platforms.

The per-request breakdown the table was built from is in [network-2026-10-02.md](network-2026-10-02.md).
`select=*` and "no limit" are read from the URL; a limit sent as a `Range` header would not show up.

## After the fixes for #269, #270, #271 — 2026-10-02

Same simulator, account and local stack. App → Supabase requests only.

| Screen | Requests before | Requests after | KB before | KB after |
|---|---|---|---|---|
| launch → Dashboard | 61 | 37 | 383.8 | 260.3 |
| Schools list | 5 | 5 | 268.7 | 106.4 |
| Recruiting Timeline | 10 | 4 | 58.8 | 48.1 |
| Notifications | 1 | 1 | 50.6 | 50.6 |

"Before" here is a fresh run in the same session as "after", so it differs by a request from the table above.

| Finding | Before | After | What is left |
|---|---|---|---|
| 1 — timeline tasks (#269) | launch: `task` ×8, `athlete_task` ×8. Timeline: ×4 + ×4 | launch: none. Timeline: `task` ×1, `athlete_task` ×1 | The single `task` query is still `select=*` (44.2 KB). Kept: an explicit column list would break older app versions if a column is ever dropped |
| 2 — user row (#270) | launch: `users` ×12, `user_preferences` ×6 | launch: `users` ×6, `user_preferences` ×4 | Two full-profile reads (sign-in, then a session refresh a second later) and four single-column reads by separate features; `player` preferences are still read by two features. Short of the 2 + 1 target in the issue |
| 3 — Schools list (#271) | `interactions` 156.6 KB, `events` 23.5 KB | `interactions` 17.7 KB (two columns), `events` 0.1 KB (visits only, two columns) | `schools` `select=*` (88.0 KB) is unchanged: the same rows feed School Detail, export and the fit calculators |

Per-request breakdown: [network-2026-10-02-after.md](network-2026-10-02-after.md).

Not shown by this walk, covered by unit tests instead: a cold start with a saved session now reads the profile
once rather than twice (`AuthManagerSessionRefreshTests`).

## Simulator — 2026-10-02

iPhone 17 simulator, iOS 27.2, Debug build, same account. Two runs of five iterations each. Simulator numbers
compare commit to commit on the same machine; they are not judged against the device budgets.

### Peak memory after one fast scroll

| Screen | Run 1 (MB) | Run 2 (MB) | Spread within a run |
|---|---|---|---|
| Dashboard | 94.8 | 94.7 | 0.2% |
| Schools list | 104.2 | 104.0 | 0.3% |
| Recruiting Timeline | 108.9 | 108.6 | 0.2% |
| Notifications | 109.5 | 109.8 | 0.1% |

### Cold launch

Process start to the first frame of the landing screen (`--uitesting` clears the session). Three runs of five
launches each, `test-without-building`, with no other job running.

| Run | Average (s) | Spread within the run |
|---|---|---|
| 1 | 2.53 | 3.8% |
| 2 | 2.44 | 1.0% |
| 3 | 2.47 | 1.4% |

**Baseline: 2.48 s** (mean of the three; they agree within 3.5%). A change of more than about 5% is a real
regression.

This is a Debug build on the simulator, launched through the XCTest harness, so it is not comparable to the
400 ms device budget — that is judged in #242. It replaces three earlier runs taken while other jobs were
building (3.58–5.24 s, 19–37% spread), which were discarded.

### Scroll hitches — device only

`XCTOSSignpostMetric.scrollingAndDecelerationMetric` reports only the gesture duration on the simulator (a
constant 2.56 s) and no hitch metrics; the Dashboard reported no scroll metric at all. Hitch time ratio has to
come from a device: run the same tests with a device destination, or use Instruments (#242).

## Device — 2026-10-05/06

iPhone 17 Pro Max, iOS 27.2, the installed 1.0 (1) build, a real signed-in account (50+ schools). This is not
the 27.1-SDK Release build from the plan; re-run on that build when #219 unblocks. Traces are kept off-repo.

### Cold launch (App Launch template)

Process start to the first frame (start of *Foreground – Active*).

| Run | Start → first frame | Initial frame rendering | `sceneWillConnectTo` |
|---|---|---|---|
| 1 (cold) | 215 ms | 64 ms | 18 ms |
| 2 | 160 ms | 42 ms | 9 ms |
| 3 | 162 ms | 38 ms | 9 ms |

Budget ≤ 400 ms: **passes**. `didFinishLaunchingWithOptions` is under 1 ms. Launch to *dashboard content* is
not measured here; it is bound by the duplicate fetches in #269 and #270.

### Scrolling (Animation Hitches template)

One screen per 60 s run, scrolling continuously.

| Screen | Hitch time ratio | App hitches (max) | Hangs ≥ 250 ms |
|---|---|---|---|
| Dashboard | 2.5 ms/s | 4 (83 ms) | none |
| Schools list | 1.1 ms/s | 2 (50 ms) | none |
| Recruiting Timeline | 1.3 ms/s | 4 (25 ms) | none |
| Notifications | 0.8 ms/s | 3 (17 ms) | none |

Budget < 5 ms/s and no hang ≥ 250 ms: **passes** on every list.

**Budget miss — School Detail.** The first School Detail opened in a session freezes the main thread for about
2.4 s while `SchoolMapView` creates the first `MKMapView` (#286).

### Memory (Allocations template)

Five round trips through every tab in 75 s. About 2.2 MB stays alive after the first trip. It is one-time
setup (Swift conformance caches, a JavaScriptCore stack, tab-bar layers) and does not grow per trip:
**passes**.

### SwiftUI updates

45 s on Dashboard: total body-update work is small (`Text` 42 ms, `_ConditionalContent` 37 ms; no app view above
6 ms). `DashboardView` re-evaluated its body 25 times, which is cheap but may be the same churn as #270.
Schools-list body counts are not yet captured; they are part of #241.

### Recording gotchas

- Write the trace and `TMPDIR` to an external drive. A full internal disk crashes `xctrace` while it saves.
- After any `xctrace` crash the phone shows as offline ("Timed out waiting for device to boot"). Kill the stale
  helpers (`dtsecurity`, `xctrace`, `Instruments`) and it comes back.
- Keep runs to 75 s or less. In a 90 s deferred-mode run, CPU data stopped at 79.9 s and Instruments reported a
  fake open-ended "Severe Hang" for the rest of the recording.
- Saving a trace takes 3–5 minutes.

## Running it

Local stack (Docker running; `WEB` is the web repo checkout):

```bash
supabase start --workdir "$WEB"
export SUPABASE_SERVICE_ROLE_KEY=...   # from `supabase status -o env --workdir "$WEB"`
cd scripts && npx tsx seed-demo-screenshots.ts && npx tsx seed-perf-large.ts
```

Web API on :3003 against the local stack. `nuxi dev` runs out of file descriptors on this checkout, so build a
Node server instead — and override every Supabase variable, because the web repo's `.env` points at production:

```bash
cd "$WEB" && NITRO_PRESET=node-server npx nuxi build
SUPABASE_URL=http://127.0.0.1:54321 NUXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321 \
  NUXT_PUBLIC_SUPABASE_ANON_KEY=<local anon key> SUPABASE_SERVICE_ROLE_KEY=<local service key> \
  RESEND_API_KEY= NUXT_PUBLIC_SENTRY_DSN= PORT=3003 HOST=localhost \
  node --env-file=.env .output/server/index.mjs
```

Timed tests, from `TheRecruitingCompass/`. Use a simulator no other job is using, and turn off parallel
testing so xcodebuild does not clone it:

```bash
TEST_RUNNER_PERF_BASELINE=1 xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,id=<UDID>' -parallel-testing-enabled NO \
  -only-testing:TheRecruitingCompassUITests/PerformanceBaselineTests
```

Network table:

```bash
node scripts/perf/api-log-proxy.mjs 3004 3003 > api.log &
date -u +%Y-%m-%dT%H:%M:%SZ > start.txt
TEST_RUNNER_PERF_BASELINE=1 TEST_RUNNER_PERF_API_BASE_URL=http://localhost:3004 xcodebuild test \
  -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,id=<UDID>' -parallel-testing-enabled NO \
  -only-testing:TheRecruitingCompassUITests/PerformanceBaselineTests/testNetworkWalk > walk.log
docker logs -t --since "$(cat start.txt)" supabase_kong_recruiting-compass-web > kong.log 2>&1
node scripts/perf/network-table.mjs walk.log kong.log api.log
```

The local stack is shared with anything else running against it, so the script counts only requests carrying
the app's own user agent (`myCompass/…`). "web API → Supabase" rows include every Node process on the stack
and are only meaningful when nothing else is using it.

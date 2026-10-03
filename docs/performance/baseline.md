# iOS Performance Baseline

Tracking issue: #244. Budgets (device, Release build) live there and in the performance pass plan.

How to reproduce everything on this page: [Running it](#running-it).

## Status

| Layer | State |
|---|---|
| Network per screen (#240) | Recorded 2026-10-02 — see below |
| Memory, simulator (#239) | Recorded 2026-10-02, stable across two runs |
| Cold launch, simulator (#239) | Recorded 2026-10-02 — 2.48 s, three runs within 3.5% |
| Scroll hitches | **Not measurable on the simulator** — needs a device (#242) |
| Device (Instruments) | Not yet run (#242) |
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
| 3 | Schools list downloads every interaction and every event for the family with `select=*` and no limit. Payload grows with account age. | `interactions` 156.6 KB for 248 rows; `events` 23.5 KB; `schools` `select=*` 88.0 KB for 68 rows, also fetched twice on launch | Schools list load path | #271 |

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

## Device

Not yet run — #242.

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

# iOS Performance Pass — Plan

**Date:** 2026-10-01 · **Tracking issue:** #244 · **Label:** `performance`

**Goal:** Get measured numbers for the five flows users hit most, then fix only what misses budget.

**Approach:** Measure in three layers — simulator XCTest metrics (relative, committed, repeatable), local-stack
network counts, and one Instruments session on a device — and treat static review findings as hypotheses until a
measurement confirms them. Field data from Xcode Organizer and Sentry app hangs picks the second round after launch.

**Why not a broad audit:** PR #77 (2026-08-28, closed #71) already took the code-reading wins: dashboard count
queries, object-only memory cache, inbox render cost. There is no baseline to audit against — Sentry runs app-hang
tracking only (`Core/Services/CrashReporting.swift`), and nothing uses MetricKit or signposts.

## Global Constraints

- **No privacy-label changes.** Do not enable Sentry tracing (`tracesSampleRate`), profiling, or
  `enableAutoSessionTracking`. Field data comes from Xcode Organizer.
- **No fix without a measurement.** Every fix issue carries the before number, the budget, and how to re-measure.
- **Simulator numbers are relative only.** They compare commit to commit. Budgets are judged on a device.
- **Device runs use a Release-configuration build from the iOS 27.1 SDK** (ties into #219).
- **Parity:** when a screen's query is slimmed on iOS, check the same screen's query on web before closing.
- Perf tests are opt-in (`PERF_BASELINE=1`) and never run in the default unit/E2E jobs.

## Flows in scope

| # | Flow | Entry | Main file |
|---|---|---|---|
| 1 | Cold launch | app start | `TheRecruitingCompassApp.swift`, `Shared/Navigation/AdaptiveRootView.swift` |
| 2 | Dashboard | tab "Dashboard" | `Features/Dashboard/Views/DashboardView.swift`, `MainTabView.swift` |
| 3 | Schools list | tab "Schools" | `Features/Schools/Presentation/Views/SchoolsListView.swift` |
| 4 | Recruiting Timeline | More → "Recruiting Timeline" | `Features/Timeline/Views/RecruitingTimelineView.swift` |
| 5 | Notifications inbox | More → "Notifications" | `Features/Notifications/Views/NotificationsListView.swift` |

## Budgets (device, Release build)

| Metric | Budget | Source |
|---|---|---|
| Cold launch to first frame | ≤ 400 ms | Instruments App Launch |
| Main-thread hangs in the five flows | none ≥ 250 ms | Instruments Hangs |
| Scroll hitch time ratio | < 5 ms/s (5–10 investigate, > 10 fix) | Instruments / XCTest on device |
| Memory | no growth across 5 tab round trips | Allocations |

## Files

- Create: `TheRecruitingCompass/TheRecruitingCompassUITests/Performance/PerformanceBaselineTests.swift`
- Create: `scripts/seed-perf-large.ts` — layers a large account (60 schools, 240 interactions, 120 notifications)
  on top of `seed-demo-screenshots.ts`; the base seed alone has 8 schools and 2 notifications, too few to scroll
- Create: `docs/performance/baseline.md` — every number from Tasks 1–5, with device, OS, commit, date
- Modify: `TheRecruitingCompass/TheRecruitingCompassUITests/TheRecruitingCompassUITests.swift` — delete the
  Xcode-template `testExample` and `testLaunchPerformance` (delete the file if nothing else is left)

---

### Task 1: Committed XCTest baseline — #239

Local stack first, same as the screenshot recipe: `supabase start` in the web repo, `scripts/seed-demo-screenshots.ts`,
web `nuxi dev` on :3003 pointed at local Supabase. Fresh worktrees need `Release.xcconfig` copied from the main
checkout before `xcodebuild` will run.

- [ ] **Step 1: Write the test class**

```swift
import XCTest

/// Performance baseline against the LOCAL seeded stack. Opt-in: skipped unless `PERF_BASELINE=1`.
/// Simulator numbers compare commit to commit; device budgets live in docs/performance/baseline.md.
final class PerformanceBaselineTests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    try XCTSkipUnless(
      ProcessInfo.processInfo.environment["PERF_BASELINE"] == "1",
      "Set PERF_BASELINE=1 to record the performance baseline"
    )
    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launchArguments.append("--local-captcha-bypass")
    app.launchEnvironment["API_BASE_URL"] = "http://localhost:3003"
  }

  /// `--uitesting` clears the session, so this is process start to the first frame of the landing screen.
  @MainActor
  func testColdLaunch() {
    measure(metrics: [XCTApplicationLaunchMetric()]) { app.launch() }
  }

  @MainActor
  func testDashboardScroll() {
    launchSignedIn()
    measureScroll()
  }

  @MainActor
  func testSchoolsListScroll() {
    launchSignedIn()
    XCTAssertTrue(MainTabNavigator(app: app).goTo(.schools))
    measureScroll()
  }

  @MainActor
  func testTimelineScroll() {
    launchSignedIn()
    openMoreRow("Recruiting Timeline")
    measureScroll()
  }

  @MainActor
  func testNotificationsScroll() {
    launchSignedIn()
    openMoreRow("Notifications")
    measureScroll()
  }

  // MARK: - Helpers

  private func launchSignedIn() {
    app.launch()
    let signInLanding = app.buttons["Sign in to your account"]
    XCTAssertTrue(signInLanding.waitForExistence(timeout: 15))
    signInLanding.tap()

    let email = app.textFields.firstMatch
    XCTAssertTrue(email.waitForExistence(timeout: 10))
    email.tap()
    email.typeText("jordan@example.com")

    let password = app.secureTextFields.firstMatch
    password.tap()
    password.typeText("DemoPassword1")

    app.buttons["Sign in to account"].tap()
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30), "Never reached the dashboard")
    let notNow = app.buttons["Not Now"]
    if notNow.waitForExistence(timeout: 5) { notNow.tap() }
  }

  private func openMoreRow(_ rowTitle: String) {
    XCTAssertTrue(MainTabNavigator(app: app).goToMore(), "More tab not reached")
    let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", rowTitle)).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5), "More row \(rowTitle) not found")
    row.tap()
    XCTAssertTrue(app.navigationBars["More"].waitForNonExistence(timeout: 10))
  }

  /// Measures the swipe up only; the swipe down resets position for the next iteration.
  private func measureScroll() {
    let options = XCTMeasureOptions()
    options.invocationOptions = [.manuallyStop]
    let metrics: [XCTMetric] = [
      XCTOSSignpostMetric.scrollingAndDecelerationMetric,
      XCTMemoryMetric(application: app)
    ]
    measure(metrics: metrics, options: options) {
      app.swipeUp(velocity: .fast)
      stopMeasuring()
      app.swipeDown(velocity: .fast)
    }
  }
}
```

- [ ] **Step 2: Confirm it is skipped by default**

Run from `TheRecruitingCompass/` (get the UDID from `xcrun simctl list devices available | grep iPhone`):

```bash
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,id=<UDID>' \
  -only-testing:TheRecruitingCompassUITests/PerformanceBaselineTests
```

Expected: exit 0, five tests skipped.

- [ ] **Step 3: Record the baseline**

```bash
TEST_RUNNER_PERF_BASELINE=1 xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -only-testing:TheRecruitingCompassUITests/PerformanceBaselineTests \
  -resultBundlePath "$CLAUDE_JOB_DIR/tmp/perf-baseline.xcresult"
```

Expected: exit 0, five tests pass. Run it twice; if any metric's relative standard deviation is above 10%, note it
as unstable in the baseline rather than quoting it.

- [ ] **Step 4: Write `docs/performance/baseline.md`**

One table per run: simulator model, iOS runtime, commit SHA, date, and per test — launch duration and peak memory.
Add an empty "Device" section for Task 4 to fill.

> **Corrected 2026-10-02:** the simulator does not report hitch metrics — `scrollingAndDecelerationMetric` yields
> only the gesture duration there. Hitch time ratio comes from a device (Task 4), by running these same tests with
> a device destination or from Instruments. Also run with `-parallel-testing-enabled NO` on a simulator no other
> job is using, and only on an idle machine: launch time varied 19–37% between runs under load.

- [ ] **Step 5: Delete the template tests, build, commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompassUITests docs/performance/baseline.md
git commit -m "test(perf): opt-in XCTest performance baseline for the five hot flows"
```

### Task 2: Per-screen network table — #240

- [ ] **Step 1:** With the local stack running, find the API gateway container: `docker ps --format '{{.Names}}' | grep kong`.
- [ ] **Step 2:** In the simulator, sign in as `jordan@example.com` and walk the five flows, noting the wall-clock
  time each screen is opened. Wait for each screen to settle before moving on.
- [ ] **Step 3:** `docker logs --since <start time> <kong container>` and split the access-log lines by those
  timestamps. Do the same with the `nuxi dev` request log for `/api/*` calls.
- [ ] **Step 4:** Per screen record: request count, total response bytes, slowest request, and the full list of
  paths with query strings.
- [ ] **Step 5:** Flag (a) the same path + query more than once in one screen load, (b) `select=*` on `schools`,
  `interactions`, `events`, `notifications`, (c) list requests with no `limit` or `Range`.
- [ ] **Step 6:** For each flag, open the matching web page with the browser network tab and note whether web
  sends a slimmer query.
- [ ] **Step 7:** Append the table and flags to `docs/performance/baseline.md`. Each flag becomes a `performance`
  issue or gets a one-line reason it is fine. Commit: `docs(perf): per-screen network baseline`.

### Task 3: swiftui-pro review, hypotheses only — #241

- [ ] **Step 1:** Run the `swiftui-pro` skill on the five main files in "Flows in scope" plus their view models.
- [ ] **Step 2:** For each finding write: file:line, the suspected cost, and the measurement that would confirm it
  (which Task 1 metric, Task 2 column, or Instruments template).
- [ ] **Step 3:** Mark each finding **confirmed** or **not reproduced** against Task 1–2 numbers now and Task 4
  traces when they exist.
- [ ] **Step 4:** Append to `docs/performance/baseline.md`. Confirmed findings become `performance` issues. No code
  changes ship from this task.

### Task 4: Instruments session on device — #242 (Chris)

- [ ] **Step 1:** Install a Release-configuration build made with the iOS 27.1 SDK on the iPhone 17; sign in with
  Chris's own production account (50+ schools). Read-only walkthrough — do not create, edit or delete data.
- [ ] **Step 2:** Product → Profile, **App Launch** template. Three cold launches (force-quit between). Record time
  to first frame and time until dashboard content is on screen.
- [ ] **Step 3:** **Hangs** track enabled, walk the five flows, scrolling each list top to bottom. Record every hang
  ≥ 250 ms with the screen and the heaviest main-thread stack.
- [ ] **Step 4:** **SwiftUI** template, scroll each list. Record the views with the highest body-update counts.
- [ ] **Step 5:** **Allocations + Leaks**, five round trips through all tabs. Record footprint after trip 1 and trip 5.
- [ ] **Step 6:** Fill the "Device" section of `docs/performance/baseline.md`. Keep `.trace` files outside the repo.
- [ ] **Step 7:** Each budget miss becomes a `performance` issue with the trace evidence.

### Task 5: Field-data review — #243 (blocked: 1.0 live for 14 days)

- [ ] **Step 1:** Xcode → Organizer → Metrics for 1.0: launch time, hang rate, hitch rate, memory, disk writes, energy.
- [ ] **Step 2:** Sentry project `apple-ios`: app-hang issues, grouped by top frame.
- [ ] **Step 3:** Compare against the device baseline. Append a "Field, 1.0" section to `docs/performance/baseline.md`.
- [ ] **Step 4:** Open `performance` issues for anything outside budget, or close #244 if everything is inside.

### Task 6: Automatic baseline — #248 (blocked: #247)

- [ ] **Step 1:** Once #247 gives a working scheduled UITest environment, add a job that starts the local stack,
  runs both seed scripts, and runs `PerformanceBaselineTests` with `TEST_RUNNER_PERF_BASELINE=1`.
- [ ] **Step 2:** Compare each metric with the committed value in `docs/performance/baseline.md`; flag a regression
  only when it exceeds that metric's recorded run-to-run noise.
- [ ] **Step 3:** Report by commenting on #244 (or a dedicated issue). Compare only runs from the same machine and
  simulator.

---

## Order and owners

| Task | Issue | Owner | Depends on |
|---|---|---|---|
| 1 XCTest baseline | #239 | Claude | local stack |
| 2 Network table | #240 | Claude | local stack |
| 3 swiftui-pro review | #241 | Claude | 1, 2 for confirmation |
| 4 Instruments on device | #242 | Chris | 27.1 SDK build (#219) |
| 5 Field data | #243 | Chris + Claude | 1.0 live 14 days |
| 6 Automatic baseline | #248 | Claude | scheduled UITests working (#247) |

Tasks 1 and 2 can run in parallel. Fixes are separate issues and PRs, each re-running the Task 1 test for a
before/after number.

## Decisions (Chris, 2026-10-02)

1. **Device and account for Task 4:** iPhone 17, signed in as Chris's own production account with 50+ schools.
   That account is used only by Chris, on the device, for a read-only walkthrough. Automated runs (Tasks 1, 2, 6)
   never touch a real account — they use the local stack with the large-account seed layer
   (`scripts/seed-perf-large.ts`).
2. **Older devices:** the budgets are a hard gate on current hardware and the target on older hardware. The
   deployment target is iOS 18.0, so the oldest supported phones are the A12 generation. Older-device numbers come
   from Organizer's per-device breakdown in Task 5, plus a manual run if an older phone is on hand.
3. **Automation:** yes — the perf test should run on a schedule. That needs the scheduled UITest environment fixed
   first (#247); the automation itself is Task 6 / #248.

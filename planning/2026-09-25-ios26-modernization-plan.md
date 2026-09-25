# iOS 26 SDK Modernization Plan

**Date:** 2026-09-25 · **Status:** DRAFT — awaiting decisions in "Open questions"
**Source:** SwiftUI audit against context7 docs. context7 has **no iOS 27 SwiftUI docs** (only iOS 26-era
material), so this targets the documented iOS 26 SDK. Re-audit against Apple's "What's new in SwiftUI"
/ Xcode 27 release notes before starting Phase 7 (new-API bets).

## Baseline (audited 2026-09-25, 859 Swift files)

| Signal | Value |
|---|---|
| Deployment target | iOS 18.0 (4 build configs), README says iOS 17+ (stale) |
| Swift language mode | 5.0 |
| Already modern | 0 `ObservableObject`/`NavigationView`/`foregroundColor`; 69 `@Observable`; 107 `NavigationStack`; 26 `Tab(` |
| Not adopted | `glassEffect`, WidgetKit, AppIntents, SwiftData |
| Concurrency debt | 6 `@unchecked Sendable`, 5 `Task.detached`, 2 `import Combine`, 2 `DispatchQueue` |
| Legacy UI | `MiniBarChart.swift:15` `.cornerRadius`; `AdaptiveDetailLayout` 2× `AnyView` |
| UIKit wrappers | Turnstile (WKWebView), MessageCompose, MailCompose, ShareSheet ×2, VideoPreview, PDFPreview |

## Sequencing

Phase 0 gates everything. Phases 1–3 are independent after it and can run as parallel PRs (different
files). Phase 4 (Swift 6) touches many files — land it alone, last of the mechanical work. Phase 7
needs product sign-off.

```
P0 target bump ──┬─ P1 Liquid Glass
                 ├─ P2 Turnstile WebView spike
                 ├─ P3 small cleanups + subtitles
                 ├─ P4 Swift 6 mode (own PR train)
                 ├─ P5 rich-text TextEditor (optional)
                 └─ P6 Charts upgrades ─► P7 Widgets + App Intents
```

Every phase: TDD for behavior changes, `xcodebuild build` exit 0, affected test classes green (full
~3700-test target exceeds one bg window), a11y check (labels, Dynamic Type, Reduce Motion), iPad + iPhone
visual check, PR via `ship` skill. iOS = main-only; branch off `origin/main`.

---

## Phase 0 — Raise deployment target (rec 1)

**Goal:** iOS 26 floor so later phases need no `#available` forks.
**Blocked on:** Q1 (drop iOS 18–25 users?).

1. Pull App Store Connect / analytics OS-version split → record in this doc. Decide floor.
2. Set `IPHONEOS_DEPLOYMENT_TARGET` in all 4 configs in `project.pbxproj` (CI settings live in pbxproj,
   not xcconfig — see memory). Check `Release.xcconfig` + CI workflow simulator runtime.
3. Delete now-dead `#available(iOS …)` / `@available` guards (grep `#available`).
4. Fix stale README line ("iOS 17+") and `docs/CONFIGURATION.md`.
5. Verify: clean build, unit suite on affected classes, TestFlight-archive dry run on current Xcode beta.

**Fallback if Q1 = keep iOS 18:** wrap Phases 1/2/5 in `#available(iOS 26, *)` with legacy branches; Phase 0
becomes a no-op and PRs grow ~30%.
**Risk:** users on old OS can't update → App Store min-OS change is one-way per release.

## Phase 1 — Liquid Glass adoption (rec 2)

1. **Recompile audit** (no code): build on new Xcode, screenshot every tab on iPhone + iPad; list
   regressions from system chrome changes (custom nav/tab bar backgrounds, `.toolbarBackground`,
   hard-coded bar tints fight glass).
2. Remove custom chrome that duplicates system glass; let `TabView`/`NavigationStack` toolbars adopt it.
3. `.buttonStyle(.glass)` / `.glassProminent` for primary CTAs on high-traffic screens only (dashboard
   quick actions, empty states). Not every button.
4. `AdaptiveRootView.swift` (`NavigationSplitView`, iPad): `.backgroundExtensionEffect` for hero content
   behind sidebar; verify window-resize behavior.
5. Tab bar: evaluate `.tabBarMinimizeBehavior(.onScrollDown)` on long list tabs (Schools, Interactions).
   Search: evaluate `.searchToolbarBehavior` on 10 `.searchable` screens. **Verify exact API names in
   Xcode 26/27 autocomplete before coding — unverified via context7.**
6. Contrast/legibility: glass over content must still pass WCAG AA; test Reduce Transparency + Increase
   Contrast; snapshot tests where they exist.
**Done when:** no visual regressions vs baseline screenshots; a11y settings pass; App Store screenshots
(PR #200 set) re-captured if chrome changed.

## Phase 2 — Turnstile WebView spike (rec 3)

Context7 confirmed SwiftUI web-view *modifiers* (`webViewOnScrollGeometryChange` etc.); it did **not**
confirm the `WebView`/`WebPage` types' surface. **Spike first, migrate only on pass.**

1. Time-box 0.5 day: prototype `WebView(WebPage)` loading the Turnstile widget HTML.
2. Pass criteria (all): (a) can force **mobile UA** — iPad captcha broke on desktop UA (PR #199, memory
   `ipad-turnstile-desktop-ua`); (b) JS→native token message bridge (replaces `WKScriptMessageHandler`
   in `TurnstileWidgetView.swift`); (c) same cookie/storage behavior; (d) works in UI-test env.
3. Pass → replace `UIViewRepresentable` in `Core/Services/Turnstile/TurnstileWidgetView.swift`; keep
   `TurnstileTokenProvider` protocol unchanged; manual test login + signup on iPhone AND iPad sim +
   physical iPad.
4. Fail → leave as-is, document why here. Zero-cost outcome.
**Risk:** auth-critical path. Do not merge without physical-iPad verification.

## Phase 3 — Small cleanups + subtitles (rec 6, 8)

Single small PR.
1. `MiniBarChart.swift:15` → `.clipShape(.rect(cornerRadius: 3))`.
2. `Shared/Components/Layout/AdaptiveDetailLayout.swift`: remove `AnyView` — make generic over
   `Compact: View` or take `@ViewBuilder` (2 sites, `compactContent`).
3. `RecruitingTimelineView.swift:132` `DispatchQueue.main.asyncAfter` → `Task { try? await
   Task.sleep(for: .milliseconds(350)); … }` inside `@MainActor` context; check cancellation on dismiss.
4. `.navigationSubtitle` (confirmed in docs) on school detail (division/state), coach detail
   (school), player profile. Check no dup with existing subtitle-style header text; a11y: subtitle read
   after title.
5. `NetworkMonitor.swift` `DispatchQueue` is required by `NWPathMonitor` — leave.
**Tests:** none needed for pure refactors beyond existing; add a view-model test only if subtitle text is
computed logic.

## Phase 4 — Swift 6 language mode (rec 5)

Highest churn. Incremental, one target-level flag flip at the end.

1. **Warnings pass:** set `SWIFT_STRICT_CONCURRENCY = complete` (still Swift 5 mode); build; triage
   count by file. Record baseline count here.
2. Fix in order of dependency depth: Core (Keychain, SupabaseManager, AuthManager, NetworkMonitor) →
   Services → ViewModels → Views.
3. Specific items:
   - `KeychainHelper`, `SupabaseManager` `@unchecked Sendable`: keep if the wrapped SDK isn't Sendable-
     annotated; otherwise make real `Sendable` / actor. Comments already document why.
   - `DocumentDownloadDelegate` (`@unchecked Sendable`): confirm state is lock-free/immutable or move
     to actor-isolated continuation.
   - `MockPublicProfileManaging` `@unchecked Sendable`: make immutable or actor.
   - 5 `Task.detached` (`AuthManager:337`, `BasicsTab:70`, `ProfileView:61`, `NuxProgressManager:88`,
     `ImageCompression` doc): replace with `@concurrent` nonisolated funcs (Swift 6.2) where they exist
     only to hop off main; keep detached only if priority/isolation semantics required.
   - 2× `import Combine` in `AddSchoolViewModel+Autocomplete`/`+DuplicateDetection` (in staged PR
     work — issue #140 fuzzy autocomplete; rebase after that lands): replace debounce with
     `AsyncStream`/`Task` + `Task.sleep` debounce, or keep if Combine is genuinely simplest (then just
     make it Sendable-clean).
4. Preserve `nonisolated deinit {}` on every `@MainActor` class (macOS 26 double-free workaround). Do NOT
   add `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor` (memory: broke Decodable models).
5. Flip `SWIFT_VERSION = 6.0` (or 6.2) per config **last**; consider enabling for the test target after
   the app target is clean.
6. Consider `SWIFT_UPCOMING_FEATURE_*` (e.g. `NonisolatedNonsendingByDefault`) only after clean Swift 6.
**Verify:** full unit target on CI (not just affected classes) — concurrency changes have wide blast
radius. UI-test smoke on iPhone + iPad.
**Risk:** Supabase SDK + PostHog Sendable gaps force `@preconcurrency import`; acceptable, list each.

## Phase 5 — Rich-text TextEditor (rec 4, optional)

Product-optional; do only after Q3 answered. Docs confirm `TextEditor` + `AttributedString` rich text.
1. Pick 1–2 fields with real value (Interaction notes, coach notes). Not all 12 `TextEditor`s.
2. **Backend blocker:** notes are stored/synced with web as plain text. Rich text needs a serialization
   decision (Markdown vs attributed JSON) and **web parity** (Nuxt renders it). Cross-platform rule:
   do NOT ship iOS-only formatting that renders as raw markup on web. Needs a web PR + migration plan.
3. Constrain formatting (bold/italic/list only) via the formatting-definition API; a11y: toolbar labels.
4. If web parity isn't wanted → drop this phase.

## Phase 6 — Charts upgrades (rec 7b)

4 chart files (`InteractionTrendsChart`, `PerformanceChartView`, `PerformanceDashboardView`,
`MiniBarChart`).
1. Audit against current Swift Charts: selection (`chartXSelection`), scrolling
   (`chartScrollableAxes`), annotations, `AXChartDescriptor` / `.accessibilityChartDescriptor` for
   VoiceOver audio graphs (a11y win, WCAG AA requirement in CLAUDE.md).
2. Add tap-to-inspect on performance-metric trend chart; keep MiniBarChart lightweight.
3. Cross-platform: check web charts show same data/interaction — parity only for data, not gestures.

## Phase 7 — WidgetKit + App Intents (rec 7a)

**Blocked on:** Q2 (scope), and re-audit for iOS 27 APIs.
1. New extension target(s) — **pbxproj edit required** (file-system-synchronized groups cover source
   files in the app target, NOT new targets). Do by Xcode UI/tooling, never `add_files_to_xcode.rb`.
   Requires App Group entitlement + shared Keychain group so the widget can read the Supabase session.
2. **Widget v1: "Next deadline"** — reuses Deadlines feature (family-scoped, unified w/ NCAA
   milestones; iOS PR #98, sport calendar). Timeline provider fetches via web API `API_BASE_URL` with
   Bearer token from shared Keychain; cache last payload in App Group container for offline.
   Small/medium/lock-screen families; privacy: redact when device locked (`.privacySensitive`).
3. **App Intents v1:** "Log interaction" (school + type + note) and "Open school". Shortcuts/Siri
   entities: `SchoolEntity` with `EntityQuery` backed by the local school cache. Auth: intent must fail
   gracefully when signed out.
4. Security review (skill `security-review`): token sharing across process boundary, no PII in widget
   snapshots on lock screen, App Group scope.
5. Web parity: N/A (platform feature) — note in `platform-parity` ledger as iOS-only by design.
6. TestFlight beta before release; App Store metadata + privacy manifest updates.
**Risk:** biggest phase (new targets, entitlements, provisioning). Treat as its own mini-project;
split widget and intents into separate PRs.

## Cut / not doing
- **SwiftData:** app is Supabase-backed; no local persistence need.

## Phase 8 — iOS 27 SDK re-audit
Once Apple's iOS 27 SwiftUI/WidgetKit docs are indexed (context7 had none on 2026-09-25) or via Xcode 27
release notes: re-run the API audit, fold new APIs into Phases 1/6/7. Output: addendum to this doc.

## Decisions (2026-09-25)
1. **iOS floor:** open — see recommendation below (Chris leaning "allow all, scale back with data").
2. **Widgets + App Intents:** both, post-launch. Tracked in **#24** (re-scoped via comment). App Intents =
   plumbing for Siri/Shortcuts/Spotlight/widget actions; same phase, separate PRs.
3. **Rich text:** go, in parallel with web, same release. Handoff:
   `planning/2026-09-25-web-handoff-rich-text-notes.md`. Nice-to-have, not table stakes.
4. **Swift 6:** after App Store submission. Tracked in **#201**.
5. **iOS 27 re-audit:** yes → Phase 8.

## Floor recommendation (pending Chris)
No users yet, so a lower floor costs nothing in churn — the cost is dev effort (`#available` forks).
Recommend **keep iOS 18 at launch** (already set; roughly N-1/N-2), gate 26-only features (Phases 1/2/5)
with `#available` + fallback, and raise the floor later once real OS-adoption data exists. Liquid Glass
system chrome applies on iOS 26 devices automatically with no floor change. Don't go *below* 18 — it
gives up current APIs for little reach. Phase 0 then reduces to fixing the stale README ("iOS 17+").

## Suggested order & rough size
P0 (S) → P3 (S) → P1 (M) → P2 spike (S) → P6 (M) → P5 (M, with web) → P4 (L, post-launch) →
P7 (L, post-launch) → P8.

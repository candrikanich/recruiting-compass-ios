# Plan: Full E2E Suite Green + Robust High-Coverage Testing

**Created:** 2026-05-27
**Goal:** Every test green (unit + integration + 336 E2E methods), code coverage measured with an 80% gate, E2E running against a local Supabase stack both locally and in CI.
**Status of foundation:** Phase 0 complete (this session). Phases 1–6 are for future sessions, each scoped to be picked up independently.

---

## Decisions (confirmed with Chris, 2026-05-27)

- **CI scope:** Local **and** CI. CI runner boots Docker + `supabase start`, seeds, runs E2E on PRs.
- **Coverage:** Add an `.xctestplan` with code coverage enabled; drive unit+integration to an **80% gate**.
- **Canonical fixture:** **1 parent + 1 linked player** (+ `player_profiles` + populated recruiting data), parent auto-views the athlete. Supports parent-view E2E **and** player-login / FamilyManagementPlayerFlows tests.

---

## Critical context (why the suite isn't green)

1. **App is athlete-centric.** A parent's dashboard renders the *selected athlete's* data via
   `familyManager.selectedAthlete` / `selectedAthleteId`. A parent with a family but **no linked player**
   sees `ParentOnboardingBanner` ("Connect your athlete" / "Add your first school"), seeded data under the
   *parent's* `user_id` is invisible, and tab navigation is gated. **The fixture must seed a linked player
   and make the parent view that athlete.**
2. **Screen-object selector drift.** Login had 2 bugs (combined-field labels; submit was `"Sign in to account"`
   not `"Sign in"`). Offers nav assumed a top-level tab; Offers actually lives under the **More** tab →
   "Recruiting" section. Expect the same drift across most of the 23 screen objects.
3. **Run against LOCAL Supabase only, never prod.** `cd ../recruiting-compass-web && supabase start`
   (Docker required). Demo JWT keys via `supabase status -o env` (public, not secrets).

### Scope (measured 2026-05-27)
- **336 E2E methods**, ~44 E2E files, **23 screen objects**, grouped by feature (see Phase 3).
- Pre-login files need **no** athlete fixture: Signup*, EmailVerification, PasswordReset, TermsOfService.
- Iteration cost: ~1 min per `xcodebuild test` with `-only-testing:`; full UITest target ~47 min.
  **Always use `-only-testing:` filters during feature work.**

---

## Phase 0 — Local E2E foundation ✅ DONE (2026-05-27)

Reference state; do not redo. Commits up to `c3e7799`.
- `scripts/seed-e2e.ts`: `cleanupTestData()` (child→parent delete) + plain inserts (no `onConflict`);
  `patchUsersRow` upserts `public.users` (local has no auth→users trigger); coach `role` enum `head`/`recruiting`.
  Seeds 11 tables clean + idempotent.
- `scripts/.env.test`: local demo creds (prod service-role key removed from disk; gitignored).
- `SupabaseConfig.swift`: under `--uitesting`, env vars override embedded prod creds.
- `Config/Info.plist` + `INFOPLIST_FILE` (both app configs): `NSAllowsLocalNetworking=true` (ATS for http://127.0.0.1).
- `E2ETestEnvironment.swift` (UITests/Helpers): `.configure(app)` = `--uitesting` + local creds.
- `XCUITestHelpers.loginAsParent`: `textFields.firstMatch`/`secureTextFields.firstMatch`, submit `"Sign in to account"`.
- **Verified:** parent login → Dashboard navbar (skip advanced past "Login failed").
- **Debug pattern that works:** diagnostic test → `XCTAttachment(string: app.debugDescription)` →
  `xcrun xcresulttool export attachments` (XCUITest `print()` does NOT survive to stdout; xcresult does).

---

## Phase 1 — Canonical fixture: parent + linked player + populated data ✅ DONE (2026-05-27)

**Gate met:** `OffersListE2ETests/testOffersList_navigate_displaysScreen` PASSES with real seeded data.

Resolved open questions:
1. **Athlete selection** = `family_members.id` (row UUID) held in `selectedAthleteId`; the athlete's
   query `user_id` is `selectedAthlete.userId`. Athlete users auto-select self; parents now auto-select
   the first athlete (added to `FamilyManager.loadFamilyData`, mirroring web's closest-grad default).
2. **Dashboard ownership:** schools/coaches/interactions → `family_unit_id`; offers/events/
   performance_metrics/documents → athlete `user_id` + `family_unit_id` (RLS visibility).

Done: seed-e2e seeds player+profile+membership and owns athlete data; fixed 3 iOS parity bugs
(`isAthlete` "player", Dashboard+Offers VM target `selectedAthlete.userId`, parent auto-select);
hardened `E2ETestEnvironment` to default LOCAL and ignore ambient prod `SUPABASE_URL` (Phase 0's
"verified" was a false positive against prod); fixed OffersListScreenObject nav (coordinate-tap the
non-hittable More tab) + summary-card staticText selectors + "No Offers Yet" empty title. Unit suite
re-green (2 fixture tests updated to role "player" / athlete userId).

### Original plan (for reference)


**Outcome:** After parent login, the Dashboard is populated (no onboarding banner) and tabs navigate.
Player-login also reaches a populated dashboard.

Steps:
1. Confirm the athlete-selection mechanism in `FamilyManager` — does it auto-select when exactly one
   athlete exists, or persist `selectedAthleteId` (UserDefaults / server)? This determines whether seeding
   one player is enough or we must also set selection (e.g. via `launchEnvironment` flag or a `--uitesting` default).
2. Extend `scripts/seed-e2e.ts`:
   - Create a **player** auth user (`player@example.com` / `TestPassword1`), `public.users(role=player)`.
   - `family_members(family_unit_id, user_id=player, role=player)` linking the player to the parent's family.
   - `player_profiles` row for the player (check NOT NULL cols, grade/grad year, etc.).
   - **Re-own recruiting data** (schools/coaches/offers/events/interactions/performance_metrics/documents)
     so it belongs to the athlete context the dashboard reads (likely `user_id = player` and/or
     `family_unit_id`). Verify against the app's actual dashboard queries (read the Services).
3. Verify with SQL + a one-shot E2E assertion: parent login → dashboard shows seeded schools/offers,
   `ParentOnboardingBanner` absent, More tab navigates.
4. Reconcile the two fixture paths: the TS `seed-e2e.ts` vs in-app `TestUserSetup.swift`. Pick one source
   of truth (recommend TS seed for data; keep `TestUserSetup` only if a test needs in-process creation).

**Gate:** `OffersListE2ETests/testOffersList_navigate_displaysScreen` PASSES (not skips).

---

## Phase 2 — Shared E2E harness hardening

**Outcome:** One consistent launch/login/navigation harness; no inline per-file config; fast local loop.

Steps:
1. Replace inline `launchEnvironment` in all ~44 E2E `setUp`s with `E2ETestEnvironment.configure(app)`.
2. Centralize navigation: a `MainTabNavigator` helper (tabs: Dashboard/Schools/Coaches/Interactions/More;
   More → Recruiting section rows). Fix the combined-row selector pattern once (`label BEGINSWITH …`).
3. Add `make e2e-local`: ensure `supabase start` is up → `npm run seed:e2e` → `xcodebuild test` UITests.
   Add `make e2e-seed` and a `supabase status` precheck with a helpful error if Docker/stack is down.
4. Document the harness in `docs/E2E_TESTING.md` (how to run, the local-stack requirement, the diagnostic pattern).

**Gate:** harness compiles; 2–3 representative tests pass via the shared helper.

---

## Phase 3 — Feature-by-feature green (the bulk)

Each sub-phase = its own session: dump tree → fix that feature's screen object selectors →
green the file group with `-only-testing:` → commit. Order roughly easiest→hardest.

- **3a Auth / pre-login** (no fixture): `Signup*`, `EmailVerification`, `PasswordReset`, `TermsOfService` — ~58 methods.
- **3b Schools**: `AddSchool*` (5 files), `SchoolDetail*` (4 files) — ~43 methods. (`AddSchoolScreenObject`, `SchoolDetailScreenObject`)
- **3c Coaches**: `AddCoachE2ETests` — 12 methods.
- **3d Interactions**: Add/Detail/EdgeCase/Accessibility — ~31 methods. (`AddInteractionScreenObject`, `InteractionDetailScreenObject`)
- **3e Offers**: List/Validation/Detail* — ~29 methods. (`OffersListScreenObject` partly done, `OfferDetailScreenObject`)
- **3f Events**: Create/Detail — ~23 methods.
- **3g Documents**: List/Detail/Viewer — ~13 methods.
- **3h Performance**: dashboard — 18 methods.
- **3i Activity**: feed/widget/error — ~22 methods.
- **3j Analytics**: dashboard — 16 methods.
- **3k Notifications + Preferences**: Notifications, HomeLocation, NotificationPreferences, PlayerDetails — ~39 methods.
- **3l Tasks**: TasksList — 4 methods.
- **3m CommunicationTemplates** — 8 methods.
- **3n Family**: ParentFlows (13) + PlayerFlows (10) — needs both personas from Phase 1.

**Per-sub-phase gate:** the feature's E2E files pass with zero skips; commit per feature.

---

## Phase 4 — CI integration

**Outcome:** E2E runs green on every PR against a CI-local Supabase stack.

Steps:
1. GitHub Actions macOS job: install Docker + Supabase CLI, `supabase start` in the web repo (or a pinned
   schema snapshot), `npm run seed:e2e`, boot simulator, `xcodebuild test` UITests.
2. Pin Xcode/runtime per existing CI notes (macos-15 issues in MEMORY.md — verify against current toolchain).
3. Quarantine flaky tests behind a tag; upload screenshots/videos/traces as artifacts on failure.
4. Keep unit/integration as a fast separate job; E2E as a slower gated job.

**Gate:** green E2E run in CI on a PR.

---

## Phase 5 — Coverage + 80% gate

**Outcome:** Coverage measured per target; unit+integration ≥ 80%; threshold enforced.

Steps:
1. Add `TheRecruitingCompass.xctestplan` with **code coverage enabled** (targets: app, scoped out test targets).
2. Generate a coverage report (`xcrun xccov`), produce a per-target/per-feature summary.
3. Identify gaps; add unit/integration tests (ViewModels, Services, utilities) to reach 80%.
4. Wire a coverage-threshold check into CI (fail under 80%).

**Gate:** coverage report ≥ 80%; CI enforces it.

---

## Phase 6 — Flake hardening + maintenance

- Replace fixed `sleep()`s with predicate waits; standardize timeouts.
- Establish a quarantine + retry policy; track flake rate.
- Finalize `docs/E2E_TESTING.md` (run book, fixture spec, troubleshooting, CI notes).

---

## Cross-cutting risks / notes

- **Never run E2E/seed against prod.** Only the local stack. The web `.env` is the PRODUCTION project.
- **Don't touch `.xcodeproj` for file refs** (synchronized groups auto-include); build-setting edits are OK.
- **SourceKit false positives** ("No such module XCTest", "Cannot find SupabaseConfigEmbedded") — only
  `xcodebuild` is authoritative.
- **Iteration cost** is real — always `-only-testing:` during feature work; reserve full runs for gates.
- **`prod test@example.com` password** was reset to `TestPassword1` in a prior session; local uses the same.
- Optional: the repo's `e2e-runner` agent is Playwright/web-oriented; iOS uses XCUITest — not a direct fit.

## Open questions (resolve in Phase 1)
- Exact athlete-selection trigger (auto-select-single vs persisted `selectedAthleteId`).
- Which columns the dashboard's Services actually filter on (`user_id` of athlete vs `family_unit_id`) —
  drives how seed data must be owned.

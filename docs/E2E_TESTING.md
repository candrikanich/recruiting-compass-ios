# E2E Testing (XCUITest)

End-to-end UI tests drive the real app against a **local Supabase stack**. They
never touch production.

## TL;DR

```bash
# 1. Start the local Supabase stack (Docker required; first run pulls images)
cd ../recruiting-compass-web && supabase start

# 2. Seed + run the full UI suite against local (from the iOS repo root)
make e2e-local

# Or seed only / run only:
make e2e-seed     # seed the local stack with the canonical fixture
make test-ui      # run UI tests (assumes already seeded)
```

Run a single test during feature work (iteration is ~1 min/test, full target ~47 min):

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassUITests/OffersListE2ETests/testOffersList_navigate_displaysScreen
```

## Why local only (and how it's enforced)

The web repo's `.env` points at the **production** Supabase project, and a
developer's Xcode run scheme sets `SUPABASE_URL`/`SUPABASE_ANON_KEY` to prod for
normal app runs. Two guards keep E2E off prod:

- **`E2ETestEnvironment`** (UITests/Helpers): injects creds into the app under
  test. It defaults to the local stack (`http://127.0.0.1:54321` + demo anon key)
  and **ignores** the ambient `SUPABASE_URL`/`SUPABASE_ANON_KEY`. To target a
  different stack (e.g. CI), set the dedicated `E2E_SUPABASE_URL` /
  `E2E_SUPABASE_ANON_KEY`.
- **`scripts/seed-e2e.ts`** deletes data before seeding, so it refuses any
  non-local target unless `ALLOW_REMOTE_SEED=1` is set.

The demo JWT keys are public and identical on every local install — not secrets.

> History note: an early "login→dashboard verified" was a false positive — the
> harness had been honoring the ambient prod `SUPABASE_URL` and hitting prod
> (where `test@example.com`/`TestPassword1` also exists). If results look wrong,
> confirm the app's live backend before trusting them.

## The canonical fixture

`scripts/seed-e2e.ts` seeds one family:

- **Parent** `test@example.com` / `TestPassword1`
- **Player (athlete)** `player@example.com` / `TestPassword1`, linked via
  `family_members(role='player')` + a `player_profiles` row.

The app is **athlete-centric**: a parent's dashboard renders the *selected
athlete's* data. The parent auto-selects the linked player on load.

Data ownership (must match the seed or RLS hides rows from the parent):

| Data | Owner column | Value |
|---|---|---|
| schools, coaches, interactions | `family_unit_id` | the family |
| offers, events, performance_metrics, documents | `user_id` **and** `family_unit_id` | the **athlete's** user_id (+ family for RLS) |

`family_members.role` is `'player'` (CHECK: `player`|`parent`), never `"athlete"`.

## Harness conventions

- **Launch:** every test's `setUp` calls `E2ETestEnvironment.configure(app)` then
  `app.launch()`. Do not inline `launchEnvironment` (it forwards the ambient prod
  URL). Exception: a test that deliberately injects invalid creds to exercise an
  error state.
- **Navigation:** use `MainTabNavigator` (UITests/Helpers) — `goTo(.schools)`,
  `goToMore()`, `goToMoreSection("Offers")`. Tab-bar buttons report
  `isHittable == false` under tall scroll content, so it taps via a normalized
  coordinate and retries. Overflow features (Offers, Events, Documents,
  Performance, Analytics, Activity) live under the **More** tab as
  `NavigationLink` rows labeled by their title.
- **Login:** `app.loginAsParent(email:password:)`; the submit button label is
  "Sign in to account". Combined-accessibility form fields aren't addressable by
  label — use `textFields.firstMatch` / `secureTextFields.firstMatch`.

## Debugging a selector / navigation issue

`print()` from a UI test does **not** reach stdout. Attach the tree to the
xcresult and export it:

```swift
let a = XCTAttachment(string: app.debugDescription)
a.name = "tree"; a.lifetime = .keepAlways
add(a)
```

```bash
R=$(ls -dt ~/Library/Developer/Xcode/DerivedData/TheRecruitingCompass-*/Logs/Test/*.xcresult | head -1)
xcrun xcresulttool export attachments --path "$R" --output-path /tmp/dump
```

A skip reason ("…not reachable") vs a failure tells you whether navigation or an
assertion is the problem; read it from the xcresult:

```bash
xcrun xcresulttool get test-results tests --path "$R" | grep -i 'Test skipped\|Failure'
```

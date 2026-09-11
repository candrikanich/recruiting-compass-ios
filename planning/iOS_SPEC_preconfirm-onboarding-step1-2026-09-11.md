# iOS Spec — Pre-Confirm Onboarding Step 1

> **Prepared:** 2026-09-11
> **Web branch:** `feat/preconfirm-onboarding-step1` (PR #761 → develop, merged)
> **Purpose:** Capture onboarding step 1 (grad year, sport, gender, zip) on the player signup form itself, carry it across the email-confirmation gap, and flush it into real preferences on first authenticated session — so a confirming player doesn't re-answer questions they already answered.

---

## Feature Overview

Today, a player who signs up sits on a blank "check your email" screen, then re-answers grad year / sport / gender / zip from scratch once they land in onboarding after confirming. This feature asks those four questions on the signup form itself (player role only), stashes the answers as signup metadata (nothing is written to the DB yet — there's no session to write with), and personalizes the waiting screen with what was drafted ("We'll get you set up for Baseball, Class of 2028..."). The first time the user is truly signed in — either the confirmation-link redirect or an explicit login — the draft is silently written into real player preferences and onboarding step 1 is marked complete, so onboarding resumes at step 2 instead of re-asking.

This is **not** a bug fix and does not touch anything already working (`SignupViewModel`'s no-session handling, `EmailVerificationViewModel`). It is new capture-earlier behavior layered on top.

---

## Web Implementation Summary

### Files Changed
- `components/Auth/SignupForm.vue` — 4 new fields, `v-if="userType === 'player'"`: graduation year (select, required), primary sport (select, required), gender (select, optional — hidden when sport auto-derives it), zip code (text, optional, 5-digit maxlength).
- `composables/useAuth.ts` — `signup()` gained an optional 6th param `onboardingStep1` that, when present, adds `pending_graduation_year` / `pending_primary_sport` / `pending_gender` / `pending_zip_code` to the Supabase `signUp()` metadata object (same mechanism as the existing `pending_admin` flag).
- `pages/signup.vue` — builds `onboardingStep1` only when role is `player` AND both grad year and sport are filled (gender/zip optional); passes drafted sport + grad year as query params to `/verify-email` when no session comes back from signup.
- `pages/verify-email.vue` — reads `sport`/`gradYear` query params, shows a personalized line ("We'll get you set up for {sport}, Class of {gradYear} as soon as you confirm."). No DB write — ephemeral, from the redirect URL only.
- `composables/useAccountProvisioning.ts` — `ensureAccountProvisioned()`, already called on every Supabase `SIGNED_IN` event, gained `applyPendingOnboardingStep1()`: reads the `pending_*` metadata off `user.user_metadata`, no-ops if `primary_sport` is already set on the player's preferences (idempotency guard — loads preferences first), otherwise writes `graduation_year` / `primary_sport` / `gender` via `setPlayerDetails()` and `zip` via `setHomeLocation()`, then calls `saveOnboardingStep(1, {...})` so in-app onboarding resumes at step 2. Wrapped in try/catch, non-blocking, never breaks sign-in.

### DB/Migration Changes
None. No schema changes — this rides entirely on Supabase auth metadata (`user_metadata`) plus the existing `user_preferences` writes.

---

## What iOS Needs to Build

### Screens

| Screen | Purpose | Entry Point |
|---|---|---|
| `SignupView` (existing, extended) | Add 4 fields, player role only, below date-of-birth | Existing signup flow |
| `EmailVerificationView` (existing, extended) | Personalize the waiting copy with drafted sport/grad year | Existing post-signup flow (no session) |

No new screens. This is additive to two existing views plus a new flush call site.

### Section / Component Breakdown

**SignupView — "About the player" section** (new, `role == .player` only, placed after the date-of-birth field)
- Graduation year — `Picker`/menu sourced from `OnboardingConstants.graduationYears` (**already exists** — reuse, do not reinvent). Required.
- Primary sport — `Picker`/menu sourced from `OnboardingConstants.commonSports` (**already exists** — reuse). Required.
- Gender — `Picker` over `Gender.allCases` (**already exists**, `Core/Models/Gender.swift`). Optional. **Hidden when `SportGenderMap.gender(for: primarySport)` is `.male` or `.female`** (auto-derived silently) — shown only when `.neutral`. `SportGenderMap` already exists (`Features/Onboarding/Utilities/SportGenderMap.swift`) — reuse it, do not re-port the web's `SPORT_GENDER_MAP` object.
- Zip code — text field, `keyboardType: .numberPad`, 5-digit max length, optional. Mirrors `HomeLocationViewModel`'s existing zip validation (5 numeric digits).

**EmailVerificationView — waiting copy**
- When the signup drafted a sport + grad year, append a line under the existing subtitle: "We'll get you set up for {sport}, Class of {gradYear} as soon as you confirm." No DB read/write — purely from values threaded in from the signup call.

---

## API Endpoints to Call

N/A — this feature does not add or call any Nitro API endpoint. It is entirely Supabase Auth `signUp()` metadata plus existing `PreferenceManaging` (`savePreferences`) calls, same infrastructure iOS already uses.

---

## Data Models (Swift)

No new models. Reuse existing:

```swift
// Features/Preferences/Models/PlayerDetails.swift (existing)
struct PlayerDetails: Codable, Equatable, Sendable {
  var graduationYear: Int?
  var primarySport: String?
  var gender: String?   // Gender.rawValue
  // ...existing fields unchanged
}

// Features/Preferences/Models/HomeLocation.swift (existing, confirm field name)
// location.zip: String?
```

Supabase signUp metadata — extend the existing dictionary builder in `SupabaseManager.signUp` (`Core/Services/SupabaseManager.swift:106-134`), which already conditionally adds `family_code` / `date_of_birth` keys the same way `pending_*` keys need to be added:

```swift
// SupabaseManager.signUp — add alongside the existing conditional metadata keys
if let graduationYear {
  metadata["pending_graduation_year"] = .string(String(graduationYear))
}
if let primarySport, !primarySport.isEmpty {
  metadata["pending_primary_sport"] = .string(primarySport)
}
if let gender, !gender.isEmpty {
  metadata["pending_gender"] = .string(gender)
}
if let zipCode, !zipCode.isEmpty {
  metadata["pending_zip_code"] = .string(zipCode)
}
```

`AnyJSON` is the same wrapper type already used for `full_name`/`role`/`family_code`/`date_of_birth` — no new decode/encode plumbing needed.

---

## Business Rules to Enforce Client-Side

- Grad year + primary sport are **required** for player signup, exactly like date-of-birth already is. Mirror web: `isFormValid` gates on both being non-empty when `selectedRole == .player`.
- Only draft-and-carry the metadata when **both** grad year and sport are filled — gender/zip alone are not enough (mirrors web's `pages/signup.vue` guard: `onboardingStep1` is `undefined` unless grad year + sport are both present).
- Gender field is hidden (not just disabled) when `SportGenderMap.gender(for:)` returns `.male` or `.female` — auto-derive silently, never ask.
- Zip code: 5 digits, numeric only, optional. Reuse `HomeLocationViewModel`'s existing zip validation rule rather than writing a new one.
- The flush-on-first-session step must be **idempotent**: skip entirely if the player's preferences already have `primarySport` set (don't clobber onboarding-v2 answers if the user somehow completed onboarding before the flush ran — e.g. multi-device race). Mirror web's check-before-write.
- The flush must **never throw out of the auth flow** — wrap in do/catch, log and continue on failure, exactly like the family-creation call already does in `SignupViewModel.signup()`.

---

## Excluded Items (No iOS Work Needed)

- **DB migrations** — none exist for this feature; no schema change at all.
- **RLS policies** — unaffected, existing `user_preferences` policies already cover these writes.
- **CSRF tokens** — N/A, iOS talks to Supabase directly for this.
- **Nitro API endpoint** — N/A, feature has none.
- **Email sending** — unaffected, Supabase's existing confirmation email flow is untouched.

---

## Dependencies

- `OnboardingConstants.commonSports` / `OnboardingConstants.graduationYears` — already exist, reuse (do not duplicate sport/grad-year lists a third time).
- `SportGenderMap` — already exists (`Features/Onboarding/Utilities/SportGenderMap.swift`), reuse for the gender-auto-derive rule.
- `Gender` enum — already exists (`Core/Models/Gender.swift`).
- `PreferenceManaging` / `PreferenceServiceImpl` (`savePreferences(category:data:)`) — already used by `OnboardingV2ViewModel.saveStep1()` for the exact same write shape (player details + home location). The flush logic should follow that fetch-then-merge pattern, not overwrite the whole preferences blob.
- `HomeLocationViewModel`'s zip validation — reuse the rule, don't re-derive it.

None of these need to be built new — they were built for onboarding-v2 and this feature is explicitly about reusing them one step earlier in the funnel.

---

## Notes for iOS Claude

- **iOS's account-provisioning flow does not match web's today — this is the main structural gap to resolve, and it's bigger than this one feature.** Web has a single `ensureAccountProvisioned()` called on every Supabase `SIGNED_IN` event (explicit login *and* the confirmation-link redirect), which is exactly where `applyPendingOnboardingStep1()` was hooked in. **iOS has no equivalent listener.** Today, iOS's family creation happens as a one-off inline call inside `SignupViewModel.signup()`, gated on `authManager.isAuthenticated` being true *immediately after signup* — and if there's no session yet (confirmation required, the normal case for a fresh signup), family creation is silently skipped entirely, with recovery left to "the dashboard onboarding banner detects the missing family." There is no code path on iOS that fires when the user later becomes authenticated via `EmailVerificationViewModel`'s polling-based confirmation detection, or via a subsequent login.
- **This means the flush-on-first-session for `pending_*` metadata has no natural home to hook into on iOS yet.** Two options, in order of preference:
  1. **(Recommended)** Introduce the missing "provisioning on every authenticated session" hook now, scoped narrowly: when `EmailVerificationViewModel.checkVerificationStatus()` observes `isVerified` flip true (i.e., `authManager.refreshSession()` returns a confirmed user), and separately at the point an explicit `login()` succeeds in `AuthManager`/`LoginViewModel`, call a new `flushPendingOnboardingStep1(user:)` step. This is the closer parity match to web's `SIGNED_IN`-driven design and also gives iOS's family-creation gap a natural place to be fixed later without another spec.
  2. **(Narrower, if scope must stay minimal)** Hook the flush only into `EmailVerificationViewModel`'s verified transition, leaving the family-creation gap and the login-path flush out of scope. This under-covers the case where a player closes the app during the confirmation wait and confirms via the email link days later, then logs in fresh (Supabase's own family-creation recovery banner would presumably also need to cover the onboarding-step-1 case in that scenario, same as it already does for family creation).
  Flag this decision back to Chris before building — it's a real architecture gap, not just a wiring detail, and picking option 2 silently would leave a known hole.
- `SignupViewModel.signup()` builds its `authManager.signup(...)` call with named parameters (not positional array-splicing like web's `Parameters<typeof signup>` workaround) — just add the four new optional params (`graduationYear: Int?`, `primarySport: String?`, `gender: String?`, `zipCode: String?`) straight through `AuthManager.signup` → `SupabaseManager.signUp`. No arg-count gymnastics needed; Swift default params handle it cleanly.
- The metadata keys must be **exactly** `pending_graduation_year` (as a string, matching web's `String(onboardingStep1.graduationYear)`), `pending_primary_sport`, `pending_gender`, `pending_zip_code` — the flush code (wherever it lands, per the decision above) reads these by exact key name from `user.user_metadata` / the Supabase Swift SDK's equivalent user-metadata accessor. A mismatched key name fails silently (flush no-ops), so verify the read side and write side agree before considering this done.
- Web's idempotency check is "does `getPlayerDetails()?.primary_sport` already have a value" — on iOS, that's `PlayerDetails.primarySport` fetched via `fetchPreferences(category: .player)`, mirroring exactly what `OnboardingV2ViewModel.saveStep1()` already does when pre-filling from existing preferences (it fetches existing details first, then merges). Reuse that fetch-then-merge shape for the flush write, don't overwrite the whole preferences row.
- Web's `saveOnboardingStep(1, {...})` marks onboarding progress so the in-app flow resumes at step 2. **iOS's `OnboardingV2ViewModel.saveStep1()` does not appear to write any onboarding-progress marker at all** (only the two preference writes) — confirm whether iOS onboarding tracks step completion some other way (e.g. derived from whether `primarySport`/`graduationYear` are present, rather than an explicit progress table) before deciding whether the flush needs an equivalent call. If iOS onboarding is purely presence-derived, the two preference writes alone may be sufficient and no progress-marker call is needed — this differs from web and is fine, just confirm it's intentional rather than an oversight.
- Do not build a second sport→gender map or a second sports/grad-year list. All three already exist from the onboarding-v2 build and are the load-bearing source of truth — importing them into `SignupViewModel` is a smaller change than it looks.

---

## Test Checklist

1. Player signup, fills grad year + sport (+ optionally gender/zip when sport is a neutral sport like Soccer) → no session comes back (confirmation required) → `EmailVerificationView` shows the personalized "We'll get you set up for {sport}, Class of {gradYear}..." line.
2. Player signup, picks a sport with an unambiguous gender (e.g. Baseball) → gender field never appears on the form at all.
3. Player signup, picks a neutral sport (e.g. Basketball) → gender field appears, remains optional.
4. Player signup with grad year filled but sport left blank → form does not submit (required-field validation blocks it, same as date-of-birth today).
5. Confirm via email link (or via the resolved decision's flush trigger) → player's preferences now show the drafted grad year/sport/gender/zip without the user re-entering anything, and onboarding does not re-ask step 1.
6. Run the same flow a second time for a user who already has `primarySport` set on their preferences (e.g. completed onboarding manually before confirming) → flush is a no-op, existing preferences are not overwritten.
7. Simulate a flush failure (e.g. preferences write throws) → sign-in/confirmation still succeeds; user is not blocked or shown an error from this step.
8. Parent signup → none of the four new fields appear at all (player-only gating).
9. Zip code field: enter fewer than 5 digits or non-numeric characters → same validation behavior as `HomeLocationViewModel`'s existing zip rule (reject or block, whichever that rule already does).

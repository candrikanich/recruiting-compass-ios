# Profile Completeness — Canonical Spec (v1)

**Date:** 2026-08-09
**Bug:** iOS showed 92% complete (parent view), web showed 55% (player view) for the
same athlete. Expected identical.

## Root cause

Two independent, divergent implementations:

1. **iOS** (`PlayerDetails.completenessScore`) — equal-weight 11-field formula
   (school name/city/state, height, weight, social handles, bats/throws…). Fills
   easily from onboarding → inflated to 92%.

2. **Web** (`utils/profileCompletenessCalculation.ts`) — weighted 9-field formula,
   but **3 of its 9 fields (35% of total weight) read from sources nothing
   populates**:
   - `zip_code` (10%) — onboarding saves zip to the **home-location** store
     (`setHomeLocation`), never to the player-prefs blob the calc reads → always 0.
   - `highlight_video_url` (15%) — written **nowhere** in the app; real video data
     lives in the `video_links` table → always 0.
   - `athletic_stats` (10%) — written **nowhere** → always 0.

   Web is therefore capped at ~65%. Example athlete scored exactly 55
   (gradYear 10 + sport 10 + position 10 + gpa 15 + testScores 10), phone missing.

Both are wrong: iOS over-counts easy fields; web has 35% unearnable dead weight.

## Canonical formula (both platforms)

Weighted fields summing to 100%. Weights preserve web's original intent; the 3
broken sources are re-wired to real data. `athletic_stats` (10%) is split into
height 5% + weight 5% (real fields both platforms already store).

| Field | Weight | Source | Present when |
|---|---|---|---|
| Graduation year | 10% | player prefs `graduation_year` | non-null |
| Primary sport | 10% | player prefs `primary_sport` | non-empty (trimmed) |
| Primary position | 10% | player prefs `primary_position` | non-empty (trimmed) |
| Home location | 10% | location store (`HomeLocation`) | `zip` non-empty **OR** both `latitude`+`longitude` set |
| GPA | 15% | player prefs `gpa` | non-null |
| Test scores | 10% | player prefs `sat_score` **or** `act_score` | either non-null |
| Highlight video | 15% | `video_links` table | ≥1 row for the athlete |
| Height | 5% | player prefs `height_inches` | non-null |
| Weight | 5% | player prefs `weight_lbs` | non-null |
| Contact | 10% | player prefs `phone` | non-empty (trimmed) |

**Total: 100%.** Result is a fraction 0.0–1.0 (iOS) / integer 0–100 (web),
rounded to nearest integer for display.

### Purity / async note

Highlight-video and home-location presence live **outside** the player-prefs blob,
so the pure formula cannot read them from `PlayerDetails` alone. Both platforms:

1. Async-fetch two booleans — `hasHighlightVideo` (video_links count > 0) and
   `hasHomeLocation` (location store) — in the ViewModel/composable.
2. Pass them into a **pure** calc function alongside the player-prefs object.

Keeps the scoring function pure and unit-testable; side-effectful fetches stay in
the caller.

## Presence rules

- Strings: trimmed, non-empty.
- Numbers: non-null. (Do **not** treat 0 as missing for gpa/height/weight — 0 is
  invalid for these anyway, but null is the "unset" signal, matching iOS optionals.)
- Home location: `zip` non-empty OR (`latitude` && `longitude`).
- Highlight video: at least one `video_links` row owned by the athlete.

## Out of scope

- Reordering onboarding to collect zip into the player blob (location store is the
  canonical home for it — the fix reads from there instead).
- Changing weights beyond the athletic_stats split.

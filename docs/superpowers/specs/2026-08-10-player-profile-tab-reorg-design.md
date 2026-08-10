# Player Profile — Tab Reorganization (iOS + Web)

**Date:** 2026-08-10
**Status:** Approved (brainstorming) — pending spec review
**Scope:** Player Profile / Player Details settings. Both `recruiting-compass-ios` and `recruiting-compass-web`.

## Problem

Field placement across the Player Profile tabs is inconsistent and, on web, duplicated:

- **iOS is missing fields web has:** `core_courses`, and contact `phone` / `email` **inputs** (iOS only exposes the share-with-coaches privacy toggles, never the phone/email fields themselves).
- **Contact/privacy lives under Academics**, which is the wrong mental bucket — it is identity/reachability, not academic record.
- **Web edits the same `phone`/`email` in two tabs** (Basics "Recruiting Email/Phone" + Academics "Contact & Privacy") — both bind `form.phone` / `form.email`. Same field, two homes.
- School info (high school name/city/state) sits in Basics, but reads more naturally as academic context.

## Goal

Group fields by **purpose**, give each tab a clean identity, add the iOS-missing fields, and collapse the web contact duplication to a single home. **No data migration** — every field keeps its existing JSON key in the `user_preferences` player blob, so existing data and cross-platform reads are unaffected.

## Target Information Architecture (both platforms)

### Basics — "who they are + how to reach them"
- Profile photo *(iOS only)*
- Graduation year
- Primary sport
- **Contact** (block): `phone`, `email`, `allow_share_phone` toggle, `allow_share_email` toggle
- **Social handles** (block): `twitter_handle`, `instagram_handle`, `tiktok_handle`, `facebook_url`
- **College Preferences** (block): `campus_size_preference`, `cost_sensitivity` — *unchanged, stays here*

### Athletics — UNCHANGED
Physical (height/weight/bats/throws), Positions, Recruiting Database IDs (NCAA/Perfect Game/Prep — stay here), Video Links.

### Academics — "school + record"
- **High School** (block): `high_school` (name), `school_city`, `school_state` *(moved from Basics)*
- GPA (`gpa`), SAT (`sat_score`), ACT (`act_score`)
- **Core Courses** (block): `core_courses` — add/remove tag chips *(new on iOS)*

### History — UNCHANGED
Grade-level teams/coaches, travel team.

## Field moves summary

| Field(s) | From | To |
|---|---|---|
| `phone`, `email` inputs | Web Basics + Web Academics (dup) → **one home** | Basics (Contact block) |
| `allow_share_phone`, `allow_share_email` | iOS Academics "Privacy" / Web Academics "Contact & Privacy" | Basics (Contact block, under phone/email) |
| social handles (4) | iOS Academics / Web Academics | Basics (Social block) |
| `high_school`, `school_city`, `school_state` | Basics | Academics (High School block) |
| `core_courses` | — (missing on iOS) | Academics (new on iOS; already on web) |

## Platform-specific work

### iOS (`recruiting-compass-ios`)
1. **Model** `Features/Preferences/Models/PlayerDetails.swift`: add `var coreCourses: [String]?` + CodingKey `core_courses = "core_courses"`. (`phone`, `email`, `allow_share_phone`, `allow_share_email`, `high_school`, `school_city`, `school_state`, socials already present.)
2. **BasicsTab** `.../Views/Tabs/BasicsTab.swift`:
   - Remove High School / City / State rows.
   - Add **Contact** card: phone (`.phonePad`), email (`.emailAddress`, no autocap) text rows + the two share toggles.
   - Add **Social handles** card: 4 text rows (X/Twitter, Instagram, TikTok, Facebook) — reuse the row style moved out of AcademicsSocialTab.
   - Keep College Preferences card (added earlier this session).
3. **AcademicsSocialTab** `.../Views/Tabs/AcademicsSocialTab.swift` → effectively "AcademicsTab":
   - Remove Social Media + Privacy cards.
   - Add **High School** card: name/city/state rows (moved from Basics).
   - Add **Core Courses** card: tag-chip editor (see UI spec).
   - Section order: High School → Academics (GPA/SAT/ACT) → Core Courses.
4. **Core Courses chip UI** (new iOS component or inline in the tab): removable pills + text field + Add button. Constraints mirror web: max 20 courses, 60-char max per entry, trim, no duplicates, Return submits. Respect `viewModel.isReadOnly`. Writes via `viewModel.markChanged()`.

### Web (`recruiting-compass-web`)
1. **`pages/settings/player-details.vue:338`**: rename tab `name: "Academics & Social"` → `"Academics"`. Tab `id` stays `academics` (route/query stability).
2. **`components/Settings/PlayerDetailsBasicsTab.vue`**:
   - Remove High School Name / School City / School State inputs (move to Academics).
   - Keep the existing email/phone inputs; add the two privacy toggles beneath them so Basics is the single Contact home.
   - Add the Social Handles block (moved from Academics).
3. **`components/Settings/PlayerDetailsAcademicsTab.vue`**:
   - Remove Social Handles + Contact & Privacy blocks (the duplicate `form.phone`/`form.email` and the toggles).
   - Add High School name/city/state inputs.
   - Keep GPA/SAT/ACT + Core Courses. Order: High School → Academic Info → Core Courses.
4. Update any tab-specific props (the tabs receive `campusSizeOptions`, etc. via props; ensure moved blocks get the option/handler props they need in their new host).

## UI spec — Core Courses (both platforms, web is source of truth)
- Header: "Core Courses", subtitle "AP, honors, or notable courses for your recruiting profile."
- Chips: value text + remove (×) control (hidden/disabled when read-only).
- Input row (shown when not read-only and count < 20): text field placeholder "e.g., AP Chemistry", maxlength 60; "Add" button disabled when input is blank; Return/Enter adds.
- At 20 items: hide input, show "Maximum 20 courses added."
- Stored as `core_courses: string[]` in the player blob.

## Data / persistence
- No schema or migration change. All keys already exist in `user_preferences.data` (category `player`): `phone`, `email`, `allow_share_phone`, `allow_share_email`, `core_courses`, `high_school`, `school_city`, `school_state`, `twitter_handle`, `instagram_handle`, `tiktok_handle`, `facebook_url`, `campus_size_preference`, `cost_sensitivity`.
- Both platforms already Codable/serialize the whole blob; moving a field between tabs does not change what is written. iOS adds one new key (`core_courses`) it previously ignored on decode.

## Testing
- **iOS:** `PlayerDetails` round-trip test asserting `core_courses` encodes/decodes to `[String]`. Core-courses editor unit test: add / dedupe / trim / 20-cap / read-only. Keep/adjust any AcademicsSocialTab / BasicsTab tests to the new field homes. Build gate: `xcodebuild build` clean.
- **Web:** component tests for BasicsTab (contact block incl. toggles, social block present; HS inputs absent) and AcademicsTab (HS inputs present; social + contact absent). Assert phone/email have exactly one editing home. Run existing `usePlayerDetailsForm` tests unchanged.

## Non-goals / out of scope
- No change to Athletics, History, or Public Profile (web) tabs.
- No relocation of campus size / cost sensitivity (explicitly kept in Basics).
- No DB migration, no new persisted fields beyond iOS adopting the existing `core_courses` key.
- Recruiting DB IDs stay in Athletics.

## Open questions
None outstanding — the three placement decisions (contact+privacy → Basics; HS-only → Academics; campus/cost stay) are resolved.

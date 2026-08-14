# iOS Quick Communication — Web Template Parity Spec

**Date:** 2026-08-13
**Status:** Approved design; phased; ready for writing-plans (Phase 1 first)
**Owner:** iOS
**Related web feature:** `feat/coach-outreach-templates` (web commit `c9f21b70`, on `develop`)

---

## 1. Problem

Tapping a coach's email on iOS opens the Quick Communication sheet, but **no templates
appear**. The user asked to mirror the web's Quick Communication modal and surface all
web templates on iOS.

## 2. Root cause (verified against prod DB `xpxzhqghxecsjhvklsqg`)

The templates are NOT missing — **34 predefined templates exist in the shared DB**
(`communication_templates`, all `user_id = NULL`, all `is_predefined = true`). RLS policy
*"Users can view predefined templates"* (`SELECT USING (is_predefined = true)`) already
grants iOS read access.

iOS fails at **decode**, not fetch:

- iOS `TemplateType` enum = `email` / `text` / `twitter`.
- DB `type` values = `email` (25) / `message` (7) / `social` (2).
- `fetchTemplates()` decodes `[CommunicationTemplate]` as one array. The first `message`
  or `social` row throws a `DecodingError` → the whole array decode fails → `catch` in
  `QuickCommunicationViewModel.loadTemplates()` sets `templates = []` + an error message.
  Even the 25 valid `email` rows never load.

Secondary gaps:
- `fetchTemplates()` has no `.or("user_id.eq.<uid>,is_predefined.eq.true")` scoping (relies
  on RLS alone; works for read but diverges from web query and won't include user-owned rows
  correctly once those exist).
- iOS `CommunicationTemplate` model is missing `subject`, `slug`, `stage`, `contact_window`,
  `required_variables`, `sort_order`, `is_predefined`.
- iOS `TemplateVariable.all` is a small hardcoded subset, not the 77-variable registry.

## 3. Current iOS state (files)

| File | Role |
|---|---|
| `Features/Coaches/Views/QuickCommunicationView.swift` | Sheet UI (recipient, template picker, preview, send email/text) |
| `Features/Coaches/ViewModels/QuickCommunicationViewModel.swift` | Loads templates, fills body (4 snake_case vars), mailto/sms, logs send |
| `Features/Coaches/ViewModels/QuickCommunicationContext.swift` | Coach + school context passed to sheet |
| `Features/CommunicationTemplates/Models/CommunicationTemplate.swift` | Model + `{{key}}` substitution (`substituteVariables`) |
| `Features/CommunicationTemplates/Models/TemplateType.swift` | Enum `email`/`text`/`twitter` — **mismatch** |
| `Features/CommunicationTemplates/Models/TemplateVariable.swift` | Small hardcoded var list |
| `Features/CommunicationTemplates/Services/CommunicationTemplatesService.swift` | fetch/create/update/delete |

Sheet is presented from `CoachCardView` (email/text tap), `CoachDetailView`, `CoachesListView`.

Existing iOS substitution already supports `{{key}}` and 4 vars (`coach_name`, `school_name`,
`film_links`, `primary_film_link` — note: **snake_case**, web uses camelCase like
`{{coachFirstName}}`). The resolver port must adopt the web registry's camelCase keys.

## 4. Web system to port (source of truth)

Port the **modern `CommunicationPanel` stack** only. Ignore legacy `TemplateSendModal.vue` /
`utils/templateVariables.ts` (deprecated 7-var map).

Web key files:
- `components/CommunicationPanel.vue` — compose/send UI
- `composables/useTemplateResolver.ts` — context builder + orchestration
- `utils/templateResolver.ts` — **pure** resolver/render/computed logic (port 1:1)
- `utils/contactWindow.ts` + `composables/useContactWindow.ts` — pre/open window
- `composables/useCommunicationTemplates.ts` — template load/CRUD
- `composables/useAthleteMessages.ts` — send guardrails (API)
- `utils/editableProfileFields.ts` — inline-edit whitelist
- `supabase/migrations/20260816000000_coach_outreach_phase0_1.sql` — schema
- `docs/coach-outreach/template-library-seed.corrected.sql` — 77 vars + 33 templates

### 4.1 DB schema (already applied to shared prod DB)

`communication_templates` columns (21):
`id, user_id, name, description, type, subject, body, tags[], unlock_conditions jsonb,
is_predefined, is_favorite, use_count, created_at, updated_at, slug, stage, contact_window,
required_variables jsonb, send_timing_note, length_target, sort_order`

- `type ∈ {email, message, social}` (CHECK; base also allowed `phone_script`).
- `contact_window ∈ {pre, post, any}` (default `any`, NOT NULL).
- `stage ∈ {intro, update, event, post_event, thanks, nudge, reply, visit, status,
  decision, social}`.

`template_variables` (registry, global, no `user_id`, RLS `SELECT USING (true)`):
`key PK, label, description, category, source_type, source_path, is_required_default,
example, sort_order`
- `source_type ∈ {column, computed, authored, system}`
- `category ∈ {player, academics, metrics, contacts, program, event, authored, system}`

`contact_window_rules` (global reference): `sport, division, rule_kind, reference,
window_date, notes`.

### 4.2 Variable resolution (grouped by source)

Resolver walks the registry; per var switches on `source_type`:
- `column` → read `column:<table>.<col>` from gathered tables, or `pref:player.<key>` from
  `user_preferences` (category='player') jsonb.
- `authored` → per-message value typed by athlete (never persisted).
- `computed` / `system` → formatter in a `COMPUTED` map, else pre-computed `derived` value.
- **Any null/empty value is OMITTED** → `{{key}}` survives render → flagged as gap (this IS
  the send gate).

| Group | Source |
|---|---|
| Player identity | `users` cols + computed (`playerFirstName`, `height` in→`6'2"`, `weight`→`185 lbs`, `sport`/`position` via derived) |
| Academics | `users` cols (`gpa`), computed (`testLabel`/`testScore` prefers ACT else SAT), `pref:player.ncaa_id`, `documents` (transcript), authored (`classRank`,`intendedMajor`,`academicHonors`) |
| Metrics | `performance_metrics` (ranked primary→verified→recent, cap 4, `- label: value (source, Mon YYYY)`), `carryingTool`=primary, `videoLink`=pref, `profileLink`=derived from `player_profiles`, authored (`seasonStatLine`,`awards`,`teamAccomplishment`) |
| Contacts | `pref:player.*` (phone/email/travel_team_coach), derived grade-appropriate `hsCoachName`, authored (hs/club coach phone/email) |
| Program | `coaches` cols (first/last/title), `schools` cols (name/division/conference/city/state/twitter), computed `coachSalutation`=`Coach {last}`, `schoolShortName`, authored `programMascot` |
| Event | `events` cols + derived (`eventSchedule`, `nextEvent*`, upcoming soonest-first cap 5), authored (`teamAtEvent`,`roleNote`) |
| Athlete-authored (~20) | typed at compose: `programNote, fitReason, updateHook, updateHookShort, filmDescription, performanceSummary, specificMoment, questionBack, answerTheirQuestion, specificTakeaway, injuryNote, returnTimeline, decisionTimeframe, offerDetails, roleChange, referrerName` |
| System | `todayDate` (localized long, UTC), `seasonLabel` (from month), `contactWindowDate`, `daysSinceContact` |

`derived` (built in `buildAthleteContext`): `sport` (users.primary_sport_id→sports.name),
`position` (from `user_preferences.primary_position` STRING, not the FK table),
`positionSecondary`, `hsCoachName`, `profileLink`, `transcriptLink`, `eventSchedule`,
`nextEventName`, `nextEventDates`.

Render = regex-replace each `{{key}}` globally; unmatched left intact.
`findUnresolved(text)` returns remaining `{{\w+}}` keys.

### 4.3 Contact-window (pre vs open)

Inputs: `sport` (derived), `division` (school), `gradYear` (users). Eval:
1. Missing division or gradYear → `open` (fail-open).
2. Select most-specific rule: exact `(sport,division)` → `("*",division)` → none→open.
3. `rule_kind='unrestricted'` → open. Else compute open date from `reference` grade
   (freshman=9…senior=12) + parsed `window_date` ("Aug 1"):
   `endYear = gradYear-(12-grade)`; `date_before_grade`→`endYear-1`, `date_after_grade`→`endYear`.
4. `state = today < opensOn ? "pre" : "open"`.

Template swap (applied to type-filtered list before picker):
- `open`: hide all `contact_window="pre"` templates.
- `pre`: hide an `"any"` template when a `"pre"` sibling exists in same `(type, stage)` group.
- Athlete always sees exactly one intro; rule is silent.

### 4.4 Send gating

**The gate is unresolved `{{tokens}}`, NOT the `required_variables` metadata.**
- `unresolved = findUnresolved(subject + body)` deduped.
- Send disabled while `unresolved.count > 0`; on attempt show
  "Fill these variables before sending: {keys}".
- Authored/required vars (`programNote`, `updateHook`, `specificMoment` — the
  `is_required_default=true` ones) have no source → render literal until typed → naturally
  block send. `required_variables` jsonb is seeded but not read at gate time.

### 4.5 Guardrails (INCLUDED per decision — reuse web API)

After token check passes, `POST /api/athlete/messages/check`:
1. `programNoteReused` → **hard block** ("reason already sent to another program").
2. `recentContact` (<7d) or `messageCountToSchool >= 2` → **two-step confirm** (warn, arm,
   next tap proceeds).
Then `POST /api/athlete/messages` logs `athleteUserId, schoolId, coachId, templateSlug,
channel, programNote, updateHook, subject, body` (best-effort). **All guardrail lookups fail
open** — never block a legit send. Bearer auth (Supabase session) + `API_BASE_URL` (same
config as Dashboard Action Items widget).

### 4.6 Compose flows

- **Email**: template select (window-filtered) → editable subject + body → live preview
  (unresolved tokens bold/amber) → variables panel → "log interaction" (default on) → send
  builds `mailto:?subject=&body=`.
- **Text**: no subject, body **160-char max** + counter → send `sms:?body=`.
- **Instagram**: no composer — open `https://instagram.com/{handle}`.
- iOS uses existing `MFMailComposeViewController` / `MFMessageComposeViewController` for
  in-app compose (prefilled), falls back to `mailto:`/`sms:` hand-off (logs nothing on
  hand-off, per current behavior).

## 5. Target iOS architecture (MVVM, per project CLAUDE.md)

- **Models**
  - `TemplateType`: `email`/`message`/`social` + `.unknown` fallback (decode fail-soft so no
    single bad row nukes the array).
  - `CommunicationTemplate`: add `subject, slug, stage, contactWindow, requiredVariables,
    sortOrder, isPredefined` (all optional/defaulted for back-compat decode).
  - New: `TemplateVariableDef` (registry row), `ContactWindowRule`, `ResolvedContext`.
- **Resolver (pure struct, unit-tested)** `TemplateResolver`
  - `render(_ body:, values:) -> String`, `findUnresolved(_:) -> [String]`, source_path
    parsing, `COMPUTED` formatters (height, weight, metrics block cap-4, event schedule,
    grade-appropriate HS coach, testLabel/testScore, coachSalutation, schoolShortName,
    seasonLabel, todayDate). Port 1:1 from `utils/templateResolver.ts`.
- **Services (protocol + impl, `Sendable`, not @MainActor)**
  - `CommunicationTemplatesService.fetchTemplates()` — add `.or(...)`, fail-soft on missing
    table (`PGRST205` → `[]`).
  - New `TemplateVariablesService` (registry, cache once/session).
  - New `TemplateContextService` — gather `users`, `coaches`, `schools`, `events`,
    `performance_metrics`, `documents`, `user_preferences`, `player_profiles`, `sports`.
  - New `ContactWindowService` (rules, cache once, fail-open).
  - New `AthleteMessagesService` — `checkSend` + `logSend` via `API_BASE_URL` + Bearer.
- **ViewModel** `QuickCommunicationViewModel` (extend) — resolve context, authored inputs
  state, unresolved gating, contact-window filter, guardrail orchestration.
- **Views** `QuickCommunicationView` (extend) — subject field (email), editable body,
  preview with amber unresolved tokens, variables panel (inline-edit athlete-only / authored
  inputs / read-only + "Edit in profile" link), send-disabled gating, IG entry button.

**Fail-open everywhere.** Parents read-only for inline profile edits (`canEditProfile`
requires athlete editing own profile).

## 6. Phases (each = own PR)

### Phase 1 — Kill empty sheet + basic render *(smallest, highest value)*
- Fix `TemplateType` (add `message`/`social`, drop or map `text`/`twitter`, `.unknown`
  fallback). Sweep `.text`/`.twitter` refs (`QuickCommunicationViewModel.textTemplates`,
  `logSend` channel map, `CommunicationTemplatesView` manage UI, create/update payloads).
- Extend `CommunicationTemplate` model (new optional columns).
- `fetchTemplates()`: `.or("user_id.eq.<uid>,is_predefined.eq.true")` + fail-soft.
- Introduce `TemplateResolver` struct (render + findUnresolved); keep existing 4-var fill.
- **Exit:** all 34 templates listed (grouped email/text/social), subject+body render, send
  works as today. Unit tests: decode with `message`/`social`/unknown types; resolver
  render/findUnresolved.

### Phase 2 — Variable resolution + panel + token gating
- `template_variables` registry service + model; `TemplateContextService`; computed
  formatters. Adopt camelCase registry keys.
- Variables panel UI (inline-edit athlete-only, authored inputs, read-only + profile link).
- Send disabled while unresolved tokens remain; preview highlights amber tokens.
- **Exit:** templates fill from athlete profile; missing vars block send with guidance.
  Tests: per-source resolution, metrics cap-4 ranking, event schedule, gating.

### Phase 3 — Contact-window + guardrails
- `ContactWindowService` + pre/open eval + silent template swap.
- `AthleteMessagesService` (`/check` + log). Two-step confirm + hard block UX.
- **Exit:** window-appropriate templates; anti-spam guardrails enforced, fail-open.
  Tests: window eval (pre/open/fail-open), swap grouping, guardrail confirm/block/fail-open.
- **Pre-req to verify at P3 start:** `/api/athlete/messages` + `/check` deployed to prod
  (currently web `develop`); `API_BASE_URL` set in scheme/Release config.

## 7. Open questions / risks

1. **Web API deploy for P3** — endpoints are on web `develop`, not confirmed in prod. Verify
   before P3; if undeployed, P3 blocks on a web ship.
2. **`text` → `message` rename blast radius** — `TemplateType.text` is used in
   `textTemplates` filter and `logSend`'s `SendChannel.text → InteractionType.text`.
   `InteractionType` is a SEPARATE enum (unaffected); only the template-type filter/label
   renames. Confirm `CommunicationTemplatesView` create/edit UI offers the new types.
3. **`social`/IG scope** — web has no social composer yet (IG = open profile link). iOS
   matches: list social templates? Or IG button only? Default: IG open-profile button, no
   social composer (parity).
4. **Existing `TemplateVariable.all`** — replace with registry-backed defs, or keep as
   offline fallback when `template_variables` fetch fails (fail-open). Recommend: registry
   primary, small hardcoded fallback.
5. **Parents vs athlete** — inline edit gated to athlete-owned profile; parents see read-only
   + "Edit in profile" link. Confirm iOS has the equivalent `canEditProfile` signal
   (FamilyManager role/selectedAthlete).

## 8. Verification

- Build: `xcodebuild build` from `TheRecruitingCompass/` (iPhone 17 sim).
- Per phase: run the affected test classes (resolver, viewmodel, service) — trust
  xcodebuild exit code, not a grep.
- Manual: tap coach email → sheet lists templates → pick intro → preview fills → send.

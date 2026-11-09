# Email → Events Implementation Plan

> **For agentic workers:** this plan is executed **issue by issue on the TRC board** by `trc-web-dev`,
> `trc-ios-dev` and `trc-supabase`, then checked by `trc-verifier`. Each task below is one GitHub issue. Inside an issue,
> use TDD: write a failing test, implement, run the gate, open a PR.

**Goal:** a forwarded camp or program email becomes reviewed, pre-filled Events plus a logged inbound interaction, and
every family member is reminded to register.

**Architecture:**
- **Server (web repo):** keeps the email's links, runs a heuristic event parse, and stores `suggested_events` on the
  draft.
- **iOS:** any family device with Apple Intelligence claims the draft and improves the result with Apple's on-device
  model.
- **Review (both platforms):** shows the email next to the event forms. One RPC creates the interaction and the chosen
  events together.
- **Reminders:** the existing daily notification cron and the suggestion rules, extended to every family member.

**Tech Stack:** Nuxt 3 + TypeScript, Supabase Postgres (migrations and RPCs), Swift/SwiftUI with `FoundationModels`
(iOS 26+, guarded; the app's minimum stays iOS 18.0).

**Spec:** `planning/2026-11-09-email-to-events-design.md`. Every call in it is approved by Chris (2026-11-09).

## Global Constraints

- All schema and API changes are **additive**. The current `POST /api/inbound-drafts/{id}/confirm` request shape and
  the `confirm_inbound_draft` RPC keep working for iOS 1.0.x.
- The feature stays behind feature flag `inbound_drafts`.
- New web-API `URLRequest`s on iOS call `request.addClientHeaders()`.
- No email content is sent to any third-party AI. The only AI is `FoundationModels`, on the family's own device.
- The on-device prompt is capped at 8,000 characters of email text.
- Shared data is scoped by `family_unit_id`, never by the signed-in user.
- Registration reminders:
  - only for `type IN ('camp','showcase')`, and `registered IS NOT TRUE`;
  - one push 3 days after creation, only for events created on or after the release date (`REGISTRATION_REMINDER_SINCE`);
  - one push 10 days before `start_date`;
  - none when the event is less than 2 days away;
  - at most these two pushes per person per event;
  - sent to every family member.
- A draft's `ai_status` changes from `pending` to `skipped` after 24 hours if no device claimed it. A claim expires
  after 10 minutes.
- Confirming requires a `school_id`. It is picked from the family's schools, or added inline through the existing
  add-school search. The search is pre-filled with a hint from the sender's domain.
- Migrations reach QA through `migrate-qa.yml` and prod through `migrate-prod.yml`. Never `supabase db push`.
- Swift: `nonisolated deinit {}` on every new `@MainActor` class; lines ≤120 characters; semantic fonts; a11y labels.

## Review Focus

1. **Dates without a year near the new year:** an email received 2026-11-07 that says "JANUARY 24" must resolve to
   2027-01-24. Covered in W2's tests.
2. **The HTML-only "Register Here" links:** the link must survive into `links` and into the matching event's `url`.
   Covered in W2's Akron fixture test.
3. **The AI inventing a URL:** a model URL that isn't in the draft's `links` is dropped. Covered in I2.
4. **Two family devices claiming at once:** exactly one claim wins. Covered in W1's RPC test.
5. **A 1.0.x client confirming a draft that has `suggested_events`:** the old confirm still creates only the
   interaction and no events. Covered in W3.

---

## Phase A — Server foundation (web repo)

### W1: Schema + AI claim/submit RPCs (`trc-supabase`, Size M)

**Files:**
- Create: `supabase/migrations/<ts>_inbound_drafts_event_suggestions.sql`
- Create: `supabase/migrations/<ts>_events_inbound_draft_id.sql`
- Test: `tests/rls/inbound-drafts-ai.spec.ts` (follow the existing RLS spec pattern; scratch-stack recipe)

**Interfaces (produces):**
- New columns on `inbound_email_drafts`:
  - `body_html_links jsonb not null default '[]'` (`[{label, url}]`)
  - `suggested_events jsonb not null default '[]'`
  - `parse_source text check in ('none','heuristic','ai') default 'none'`
  - `ai_status text check in ('pending','claimed','done','failed','skipped') default 'pending'`
  - `ai_claimed_at timestamptz`
  - `ai_claimed_by uuid`
- New column `events.inbound_draft_id uuid null references inbound_email_drafts(id) on delete set null`.
- `SuggestedEvent` JSON shape, shared by the server and iOS:
  `{name, type, start_date (YYYY-MM-DD), end_date?, start_time?, location?, url?, audience?, cost?, confidence: {<field>: 'high'|'low'}}`
- RPC `claim_inbound_draft_ai(p_family_unit_id uuid) returns setof inbound_email_drafts`:
  - claims up to 3 drafts whose `ai_status = 'pending'`, or `'claimed'` with `ai_claimed_at < now() - 10 min`;
  - uses `FOR UPDATE SKIP LOCKED`;
  - sets `ai_status='claimed'`, `ai_claimed_by=auth.uid()`.
- RPC `submit_inbound_draft_ai(p_draft_id uuid, p_events jsonb, p_is_bulk boolean) returns void`:
  - succeeds only when the caller holds the claim;
  - sets `suggested_events`, `parse_source='ai'`, `ai_status='done'`, and `is_bulk_announcement`
    (add that column too: `boolean default false`).
- Both RPCs are `security definer` with an explicit family-membership check. `EXECUTE` is revoked from `public` and
  `anon` **by role name**, per the revoke-from-public trap.

**Steps:**
- [ ] Failing RLS spec: a family member can claim; a non-member gets 0 rows; two concurrent claims return disjoint
  sets; submitting without the claim raises; an expired claim can be re-claimed.
- [ ] Write the migrations. Keep any enum `ADD VALUE` in its own migration file.
- [ ] Spec green on the scratch stack. Regenerate `types/database.ts`.
- [ ] Commit, then open a PR.

### W2: Keep links + heuristic event parse in the webhook (`trc-web-dev`, Size M)

**Files:**
- Create: `server/utils/inboundEmail/htmlToTextWithLinks.ts`
- Create: `server/utils/inboundEmail/parseEventCandidates.ts`
- Modify: `server/api/webhooks/inbound-email.post.ts` (the body-fetch section around `resend.emails.receiving.get`
  and the draft insert)
- Test: `tests/unit/server/utils/inboundEmail/*.spec.ts`
- Fixture: `tests/fixtures/inbound/akron-camps.html`. Copy the Akron email's HTML and strip the unsubscribe and
  tracking URLs.

**Interfaces:**
- Consumes: W1's columns.
- Produces:
  - `htmlToTextWithLinks(html: string): { text: string; links: {label: string; url: string}[] }`. It keeps
    `label (url)` inline, keeps only http and https links, and drops unsubscribe and mailto links.
  - `parseEventCandidates(input: { text: string; subject: string; links: Link[]; receivedAt: Date }): SuggestedEvent[]`.
    The function is pure; use `date-fns`, which is already a dependency.

**Steps:**
- [ ] Failing tests:
  - The Akron fixture gives 2 events:
    - `{name:'Youth Camp', type:'camp', start_date:'2026-12-13', audience:'Grades 1st–8th'}`
    - `{name:'Prospect Camp', type:'camp', start_date:'2027-01-24'}`
  - Both have `location` containing "Stile Athletic Field House" and a `url` equal to their own "Register Here" link.
  - A plain 1:1 coach email ("Great to meet you at the game") gives `[]`.
  - The year rolls over to the next year when the month and day are before `receivedAt`.
  - An email with no HTML falls back to the text part.
- [ ] Implement both utils. In the webhook:
  - prefer the HTML, else the text;
  - store `body_text`, `body_html_links`, `suggested_events`;
  - set `parse_source = suggested_events.length ? 'heuristic' : 'none'`.
- [ ] Run the existing webhook and parser specs; they must stay green.
- [ ] Commit, then open a PR.

### W3: Confirm with events (`trc-supabase` + `trc-web-dev`, Size M)

**Files:**
- Create: `supabase/migrations/<ts>_confirm_inbound_draft_with_events.sql`
- Modify: `server/api/inbound-drafts/[id]/confirm.post.ts` (Zod schema plus the RPC call)
- Modify: `server/api/inbound-drafts/index.get.ts` (return the new columns)
- Test: `tests/unit/server/api/inbound-drafts/confirm.spec.ts`, plus an RLS spec for the RPC

**Interfaces:**
- Produces:
  - RPC `confirm_inbound_draft_with_events(<all existing confirm_inbound_draft params>, p_events jsonb)`.
    In one transaction it calls the existing interaction logic and then inserts each event with:
    - `family_unit_id` and `school_id` from the draft or interaction,
    - `event_source='email'`,
    - `inbound_draft_id`,
    - `registered=false`.

    It returns `{interaction_id, event_ids uuid[]}`.
  - The confirm endpoint accepts an optional `events: SuggestedEvent[]` (Zod: max 10; `start_date` required; `url`
    must be http(s)). When `events` is present it calls the new RPC; otherwise it calls the old one, unchanged.

**Steps:**
- [ ] Failing tests:
  - confirming with 2 events creates 1 interaction and 2 events, all linked;
  - the old request shape creates only the interaction (1.0.x compatibility);
  - a missing `schoolId` gives a 400;
  - a `javascript:` url gives a 400;
  - an RPC failure leaves no partial rows.
- [ ] Implement.
- [ ] Commit, then open a PR.

### W4: Expire unclaimed AI work (`trc-web-dev`, Size XS)

**Files:**
- Modify: `server/api/cron/inbound-email-purge.get.ts` (the existing daily cron; add one step)
- Test: its existing spec

**Steps:**
- [ ] Failing test: a draft that has been `pending` for more than 24 hours becomes `skipped`; `claimed` and `done`
  drafts are untouched.
- [ ] Implement as one `update ... where ai_status='pending' and created_at < now() - interval '24 hours'`.
- [ ] Commit, then open a PR.

## Phase B — Review screens

### W5: Web review screen (`trc-web-dev`, Size L)

**Files:**
- Modify: `pages/inbox/inbound-drafts.vue`
- Create: `components/InboundDrafts/DraftReviewLayout.vue` (email pane plus form pane)
- Create: `components/InboundDrafts/SuggestedEventForm.vue`
- Create: `components/InboundDrafts/SchoolPickerWithAdd.vue`. Reuse the existing add-school search component; the hint
  comes from the sender's domain.
- Test: component specs. Also add a smoke E2E only if the inbound flow is already in the smoke gate; otherwise add it
  to the weekly suite.

**Steps:**
- [ ] Failing component tests:
  - a draft with 2 `suggested_events` renders 2 forms with values filled in;
  - fields with low confidence and empty required fields are highlighted;
  - unticking an event leaves it out of the payload;
  - "Add another event" appends a blank form;
  - confirm is disabled until a school is chosen;
  - an `is_bulk_announcement` draft shows the "Program announcement" label;
  - the "Improving with Apple Intelligence…" note shows only when `ai_status='claimed'`.
- [ ] Implement:
  - side-by-side at ≥1024px, stacked below that;
  - the email shows `body_text` with links clickable (sanitized; no `v-html` on raw input);
  - poll or refresh the draft while `ai_status='claimed'`, and apply AI values only to fields the user hasn't touched.
- [ ] Gate: `npx tsc --noEmit`, lint, unit tests.
- [ ] Commit, then open a PR.

### I1: iOS models + API for suggestions and confirm-with-events (`trc-ios-dev`, Size S)

**Files:**
- Modify: `Features/InboundDrafts/Models/InboundEmailDraft.swift`
- Create: `Features/InboundDrafts/Models/SuggestedEvent.swift`
- Modify: `Features/InboundDrafts/Services/InboundDraftsAPIService.swift` and `InboundDraftsAPIManaging.swift`
- Test: `TheRecruitingCompassTests/Features/InboundDrafts/*`

**Interfaces:**
- Produces:
  - `struct SuggestedEvent: Codable, Equatable, Sendable`, matching W1's JSON shape with snake_case `CodingKeys`.
  - New draft fields, all optional: `suggestedEvents: [SuggestedEvent]`, `parseSource`, `aiStatus`,
    `isBulkAnnouncement`, `links`.
  - `func confirm(draftId: UUID, overrides: ConfirmOverrides, events: [SuggestedEvent]) async throws -> ConfirmResult`.
    It omits `events` when the array is empty.

**Steps:**
- [ ] Failing decode test using the Akron JSON from W2. Decoding an older payload without the new keys must still
  succeed.
- [ ] Implement.
- [ ] Run the tests: `scripts/run-ios-tests.sh --only TheRecruitingCompassTests/InboundDraftsAPIServiceTests` (and the
  model tests).
- [ ] Commit, then open a PR.

### I2: On-device AI extraction (`trc-ios-dev`, Size M)

Port the pattern from Foon (`foon-meal-planner/Foon/Core/AI/AIService.swift` and `RecipeStructuring.swift`).

**Files:**
- Create: `Core/Services/AI/OnDeviceAI.swift`. This is the `AIService` closure wrapper, `AIAvailability` and
  `AIOutcome`, all inside `#if canImport(FoundationModels)` plus `@available(iOS 26, *)`. Its `.none` stub is what
  iOS 18–25 uses.
- Create: `Features/InboundDrafts/AI/EmailEventExtraction.swift`, containing:
  - `@Generable struct GeneratedEmailEvents` with fields `events` (max 10) and `isBulkAnnouncement`;
  - `EmailEventExtraction.instructions`;
  - `static func extract(text:subject:links:receivedAt:_ ai:) async -> AIOutcome<[SuggestedEvent]>`.
- Create: `Features/InboundDrafts/AI/InboundDraftAIRunner.swift`. Called on scene `.active` when `ai.canRun` and the
  `inbound_drafts` flag is on, it runs claim → extract → submit. When the outcome is `.unavailable`, `.timedOut` or
  `.failed`, it does not submit, so the claim expires.
- Test: `TheRecruitingCompassTests/Features/InboundDrafts/EmailEventExtractionTests.swift` and
  `InboundDraftAIRunnerTests.swift`, with the AI stubbed.

**Steps:**
- [ ] Failing tests:
  - A stubbed model returns a URL that isn't in `links`: it is dropped.
  - A returned `start_date` that doesn't parse: that event is dropped.
  - The text is cut to 8,000 characters.
  - An unavailable AI means no claim RPC is called.
  - A timeout means no submit.
  - Sanitizing is the same whatever the input source (follow `StructuredRecipe`).
- [ ] Implement.
- [ ] Manual check on a real Apple Intelligence device with the Akron email: record the time taken and the output in
  the PR.
- [ ] Commit, then open a PR.

### I3: iOS review screen (`trc-ios-dev`, Size L)

**Files:**
- Create: `Features/InboundDrafts/Views/DraftReviewView.swift`
- Create: `Features/InboundDrafts/Views/Components/SuggestedEventFormSection.swift`
- Create: `Features/InboundDrafts/Views/Components/OriginalEmailDisclosure.swift`
- Create: `Features/InboundDrafts/ViewModels/DraftReviewViewModel.swift` (`@Observable @MainActor`,
  `nonisolated deinit {}`)
- Modify: `InboundDraftsViewModel.swift`, so "Review" opens `DraftReviewView` instead of the plain Log Interaction form
- Reuse: the existing add-school search sheet for `SchoolPickerWithAdd`
- Test: `DraftReviewViewModelTests.swift`, plus a UI test only for the confirm path

**Steps:**
- [ ] Failing view-model tests. They mirror W5's component tests one for one (including the touched-fields rule when
  the AI result arrives), plus: confirm sends `events` only for ticked forms.
- [ ] Implement:
  - iPhone: the forms first, with a collapsible "Show original email";
  - iPad (regular width): side by side;
  - a11y labels on every toggle and field;
  - empty or low-confidence fields marked with an icon and an a11y hint, not only by color.
- [ ] Build plus tests through `scripts/run-ios-tests.sh --only ...`.
- [ ] Commit, then open a PR.

## Phase C — Reminders (web server; iOS consumes them)

### W6: Family-wide registration reminders + follow-up rule check (`trc-web-dev`, Size M)

**Files:**
- Modify: `server/utils/notificationGenerator.ts` (`generateEventNotifications`, plus a new
  `generateEventRegistrationNotifications`)
- Modify: `server/api/cron/generate-notifications.get.ts` (iterate over family members, not only `role='player'`)
- Modify: `server/utils/notificationDelivery.ts`
- Create: `server/utils/rules/eventRegistration.ts`, and register it in `server/utils/ruleEngine.ts` and
  `server/utils/rules/index.ts`
- Investigate and fix: `server/utils/rules/eventFollowUp.ts` (it reads `event_date`; the column is `start_date`)
- Test: specs next to each file

**Interfaces:**
- Produces:
  - notification templates `event_register_after_add` and `event_register_before_10`, each with
    `relatedEntityType:'event'`. The dedupe key is (user, event, template), not the date.
  - suggestion `rule_type: 'event-registration'`, with action `open_event` and payload `{event_id, url}`.

**Steps:**
- [ ] First, query QA for whether `event-follow-up` suggestions have ever been created. Record the result in the PR.
- [ ] Failing tests:
  - a camp created on or after `REGISTRATION_REMINDER_SINCE`, 3 days old and unregistered: every family member gets 1
    push;
  - re-running the cron sends no duplicates;
  - 10 days before: a second push; nothing more after that;
  - an event less than 2 days away: no push;
  - `registered=true`: no push and no suggestion;
  - type `game`: no reminder;
  - a parent receives the existing 7-day and 1-day reminders;
  - `event` notification preference off: no push;
  - the follow-up rule fires for an attended event 3 days old.
- [ ] Implement. Events are queried by `family_unit_id`.
- [ ] Commit, then open a PR.

### I4: iOS registration actions (`trc-ios-dev`, Size S)

**Files:**
- Modify: the suggestion row and actions in `Features/Suggestions/` (handle `event-registration`: "Register" opens
  `url` in Safari, "Mark registered" calls the events update)
- Modify: push deep-link routing for `relatedEntityType == "event"` (confirm the handler exists; add it if not)
- Test: suggestion action tests

**Steps:**
- [ ] Failing tests:
  - an `event-registration` suggestion shows both actions;
  - "Mark registered" sets `registered=true` and removes the suggestion;
  - with no `url`, "Register" is hidden.
- [ ] Implement.
- [ ] Commit, then open a PR.

## Phase D — Make forwarding easy, plus legal

### W7: Web forwarding card + help + privacy (`trc-web-dev`, Size S; the policy text needs Chris's approval)

**Files:**
- Modify: `pages/settings/family-management.vue` (the forwarding section)
- Create: `server/api/family/inbound-address.vcf.get.ts`, which returns a vCard `FN:TRC Coach Inbox` with the
  family's address
- Modify: `pages/legal/privacy.vue`
- Add: a Help Center article "Forward coach and camp emails" (closes web #677)

**Steps:**
- [ ] Failing tests:
  - the vCard endpoint returns `text/vcard` with the right `EMAIL`;
  - a non-member gets a 403;
  - the copy button writes the address to the clipboard.
- [ ] Implement:
  - a short "How it works" with the Akron-style example;
  - privacy policy wording: emails are parsed on our servers by rules, and on your family's own Apple device by
    Apple's on-device model; not sent to AI providers.
- [ ] Commit, then open a PR (the policy wording goes to Chris for review).

### I5: iOS forwarding card (`trc-ios-dev`, Size S)

**Files:**
- Modify: `Features/Family/Components/ForwardCoachEmailsCard.swift`
- Test: view-model or unit tests for building the `CNMutableContact`

**Steps:**
- [ ] Failing test: building the contact gives `givenName "TRC Coach Inbox"` and one work email equal to the address.
- [ ] Implement:
  - a Copy button (`UIPasteboard`);
  - "Add to Contacts" with `CNContactViewController(forUnknownContact:)`, which needs no contacts permission;
  - a "How it works" disclosure.
- [ ] Commit, then open a PR.

## Order and dependencies

```
W1 ─┬─ W2 ──┐
    ├─ W3 ──┼─ W5 (web review)
    ├─ W4   │
    └───────┴─ I1 ─┬─ I2 (on-device AI)
                   └─ I3 (iOS review)
W6 → I4            (independent of W1–W5)
W7, I5             (independent; can ship first)
```

- The web side can ship before iOS, because the server changes are additive.
- The iOS issues (I1–I5) ride one iOS train.
- The feature is turned on through `inbound_drafts` once I3 and W5 are both Verified.

## Issues (filed 2026-11-09, Status Ready, P2, no train yet)

Epic: web #1666 · W1 web #1667 · W2 web #1668 · W3 web #1669 · W4 web #1670 · W5 web #1671 · W6 web #1672 ·
W7 web #1673 · I1 ios #557 · I2 ios #558 · I3 ios #559 · I4 ios #560 · I5 ios #561

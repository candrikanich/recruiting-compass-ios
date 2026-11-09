# Email → Events: turn forwarded camp/program emails into Events

Status: design, pending Chris's approval · 2026-11-09 · Platforms: web (server + UI) and iOS

## Why

College programs email families about camps, prospect days and showcases. A typical example is Akron Baseball's
off-season camp schedule (2026-11-07, from `meversol@uakron.edu`): two dated camps, one location and two
"Register Here" links. Today, putting that into TRC means typing each Event by hand, or forwarding the email to the
family inbound address. Forwarding produces one plain `interactions` row, and the registration links are lost because
the server keeps only the email's text part.

Success: Chris forwards that email and opens the app. The review screen shows the email next to two pre-filled camp
Events. He ticks both and confirms. The camps then show up on the calendar with their registration links, the email
is logged as an incoming interaction, and he gets a push reminder to register.

## Goals

1. **Extract events from forwarded emails.**
   - A server-side heuristic parse runs on every inbound email.
   - An on-device Apple Foundation Models pass improves the result. It runs on **any family member's** eligible
     iPhone or iPad, so families without one still get the heuristic result.
2. **Upgrade the review screen** on web and iOS:
   - The original email sits beside one pre-filled Event form per event found.
   - Empty or uncertain fields are highlighted for the user to fill in.
   - The user picks which events to create. Confirming creates the chosen Events **and** logs the email as an
     inbound interaction (Chris: "log it as an incoming interaction to keep track of it").
3. **Remind families to register** for upcoming events that aren't marked registered, for *all* events and not only
   imported ones:
   - an Action Items suggestion, and
   - push notifications.
4. **Make the forwarding address easy to find and use:**
   - a copy button,
   - "Add to Contacts" (a vCard), and
   - real instructions.

## Non-goals

- iOS Share Extension, paste-text import, `.ics` import and URL import. These can reuse the parser later.
- Creating schools automatically from unknown sender domains (web #675 covers that separately).
- Server-side or cloud LLM calls. The AI runs only on the user's own device.
- Reading the user's mailbox (no Gmail or IMAP integration).

## Anti-goals (a failure even if it "works")

- Events created without the user confirming them.
- The AI inventing a date, link or location the email doesn't contain. Every AI field must come from the text, and
  the heuristic result stays as the fallback.
- Email content sent to any third-party AI service.
- Breaking iOS versions already in the field: every server change is **additive**, and the existing confirm endpoint
  and fields keep working unchanged for 1.0.x clients.
- Nagging: at most two registration pushes per event, and none when the event is less than 2 days away.

## Constraints

- **iOS minimum is 18.0.** `FoundationModels` needs iOS 26+ and an Apple Intelligence-capable device that has
  Apple Intelligence turned on, so every call is behind an `#available` check plus `SystemLanguageModel.availability`.
  CI and simulators usually have no model, so the model must be stubbable in tests.
- The on-device model has about a 4K-token context. The text sent to it is capped at about 8,000 characters.
- The inbound pipeline lives in the **web repo** (Resend Inbound webhook at `server/api/webhooks/inbound-email.post.ts`;
  table `inbound_email_drafts`). Migrations go through `migrate-qa.yml` / `migrate-prod.yml`, never `db push`.
- **Family scope:** drafts, suggested events and Events are scoped by `family_unit_id`.
- The feature stays behind the existing `inbound_drafts` feature flag.
- The privacy policy needs a short update: forwarded emails are parsed on the server by rules, and on the family's
  own Apple device by Apple's on-device model. Nothing goes to an AI provider.

## Design decisions (made with Chris)

### 1. Ingest: keep the links
The webhook currently uses only `fullEmail.text`. Change it to:
- Build the body from the HTML when one exists. Convert it to plain text, keeping each link as `label (url)`, so
  "Register Here" survives. Fall back to the text part when there is no HTML.
- Store the result in the existing `body_text` field. My guess: also store the extracted links in a separate field
  so the parser and the UI don't have to scrape them out of the text again.

### 2. Heuristic parse (server, every email)
A pure TypeScript function `parseEventCandidates(body, subject, receivedAt)`. It extracts zero or more candidate
events with these fields:
- `name`, taken from the line around each date,
- `type` (camp, showcase or visit, from keywords),
- `start_date` and optional `end_date`; a date with no year resolves to its next occurrence after `receivedAt`,
- `location`, when a clear "location" or "hosted at" line exists,
- `url`, the registration link nearest each event,
- `notes`, for audience text such as "Grades 1st–8th".

Results are stored on the draft as `suggested_events` (jsonb), together with `parse_source = 'heuristic'`.

### 3. On-device AI parse (iOS, any family device)
This copies the pattern Foon already ships (`foon-meal-planner/Foon/Core/AI/`): `AIService` wrapped in closures with
a timeout, a `@Generable` output schema, and strict trimming of the model's answer.

- New draft columns, all additive:
  - `ai_status`: pending, claimed, done, failed or skipped,
  - `ai_claimed_at`,
  - `ai_claimed_by`.
- When the app opens on an eligible device, it claims pending drafts for its family through a `claim_inbound_draft_ai`
  RPC. The claim is atomic, and an unfinished claim expires after about 10 minutes.
- The device runs the model with a `@Generable EmailEvents { events: [{name, type, startDate, endDate?, location?,
  registrationURL?, audience?}], isBulkAnnouncement }` schema, then writes the result back through
  `submit_inbound_draft_ai`.
- A link the model returns is kept only if it appears in the email's own list of links.
- The AI result replaces the heuristic `suggested_events` only while nobody has edited them. `parse_source` then
  becomes `ai`.
- The model sees only the email text, never other family data.
- I chose dedicated columns on `inbound_email_drafts` rather than Foon's general job queue, because only one job type
  needs it here.

### 4. Review screen (web + iOS, parity)
- Layout:
  - **Web:** the email on the left; the event forms on the right.
  - **iPhone:** the event forms come first, with a collapsible "Show original email" panel.
  - **iPad:** side by side.
- Each form is pre-filled from `suggested_events`. Missing or unsure fields are highlighted.
- Each event has an include toggle; all are on by default.
- An "Add another event" button lets the user add one by hand.
- The interaction section stays, pre-filled with direction inbound and type email. Its school is shared with the events.
- Confirm runs in one transaction: it creates the interaction plus the chosen events. Each event gets:
  - `event_source = 'email'`,
  - `inbound_draft_id` set (new nullable column on `events`),
  - `registered = false` by default.

  This is a new endpoint, or a new optional `events[]` field on the confirm request. The old request shape keeps
  working.
- While the AI is still pending on another device, the screen says "Improving with Apple Intelligence…" and still lets
  the user confirm with the heuristic result.

### 5. Registration reminders (all unregistered upcoming events)
- **Action Items:** a new suggestion rule, `event-registration`, fires for every upcoming event that isn't registered.
  The action is "Register" (it opens the event's `url`) or "Mark registered".
- **Push:** extend `generateEventNotifications` (`server/utils/notificationGenerator.ts`) with:
  - a registration push **3 days after** the event was created, if it's still unregistered, and
  - another **10 days before** the event,
  - none if the event is less than 2 days away.

  Pushes are made idempotent with `createNotificationIfAbsent`, gated by the `event` notification preference, and
  deep-link to the event.
- The reminders stop once the event is marked registered or the event date passes.

### 6. Forwarding address
On iOS (`ForwardCoachEmailsCard`) and the matching web settings card:
- a copy button,
- "Add to Contacts", which downloads a vCard named "TRC Coach Inbox",
- a short "How it works" with an example,
- a Help Center article (closes web #677).

## Known issues found while designing (verify with data, don't assume)

- The suggestion rule `eventFollowUp.ts` filters on `event_date`, but the events table field is `start_date`. That rule
  may never fire. Check it against real data and fix it alongside the new rule.
- The `generate-notifications` cron only iterates over `role = 'player'` users, so parents may never get event or
  registration pushes. That goes against the product rule that the family sees the same data. See open question 1.

## Left to the builder

- The HTML-to-text library: use an existing dependency if one covers it. Otherwise a small, tested converter.
- Date-parsing details and the keyword lists.
- The exact RPC signatures, and the RLS rules for the new columns (family members only).
- How the claim expiry is implemented.
- Copy text, staying with the existing voice.

## Calls made by Claude (Chris to check)

- **Which events get reminders:**
  - Only `camp` and `showcase` events, since registration doesn't fit games or visits.
  - A null `registered` counts as unregistered.
  - The "3 days after created" push applies only to events created after the feature ships, so launch doesn't send
    a burst of pushes for old events. The "10 days before" push applies to all events.
  - Each of the two pushes gets its own notification type or key so it is deduplicated separately.
- **No eligible device in the family:**
  - `ai_status` starts as `pending`, but the screen says "Improving with Apple Intelligence…" only once a device has
    claimed the draft.
  - Unclaimed drafts become `skipped` after 24 hours.
  - The heuristic result can always be confirmed, so nothing ever waits on the AI.
- **Bulk announcements:** `isBulkAnnouncement` only adds a label in the review screen ("Program announcement"). The
  existing coach matching and auto-create behavior is unchanged; the Akron sender is a real staff member.
- **"Edited" means edited on this screen:** review edits stay in the client until confirm. An open review screen
  swaps in the AI results only for fields the user hasn't touched. There is no new save-draft endpoint.

## Decided by Chris (2026-11-09)

1. **Every family member receives the registration reminders**, both the push and the Action Item, because this is a
   collaborative journey.
   - The cron must reach parents and guardians, not only `role = 'player'`.
   - Events are queried by `family_unit_id`.
   - The two-push limit applies per person per event.
   - Marking an event registered clears the reminder for everyone.
   - Check whether the existing event reminders (7 days and 1 day before) should also go to the whole family. My call:
     yes, in the same change, since they share the code path.
2. **Unknown school:** confirming requires a school, chosen in **one picker** that lists the family's schools plus
   "Add this school" inline. That picker reuses the existing add-school search, pre-filled with a hint from the
   sender's domain (for example `uakron.edu` → "Akron"). This combines options (a) and (c). A school is never created
   without the user confirming it.

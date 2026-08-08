# Action-Item Buttons + Learn More (iOS) — Design

**Date:** 2026-08-08
**Status:** Approved (design)
**Repos:** `recruiting-compass-ios` (primary), `recruiting-compass-web` (suggestions endpoints only)

## Problem

The iOS Dashboard "Action Items" widget renders suggestions (message + urgency dot +
Complete/Dismiss icon buttons) but has **no guided action**. The web app gives each
suggestion a primary CTA (Add School / Log Interaction / Add Video), a "Learn More"
help modal, and Dismiss. Players (and their parents) on iOS can read a suggestion but
can't act on it in one tap.

Two current constraints compound this:

1. **`suggestion.actionType` / `relatedSchoolId` are decoded but unused** on iOS — the
   hooks for a CTA already arrive in the payload.
2. **Parent-preview blocks all mutations.** `DashboardViewModel.dismissSuggestion` /
   `completeSuggestion` early-return when `isParentPreviewMode`. This contradicts the
   product's family-collaboration model: parents should assist the player with
   everything *except* direct coach communication (which belongs to the player, from
   the player's own account/device — enforced by the separate comms feature, not here).

## Goals

- Add a primary CTA and a Learn More modal to the shared `ActionItemCard`.
- Let parents in preview mode use the CTA **and** Complete **and** Dismiss.
- Present suggestions ordered by urgency (high → medium → low).
- Fix the web dismiss/complete endpoints so a parent's action actually persists.

## Non-Goals

- **Video CTA** (`add_video` / `update_video`). The web video feature is broken
  (dead `/videos` route, phantom `videos` table the rules read but nothing writes).
  Handled separately as "Path B" in another session. Video suggestions on iOS show
  Learn More + Complete + Dismiss, no CTA.
- Red/yellow/green progress status (cut — action items are done/not-done todos).
- Urgency-visual overhaul (future).
- Any DB migration or web change outside the two suggestion endpoints.

## Prerequisite (already implemented, separate commit)

`recruiting-compass-web/server/utils/triggerSuggestionUpdate.ts` — the rule engine
loaded `schools`/`interactions` by legacy `user_id`/`logged_by`; the family-symmetric
model owns them by `family_unit_id`. Fixed to resolve `family_unit_id` first and scope
those two queries to it (a 53-school family previously read as 1 → bogus "1 schools"
suggestion). Not part of this plan's diff; noted because it's the reason the school-list
suggestion counts are now correct.

---

## iOS Design

### Shared component: `ActionItemCard`

`Features/Dashboard/Components/ActionItemCard.swift` is rendered by **both** the
dashboard widget (`ActionItemsWidget`, capped `prefix(3)`) and the full-screen list
(`SuggestionsListView`, all items). Editing the card updates both surfaces.

**New layout** — message on top, then an action row:

```
[ Primary CTA ]   Learn More        ✓ Complete   ✕ Dismiss
   (filled,        (text button)     (existing icon buttons, kept)
    urgency color)
```

- Primary CTA: filled button tinted by `suggestion.urgency.color`, shown only when
  `actionType` maps to an iOS destination (below). Hidden otherwise.
- Learn More: plain text button, always shown, opens the help modal.
- Complete (`checkmark.circle.fill`) / Dismiss (`xmark.circle.fill`): existing 44×44
  icon buttons, retained.
- No button in this row is gated by parent-preview (see Gating).

### Primary CTA mapping

Driven by `suggestion.actionType` (`String?`). Presentation reuses the existing
sheet pattern in `DashboardView` (`DashboardAddSchoolSheet` — a `NavigationStack`
wrapping the add view, built with `familyUnitId` + `userId`, refetching dashboard on
dismiss).

| `actionType`      | Button label     | Action |
|-------------------|------------------|--------|
| `add_school`      | "Add School"     | Present `AddSchoolView` in a sheet (mirrors `DashboardAddSchoolSheet`). |
| `log_interaction` | "Log Interaction"| Present `AddInteractionView` in a sheet (new `DashboardAddInteractionSheet` mirror); pass `relatedSchoolId` when present so the interaction is pre-associated. |
| `add_video`, `update_video` | *(no CTA)* | Learn More only (Path B). |
| `nil` / unknown   | *(no CTA)*       | Learn More only. |

**Sheet inputs** (same source as the existing add-school sheet):
- `familyUnitId` = `familyManager.currentMember?.familyUnitId ?? ""`
- `userId` = `authManager.user?.id ?? ""` (the acting user — parent or player; schools
  are `family_unit_id`-owned and interactions record `logged_by = userId`, so a parent
  acting on the family's behalf is recorded accurately).
- On sheet dismiss → `await viewModel.fetchDashboardData()` (refreshes counts + list).

`AddInteractionView(interactionsService: InteractionsServiceImpl(supabaseManager: .shared), familyUnitId:, userId:)`.
`relatedSchoolId` prefill: verify how `AddInteractionViewModel` accepts a pre-selected
school (the `InteractionDestination.addWithSchool(String)` path already exists in
`InteractionsListView`); reuse that mechanism rather than adding a new init param if
possible.

**Presentation ownership.** To keep the card usable from both hosts without each host
re-implementing sheet state, the card owns its own CTA sheet + Learn More modal
`@State`, taking `familyUnitId`, `userId`, and an `onActionCompleted: () -> Void`
closure (hosts wire it to their refetch). This mirrors the existing inline
service-construction pattern (`SchoolsServiceImpl(supabaseManager: .shared)`), accepted
here for parity with `DashboardAddSchoolSheet`. Both `ActionItemsWidget` and
`SuggestionsListView` pass the same three inputs through.

### Learn More

- New `Features/Dashboard/Models/SuggestionHelpContent.swift`:

  ```swift
  struct SuggestionHelpContent {
    let title: String
    let whyItMatters: String
    let howToComplete: [String]
    let coachesExpect: [String]
    let timeline: String
  }
  ```

  Static lookup `static func content(for ruleType: String) -> SuggestionHelpContent`,
  porting the web `helpContentMap` verbatim from
  `recruiting-compass-web/components/Suggestion/SuggestionHelpModal.vue:185-333`.

  Keyed entries (7): `school-list-building`, `showcase-attendance`,
  `ncaa-registration`, `formal-outreach`, `official-visit`, `missing-video`,
  `interaction-gap`. Unknown rule types (`event-follow-up`,
  `priority-school-reminder`, `video-link-health`, anything new) → the web's generic
  fallback object (`SuggestionHelpModal.vue:326-333`).

  All copy is wrapped in `String(localized:)` per the app's localization standard.

- New `Features/Dashboard/Components/SuggestionHelpModal.swift`: a SwiftUI sheet
  presenting title, "Why it matters", numbered "How to complete", "What coaches
  expect" bullets, and timeline. Opened from the card's Learn More button, keyed by
  `suggestion.ruleType`.

### Urgency sort

In `DashboardViewModel`, sort `suggestions` high → medium → low wherever the array is
assigned from a fetch (both the normal path and the 401-refresh-retry path in
`fetchSuggestions`). Stable sort preserves the server's within-urgency ordering. Add a
sort weight to `UrgencyLevel` (e.g. `var sortWeight: Int { high=0, medium=1, low=2 }`)
and apply `.sorted { $0.urgency.sortWeight < $1.urgency.sortWeight }`. Benefits both
the widget's `prefix(3)` and the full list.

### Gating (parent-preview) — behavior change

Remove the `guard !isParentPreviewMode else { return }` early-return from
**both** `DashboardViewModel.dismissSuggestion` and `completeSuggestion`. Remove the
`canDismissOrComplete` suppression so the CTA + Complete + Dismiss are always available.
`ActionItemCard` / `ActionItemsWidget` / `SuggestionsListView` drop the
`canDismissOrComplete` parameter (or hardcode `true`) accordingly.

Rationale: family-collaboration model — parents assist. The only parent restriction is
coach communication, which is enforced by the comms feature, not by action items. None
of these actions message a coach (`log_interaction` records a past contact; it does not
send anything).

---

## Web Design (suggestions endpoints only — clear of the comms session)

**Problem.** `server/api/suggestions/[id]/dismiss.patch.ts:29` and the analogous
`complete.patch.ts` scope the update `.eq("athlete_id", user.id)`. A parent's
`user.id` ≠ the suggestion's `athlete_id` (the player), so **no row matches**. A
Postgres `UPDATE ... WHERE` with zero matches returns **no error**, so the endpoint
returns `{ success: true }` while persisting nothing — the iOS card optimistically
disappears then returns on the next fetch. Ungating iOS is inert without this fix.

The server client (`createServerSupabaseClient`) is **service-role** (bypasses RLS), so
resolving the athlete id is the sole and sufficient guard; it stays constrained to the
parent's own family.

**Change.**

1. New helper `server/utils/resolveAthleteId.ts`:
   `resolveAthleteId(userId: string, supabase): Promise<string>` — returns `userId` for
   players; for a parent, looks up their `family_members.family_unit_id` (role
   `parent`) then the family's `player` member's `user_id`, falling back to `userId`
   when unresolved. This is the exact logic currently inlined in
   `server/api/suggestions/index.get.ts:21-44` — extract it there and reuse.

2. `dismiss.patch.ts` and `complete.patch.ts`: resolve `const athleteId = await
   resolveAthleteId(user.id, supabase)` and scope `.eq("athlete_id", athleteId)`. Audit
   logs keep `userId: user.id` (who acted) but reference the resolved athlete.

3. `index.get.ts`: replace its inline block with the helper (no behavior change).

**Scoping note for the other session:** this touches only
`server/api/suggestions/**` and a new `server/utils/resolveAthleteId.ts`. It does not
touch communications code.

---

## Testing

**iOS (unit, `@MainActor` test classes with `nonisolated deinit`):**
- `actionType` → CTA label + visibility mapping (`add_school`, `log_interaction`,
  `add_video`/`update_video` → no CTA, `nil` → no CTA).
- `log_interaction` with/without `relatedSchoolId` selects the right sheet target.
- Urgency sort: mixed-urgency input → high, medium, low order; stable within urgency.
- `SuggestionHelpContent.content(for:)`: known key returns its entry; unknown key
  returns the fallback.
- Parent-preview: dismiss/complete now proceed (no early return); assert the service
  call is made.

**Web (Vitest):**
- `resolveAthleteId`: player → self; parent → linked player; parent with no family →
  self.
- `dismiss` / `complete` endpoints: parent caller updates the player's suggestion row
  (mocked supabase asserts `.eq("athlete_id", <playerId>)`).

## Open Questions

None. (Video CTA parity deferred to Path B by decision.)

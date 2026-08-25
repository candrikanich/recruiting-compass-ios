# Coach Detail Redesign — iOS Design Spec

**Date:** 2026-08-25
**Author:** iOS session (Claude)
**Source of truth:** Figma frame `coach-detail-ios` node `13:4` (390×1276pt) — file "Coach Detail — Web Capture" (https://www.figma.com/design/A4LleRjo8wP6djA4UqADzB/Coach-Detail-%E2%80%94-Web-Capture?node-id=13-4). Frame image captured at `planning/assets/coach-detail-ios-figma-13-4.png` in the web repo worktree.
**Web handoff:** `iOS_SPEC_coach-detail-redesign-2026-08-25.md` (behavior/insights), `iOS_SPEC_coach-detail-followups-2026-08-25.md` (deltas — already shipped PR #62).
**Ships as:** ONE PR to `main`.

The user has explicitly asked that the iOS screen **look like the Figma frame**. Where the web handoff deferred visual pieces (analytics gauge card, stat-card rings — web §6.1/§6.2), iOS **builds them** to match the frame. Those rings/gauge are decorative-or-simple-derived, not reverse-engineered proportional math. This visual-fidelity choice is a deliberate iOS-vs-web divergence, recorded in §9.

---

## 1. Goal

Replace the current stacked-sections `CoachDetailView` with the Figma redesign: a compact identity toolbar, conditional alert banners, ringed KPI cards, a colored direct-channels action grid, an outreach analytics card, the interactions log, internal notes, a tags card, and a profile-meta card — every section wrapped in a white/elevated rounded card ("box every section").

## 2. Data model + persistence (new fields)

`coaches` table already has `tags text[]` and `source text` on the shared prod DB (web migration `20260906...` — applied; **no iOS migration**).

Add to iOS:

| Type | Field | Notes |
|---|---|---|
| `Coach` | `tags: [String]` (default `[]`) | Decode `"tags"`; default `[]` when absent/null. |
| `Coach` | `source: String?` | Decode `"source"`. |
| `EditableCoach` | `tags`, `source` | Seeded from `Coach`. |
| `CoachFormState` | `tags`, `source` | Create form. |
| `CoachCreateRequest` / `CoachUpdateRequest` | `tags`, `source` | Encode `"tags"`, `"source"`. `updateCoachTags`-equivalent write path. |

**Validation caps (mirror web Zod `coachSchema`), enforced client-side before any write:**
- `tags`: ≤ **20** items; each trimmed, non-empty, ≤ **40** chars; drop empties/dupes.
- `source`: ≤ **80** chars; empty → `nil`.

No enum, no taxonomy, no autocomplete (deferred both platforms).

## 3. Insights — port `useCoachInsights` exactly

New pure value type `CoachInsights`, computed from `coach` + `[Interaction]`. Reproduces the web composable so both platforms show identical numbers.

```
OVERDUE_DAYS = 14

daysSinceContact: newest interaction occurredAt (nil-occurredAt filtered — displayDate
  defaults to .now), else stored last_contact_date, else nil. (Already live in
  CoachDetailViewModel from PR #62 — move the logic into CoachInsights.)
isOverdue: daysSinceContact != nil && daysSinceContact > 14   (strictly greater)
totalInteractions: interactions.count
sentReceived: sent = count(direction == .outbound); received = count(rest)
responseRate: totalInteractions == 0 ? 0 : round(received / total * 100)   // integer %
preferredChannel: interactions empty ? nil : mode of interaction.type (first-encountered-max)
overdueAlert: == isOverdue
channelPreferenceAlert: preferredChannel != nil && totalInteractions >= 1
```

Unit-tested against known web values. Existing `CoachStats` (days-since/preferred/total) is subsumed; either extend `CoachStats` → `CoachInsights` or keep `CoachStats` and add the alert/rate fields. Implementation picks one; the pure function is what gets tested.

## 4. Layout — `CoachDetailView`, portrait, boxed sections

One `ScrollView`. Every section is wrapped in a shared **`SectionCard`** (elevated rounded-rect: `Color(.secondarySystemBackground)` fill, `separator` hairline stroke, 12pt radius, `brandShadowSm()`, 16pt padding) — matching `CoachCardView.fullBody`'s chrome. Section order top→bottom (matches frame):

1. **Identity toolbar** (`CoachDetailHeader`, rebuilt — see §5.1)
2. **Alerts** (`CoachAlertsSection` — 0/1/2 banners, §5.2)
3. **KPI stat cards** (`CoachStatsGrid`, restyled — §5.3)
4. **Direct Channels** grid (`CoachDirectChannelsGrid` — §5.4)
5. **Outreach History & Analytics** (`CoachAnalyticsCard` — §5.5)
6. **Interactions History** (`CoachInteractionsLogSection`, existing — restyle into `SectionCard`)
7. **Internal Notes** (existing `NotesSection` — into `SectionCard`, label "INTERNAL NOTES" + pencil)
8. **Tags** (`CoachTagsCard` — §5.6)
9. **Profile Meta** (`CoachProfileMetaCard` — §5.7)

Section labels use the uppercase, bold, small, `slate500`/secondary style from the frame ("DIRECT CHANNELS", "TAGS", "PROFILE META", "INTERNAL NOTES").

`CoachStatisticsSection` (existing): fold into the analytics card if redundant; otherwise drop. `CoachMetricsSection`: superseded by `CoachAnalyticsCard` for the primary Sent/Received + Response-Rate + gauge visual; keep any unique ranking/insight lines it renders below the gauge.

## 5. Components (visual detail from the frame)

### 5.1 Identity toolbar (`CoachDetailHeader` rebuilt)
Horizontal row (NOT the centered 100pt avatar shipped in PR #62 — that big-avatar header is replaced):
- **Left:** `SchoolLogoAvatar` at ~40pt (school favicon, coach-initials fallback).
- **Middle:** name (`.headline`/18 bold) over "`role.displayName`" (`.subheadline`/13, secondary). Frame shows `Recruiting Candidate · Head Coach` — role line only (the "Recruiting Candidate" prefix is a web label; iOS shows `role.displayName`).
- **Right:** two 32–36pt rounded-square buttons — **edit** (pencil, `blue600` on `blue100`) and **delete** (trash, `red600` on `red100`). These move the edit/delete actions into the header to match the frame. The nav-bar `ellipsis.circle` menu keeps Quick Communication (and may keep edit/delete as redundant affordances or drop them — implementer's call; header buttons are canonical).

### 5.2 Alerts (`CoachAlertsSection`)
Two independent conditional banners inside `SectionCard`-less full-width rounded cards (they ARE the card):
- **Outreach Overdue** — shown when `overdueAlert`. Red: `red100`/`errorBackground` fill, `red500` accent, red border. Warning-triangle icon in a red circle. Title "Urgent: Outreach Overdue" (`red600` bold), body "No contact in {days} days – reach out immediately to maintain connection."
- **Channel Preference** — shown when `channelPreferenceAlert`. Blue: `blue100` fill, `blue500`/`blue600` accent. Info icon in a blue circle. Title "Channel Preference detected" (`blue600` bold), body "Prefers responding via {preferredChannel.displayName}."
Both can co-occur, one, or neither. Reuse existing `WarningBanner`/banner tokens where they fit.

### 5.3 KPI stat cards (`CoachStatsGrid` restyled)
3 equal cards in a row, each a bordered rounded card (frame: overdue card gets a red border/tint). Per card: uppercase label (top, `slate500`), big value, a sub-line, and a **ring accent** on the right (decorative circle; not proportional math per web §6.1).
- **DAYS SINCE:** value `{days}` (red when overdue), red **OVERDUE** pill under it when `isOverdue`, red ring.
- **INTERACTIONS:** value `{total}`, "{total} logged" sub, blue ring.
- **PREFERRED:** value `{preferredChannel.displayName}` (truncates, e.g. "Ph…"), "{responseRate}% rate" (green) sub, orange ring.
Empty/`—` state when `daysSinceContact == nil` (not 0, not OVERDUE).

### 5.4 Direct Channels (`CoachDirectChannelsGrid`)
`SectionCard` labelled "DIRECT CHANNELS". 2 rows × 3 filled pill buttons, icon + label, white text, rounded 10–12pt:
| Button | Fill | Action |
|---|---|---|
| Email | `blue500` | existing email path (Quick Comm or Mail) |
| Text | `emerald500` | existing text path |
| Call | `orange500` | OS dialer (`tel:`) |
| Twitter | `sky500` (new token `#0ea5e9`) | open profile + arm social-DM prompt (§6) |
| Instagram | `fuchsia500`→`pink500` gradient (new `#d946ef`) | open profile + arm social-DM prompt (§6) |
| Log Activity | `slate700` dark | existing Log Interaction flow, coach pre-selected |
Buttons ≥44pt hit target; brand-mark assets `LogoX`/`LogoInstagram` for X/IG (existing).

### 5.5 Outreach History & Analytics (`CoachAnalyticsCard`)
`SectionCard` titled "Outreach History & Analytics", "All Time" link top-right (static label; no range picker in v1). Left column: **Sent / Received** row ("{sent}/{received}") over a two-tone progress bar; **Response Rate** row ("{responseRate}%") over a green progress bar. Right: a ring gauge showing "{responseRate}%" + a qualitative caption ("Great Progress" ≥ threshold, else neutral copy). All values from `CoachInsights`. This replaces web's deferred gauge card per user direction.

### 5.6 Tags (`CoachTagsCard`)
`SectionCard` labelled "TAGS". Wrapping chips (`slate100` bg, `slate600` text, rounded), each removable (× on chip in edit affordance). "+ Add Tag" (`blue600` link) appends inline via a text field / small sheet. Optimistic update then persist through the tags write path; caps from §2 enforced before write. Empty state: just "+ Add Tag".

### 5.7 Profile Meta (`CoachProfileMetaCard`)
`SectionCard` labelled "PROFILE META". Three key/value rows, value right-aligned:
- **Coach Since** = `coach.createdAt` (formatted e.g. "Jan 15, 2026")
- **Source** = `coach.source ?? "—"`
- **Last Updated** = `coach.updatedAt`

## 6. Social-DM return-confirmation (iOS behavior — divergence from web)

Web fires-on-open (logs an outbound interaction the instant X/IG is tapped, no confirm — web §6.3). **iOS instead confirms on return**, per user decision:

1. Tapping **Twitter** or **Instagram** in Direct Channels: set `pendingSocialDM = (channel, coachId, coachName)`, then open the profile URL (existing `CommunicationButton`/`openURL`).
2. When the app returns to foreground — `@Environment(\.scenePhase)` transitions to `.active` **and** `pendingSocialDM != nil` — present a confirmation dialog:
   - Title/message: "Did you send {name} a DM on {Twitter|Instagram}?"
   - **Yes** → `interactionsService.createInteraction(type: .twitter|.instagram, direction: .outbound, coachId:, occurredAt: .now, ...)`, then reload details so insights/days-since update. Clear pending.
   - **No / Cancel** → clear pending, no write.
3. Single pending (last tap wins). Cleared after resolve. A tap that never leaves the app (URL open fails) does not arm the prompt.

Rationale: avoids logging DMs the user never actually sent; a confirm on return is the natural iOS moment. Documented as intentional parity delta (§9).

## 7. New / changed files

**New components:** `SectionCard`, `CoachDirectChannelsGrid`, `CoachAlertsSection`, `CoachAnalyticsCard`, `CoachTagsCard`, `CoachProfileMetaCard`, `CoachInsights` (model), tags chip input (form). New color tokens `Brand.sky500`, `Brand.fuchsia500`.
**Changed:** `Coach`, `EditableCoach`, `CoachFormState`, `CoachCreateRequest`, `CoachUpdateRequest`, `CoachDetailView` (recomposed), `CoachDetailHeader` (rebuilt toolbar), `CoachDetailViewModel` (insights + pendingSocialDM + tags write + createInteraction), `CoachStatsGrid` (restyled), `CoachEditForm` + `AddCoachView`/`CoachFormView` (tags + source inputs).

## 8. Testing

- `CoachInsights` unit tests: overdue boundary (14 not overdue, 15 overdue), preferred-channel mode + tie, response-rate rounding, sent/received split, empty-interactions nils, days-since (from-interaction / fallback / nil-occurredAt — carried from PR #62).
- Tags validation: caps (>20 rejected, >40-char trimmed/rejected, empties dropped), source >80 rejected.
- ViewModel: `pendingSocialDM` set on tap arm; resolve-Yes calls `createInteraction` with correct type/direction/coach; resolve-No writes nothing; both clear pending.
- Existing coach-detail/component/accessibility tests updated for the recomposed view + new model fields.
- Build `xcodebuild build` EXIT 0; affected classes green; SwiftLint clean (`--config .swiftlint.yml`).

## 9. Known parity deltas (intentional, documented)

1. **Social-DM logging:** iOS confirms on return (§6); web fires-on-open. Deliberate — better UX, avoids false logs.
2. **Analytics gauge + stat-card rings:** iOS builds the fuller Figma visual; web deferred them (web §6.1/§6.2). Rings/gauge are decorative or simple-derived (responseRate), not proportional-target math.
3. **Edit/Delete in header:** iOS surfaces edit/delete as header buttons (matches frame); web keeps them elsewhere.

## 10. Out of scope (deferred both platforms)

Avatar photo upload; tag taxonomy/autocomplete; average-response-time metric; iPad two-pane split (portrait single-column only).

# iOS Spec — Coach Tile + Detail Consolidation

> **Prepared:** 2026-08-15
> **Web branch:** `develop` (merges `feat/coach-tile-unification` + `feat/coach-detail-consolidation`, both shipped + browser-verified)
> **Purpose:** Bring iOS coach tiles to parity with the web's single variant-driven `CoachCard` — one tile component, canonical 5-icon action row, no delete on any tile, and whole-tile tap to a single coach detail screen from every entry point.

> **Nature of this spec:** This is a **DELTA** spec, not a from-scratch build. iOS already has all the pieces (`CoachCardView`, `CompactCoachCard`, `SchoolCoachesPanel`, a single `CoachDetailView`, `CommunicationButton`/`CommunicationType`). The work is reconciling two divergent tile renderings into one and correcting the action-icon set/colors. Do not rebuild the coaches feature.

---

## Feature Overview

A coach appears as a tile in two places: the global Coaches directory (and the per-school "Manage Coaches" list) and the school-detail screen's coaches panel. The web now renders both from a **single** `CoachCard` component driven by a `variant` (`compact` | `full`) and a `showSchoolMeta` flag. Tapping anywhere on a tile opens the coach detail screen; the small action icons on the tile fire their own action (email/text/call/open-profile) without navigating. Deleting a coach is possible **only** on the detail screen — no tile has a delete affordance.

---

## Web Implementation Summary (source of truth)

### Files
- `components/Coach/CoachCard.vue` — the unified tile. Props: `variant` (`compact`|`full`, default `full`), `showSchoolMeta` (bool, default `false`), `school?`, `contactMode` (`native`|`modal`, default `native`), `detailTo?`, `backTo?`, `backLabel?`.
- `components/Coach/CoachCardActions.vue` — the action-icon row (the canonical 5 icons).
- Detail route `/coaches/:id` — single detail screen for all entry points; accepts `?back=<path>&label=<text>` for context-aware back-nav.

### Web contract (exact)

**Tile layout**
- **`compact`** (school-detail sidebar): name + role badge + action-icon row **only**. No logo, no school name, no contact text rows, no last-contact line. Padding `p-3`.
- **`full` + `showSchoolMeta: true`** (global directory — cross-school): school logo + name + school name + role badge, contact rows (email/phone as text), action-icon row, "Last contact: …" line. Padding `p-4`.
- **`full` + `showSchoolMeta: false`** (per-school "Manage Coaches" — same-school context): identical to above **but logo and school name are hidden** (redundant when every coach belongs to the school you're already viewing).
- **No delete affordance on ANY tile.** Delete lives only on the detail screen.
- The **whole tile is a link** to `/coaches/:id` (a `NuxtLink` wrapping everything).

**Action-icon row** (`CoachCardActions.vue`) — fixed order, each icon renders **only when its data field is present**:

| # | Action | Icon | Color (web token) | Shows when | Behavior |
|---|--------|------|-------------------|-----------|----------|
| 1 | Email | envelope | `brand-blue-600` | `coach.email` | `native`: `mailto:` · `modal`: emit open-communication |
| 2 | Text/SMS | chat-bubble-left | `brand-emerald-600` | `coach.phone` | `native`: `sms:` · `modal`: emit open-communication |
| 3 | Call | phone | `brand-purple-600` | `coach.phone` | **always** `tel:` (never modal) |
| 4 | X / Twitter | X glyph (custom SVG) | `brand-slate-700` | `coach.twitter_handle` | open `x.com` profile |
| 5 | Instagram | IG glyph (custom SVG) | `brand-pink-500` | `coach.instagram_handle` | open `instagram.com` profile |

- Each action button uses `@click.stop.prevent` so tapping an icon does **not** trigger the tile's navigation.
- `contactMode: "modal"` swaps Email + Text to emit `open-communication` (opens the in-app compose flow with templates) instead of the OS handler. Call is always native `tel:`.

### DB/Migration Changes
None. This is a pure UI/navigation consolidation — no schema, API, or model changes on the server.

---

## Existing iOS Files (what's there today — VERIFIED)

Main tree: `.../recruiting-compass-ios/TheRecruitingCompass/TheRecruitingCompass/`

| File | Role today | Fate |
|------|-----------|------|
| `Features/Coaches/Components/CoachCardView.swift` | Directory / manage tile (full layout) | **Keep + modify** → becomes the single variant-driven tile |
| `Features/Schools/Components/CompactCoachCard.swift` | School-sidebar tile (separate impl) | **Delete** → replaced by `CoachCardView(variant: .compact)` |
| `Features/Schools/Components/SchoolCoachesPanel.swift` | Renders `CompactCoachCard` list + "See All" | **Modify** → render unified tile, add per-coach nav to detail |
| `Features/Coaches/Views/CoachDetailView.swift` | Single coach detail screen | **Keep** — confirm it owns delete |
| `Features/Coaches/Views/CoachesListView.swift` | Directory list; wraps tile in `NavigationLink` to detail | **Modify** → drop tile-level delete plumbing |
| `Features/Coaches/Components/CommunicationType.swift` | Icon/color/URL model for the 5 action types | **Modify** → fix Call + X colors, kill camera fallback |
| `Features/Coaches/Components/CommunicationButton.swift` | Renders one action icon | Keep as-is |
| `Features/Dashboard/Models/Coach.swift` | `Coach` model + `contact*` nonBlank accessors | Keep as-is |

**Confirmed divergences from the web contract** (these are the actual work items):

1. **Two components, not one.** `CoachCardView` (full) and `CompactCoachCard` (compact) are independent implementations with drifting behavior.
2. **`CoachCardView` shows a delete (trash) button** via `onDelete`, and `CoachesListView` wires `confirmDelete` + a confirmation dialog + a "Quick Communication" context menu. **Web has no tile delete.**
3. **Action-icon set differs between the two tiles:**
   - `CoachCardView` renders: Email, Text, Twitter, Instagram — **missing Call**.
   - `CompactCoachCard` renders: Email, Text, Call, Twitter, Instagram — full set, correct order.
4. **Colors wrong vs canonical:** in `CommunicationType`, `.call` is `.successGreen` (should be **purple**) and `.twitter` is `#1DA1F2` twitter-blue (should be **slate**). `.instagram` is `#E4405F` (≈ pink — verify against brand-pink token).
5. **Camera glyph:** `CommunicationType.instagram.iconName == "camera.fill"` — this is a **dead fallback**; `CommunicationButton` always prefers `brandAssetName` (`"LogoInstagram"`), so the IG brand mark actually renders. Not user-visible today, but remove the `camera.fill` fallback to match the "drop the camera glyph" directive and avoid confusion.
6. **Compact shows too much:** `CompactCoachCard` renders a **last-contact row** and an inline `"Name – Role"` text instead of a role **badge**. Web compact shows name + role **badge** + icons only.
7. **`CoachCardView` always shows logo + school name** with no way to hide them — there is no `showSchoolMeta` equivalent for the per-school manage context.
8. **Compact tile is not tappable to detail:** in `SchoolCoachesPanel`, `CompactCoachCard` is not wrapped in any navigation; only "See All" navigates (to the filtered list). Web compact tiles tap through to the coach detail.

---

## What iOS Needs to Build (the delta)

### 1. Unify into one variant-driven tile (`CoachCardView`)

Add a variant + meta flag to `CoachCardView` and make it cover both layouts:

```swift
enum CoachCardVariant { case compact, full }

struct CoachCardView: View {
  let coach: Coach
  var variant: CoachCardVariant = .full
  var showSchoolMeta: Bool = false        // only meaningful for .full
  // school meta (only read when showSchoolMeta && variant == .full)
  var schoolName: String = ""
  var schoolLogoUrl: String? = nil
  var schoolInitials: String = ""
  var onQuickCommunication: ((QuickCommunicationContext) -> Void)? = nil
  // NOTE: no onDelete — removed (see item 2)
}
```

Rendering rules (mirror the web contract exactly):

- **`.compact`** — header shows **name + role badge only** (no logo, no school name). Then the action-icon row. **No** contact text rows, **no** last-contact line. Tighter padding.
- **`.full`, `showSchoolMeta == true`** — logo + name + school name + role badge, contact text rows (email/phone), action row, "Last contact: …" line.
- **`.full`, `showSchoolMeta == false`** — same as above but **omit the logo and the school-name subtitle**.

Then **delete `CompactCoachCard.swift`** and repoint `SchoolCoachesPanel` at `CoachCardView(variant: .compact)`.

Standardize on the `Coach.contact*` accessors (`contactEmail`, `contactPhone`, `contactTwitter`, `contactInstagram`) everywhere — they collapse blank/whitespace strings to nil. `CompactCoachCard` currently reads raw `coach.email`/`coach.phone`/etc., which would render an icon for an empty-string field.

### 2. Remove the delete affordance from the tile

- Delete `CoachCardDeleteButton` and the `onDelete` parameter from `CoachCardView` / `CoachCardActionsSection`.
- In `CoachesListView`: remove `onDelete:` wiring, `confirmDelete`, the delete confirmation dialog, and the delete error alert **from the list** (they belong on detail). Also reconsider the tile `contextMenu` "Quick Communication" — web has no such tile context menu; keep only if you want it as an iOS affordance, but it is not required for parity.
- **Verify** `CoachDetailView` already provides delete (grep shows `CoachDetailViewModel` + delete tests exist). If detail delete is missing, that is a gap to fill — confirm before removing the list-level delete so the capability isn't lost.

### 3. Fix the action-icon row (canonical 5, correct order + colors)

In `CommunicationType.swift`:

| Type | `iconColor` today | Change to (canonical) |
|------|-------------------|-----------------------|
| `.email` | `.accentBlue` | keep (blue) ✓ |
| `.phone` (Text) | `.successGreen` | keep (emerald/green) ✓ |
| `.call` | `.successGreen` | **purple** (match `brand-purple-600`) |
| `.twitter` | `Color(hex: "1DA1F2")` | **slate** (match `brand-slate-700`) |
| `.instagram` | `Color(hex: "E4405F")` | **pink** — verify against the brand pink token (`brand-pink-500`) and align |

- Remove the `.instagram` `iconName` `"camera.fill"` dead fallback (the `LogoInstagram` brand asset already renders). X uses `LogoX` brand asset — keep, just retint to slate.
- In the **unified** `CoachCardView`, render the icons in the fixed order **Email → Text → Call → X → Instagram**, each gated on the matching `contact*` field. This adds the **Call** button that `CoachCardView` is missing today (compact already had it).
- Preserve the existing two behaviors: when `onQuickCommunication` is set, Email + Text open the Quick Communication sheet (web `contactMode: "modal"`); otherwise they use the OS handler via `CommunicationButton` (web `native`). **Call is always native `tel:`** — never route Call through Quick Communication.

### 4. Make the compact (school-sidebar) tile tap through to detail

In `SchoolCoachesPanel` (rendered by `SchoolDetailView`), wrap each unified compact tile so the whole tile pushes the coach detail:

```swift
NavigationLink(value: CoachDestination.detail(coach.id)) {
  CoachCardView(coach: coach, variant: .compact)
}
.buttonStyle(.plain)
```

This requires the **school detail's `NavigationStack`** to register `.navigationDestination(for: CoachDestination.self) { CoachDetailView(...) }`. Verify whether `SchoolDetailView` already has this destination; if not, add it (it will need `allCoaches` / `allSchools`, or a detail initializer that fetches by id). The directory list (`CoachesListView`) already does this correctly — mirror that pattern.

### 5. Verify icon taps don't also trigger navigation (the web-only "button-in-anchor" concern)

Web guards every action button with `@click.stop.prevent` because the tile is an `<a>`. SwiftUI's equivalent: the action icons are `Button`s nested inside a `NavigationLink` label. In the directory list this already behaves (each `CommunicationButton` has its own `contentShape` + hit target and `buttonStyle(.plain)` on the link). **After wrapping the compact tile in a `NavigationLink`, test that tapping an action icon fires only that icon's action and does not also push the detail screen.** This is a SwiftUI hit-testing gotcha, not a data concern — verify by tapping, don't assume.

---

## Navigation & Back-Nav (mostly free on iOS)

- Web encodes context-aware back via `?back=…&label=…`. **iOS gets this for free** through `NavigationStack`: a push returns to its origin. Directory → detail → back = directory; school → detail → back = school. **No hardcoded back target exists in the iOS code** — no work needed beyond making the push happen from the school panel (item 4).
- One existing wrinkle to be aware of (not new work): the school's "Manage Coaches" path uses `CoachDestination.filteredBySchool` → a **nested** `CoachesListView` with its own `NavigationStack`. Back from a coach opened inside that filtered list returns to the filtered list, then to the school. That matches web behavior (manage list is an intermediate screen). Leave as-is unless the coordinator wants the manage list to open detail without the extra stack.

---

## Data Models (Swift)

No model changes. The existing `Coach` struct (`Features/Dashboard/Models/Coach.swift`) already exposes everything the unified tile needs:

```swift
struct Coach: Codable, Identifiable, Sendable {
  let id, firstName, lastName, schoolId, createdAt, updatedAt: String
  let email, phone, position, twitterHandle, instagramHandle, notes: String?
  let lastContactDate, nextContactDate: String?
  // ...
  var fullName: String
  var role: CoachRole                 // from `position`, defaults .assistant
  var contactEmail, contactPhone, contactTwitter, contactInstagram: String?  // nonBlank-trimmed
  var lastContactDateParsed: Date?
}
```

Use `contact*` accessors for icon gating; use `role` (→ `CoachRole.displayName` + `badgeColor`) for the badge.

---

## Business Rules to Enforce Client-Side

- **Icon visibility:** render each action icon **only** when its backing field is non-blank (`contactEmail` → Email; `contactPhone` → Text **and** Call; `contactTwitter` → X; `contactInstagram` → Instagram). Order is fixed: Email, Text, Call, X, Instagram.
- **No delete on tiles.** Delete is a detail-screen-only action.
- **Compact tile content is minimal:** name + role badge + icons only. No last-contact, no contact text rows, no logo/school name.
- **`showSchoolMeta` gates logo + school name** on full tiles (true in the cross-school directory, false in the same-school manage list).
- **Call is always the OS dialer** (`tel:`), even when the Quick Communication modal path is active for Email/Text.

---

## Excluded Items (No iOS Work Needed)

- **DB migrations / API / RLS** — none; pure client consolidation.
- **`?back=&label=` query plumbing** — web-only; iOS uses `NavigationStack` back behavior.
- **`@click.stop.prevent`** — web-only anchor concern; iOS handles via nested `Button` hit-testing (but verify per item 5).
- **Email sending / templates backend** — unchanged; Quick Communication already exists on iOS.

---

## Dependencies

- `CoachDetailView` + `CoachDetailViewModel` — must exist and **own the delete action** (they do; confirm delete is reachable there before removing the list-level delete).
- `CoachDestination` enum with a `.detail(coachId)` case — exists, used by `CoachesListView`.
- `QuickCommunicationView` / `QuickCommunicationContext` — exists; the `.modal` contact behavior maps to it.
- `CoachRole.displayName` + `badgeColor`, and the `LogoX` / `LogoInstagram` brand assets — all present.

---

## Notes for iOS Claude

- **Web/iOS parity principle** (from project memory): same data + functionality on both platforms **wherever the iOS models support it**. They do here — this is a UI reconciliation, nothing is blocked by a missing field.
- The cleanest approach is to make `CoachCardView` the single source and **delete `CompactCoachCard`** rather than keep two files in sync. Update `CompactCoachCard`'s tests (`CoachCardViewTests`, `CoachCardAccessibilityTests`, plus any `CompactCoachCard` previews/tests) to target the unified component + `.compact` variant.
- `CommunicationType.instagram.iconName = "camera.fill"` is the "camera glyph" referenced in the brief — it's already shadowed by the brand asset, so this is a cleanup, not a visible bug. Remove it while you're in the file.
- Double-check the brand **purple**, **slate**, and **pink** color tokens the iOS design system exposes (the web uses `brand-purple-600`, `brand-slate-700`, `brand-pink-500`). Use the existing iOS brand color extensions rather than raw hex where one exists.
- Keep the 44×44 minimum hit targets already present on `CommunicationButton` — don't shrink them for the compact layout.

---

## Test Checklist

1. **Directory tile (full, cross-school):** open Coaches list → each tile shows logo + name + school name + role badge + contact rows + Email/Text/Call/X/Instagram (only for present fields) + last-contact. No trash icon anywhere.
2. **Per-school manage tile (full, same-school):** open a school → Manage Coaches → tiles show name + role badge + contact rows + icons + last-contact, but **no logo and no school-name subtitle**.
3. **School-sidebar tile (compact):** open a school detail → coaches panel tiles show name + role badge + icons **only** (no logo, no last-contact, no contact text). Tap a tile → coach detail opens; Back returns to the **school**.
4. **Icon actions:** tap Email → Mail/compose; Text → Messages/compose; Call → dialer (`tel:`); X → x.com profile; Instagram → instagram.com profile. None of these also navigates to the detail screen.
5. **Icon gating:** a coach with only an email shows just the Email icon; a coach with a phone shows both Text and Call; a coach with no socials shows no X/IG icons.
6. **Colors:** Email blue, Text green, Call purple, X slate, Instagram pink — no more green Call or blue X, no camera glyph.
7. **Delete:** confirm there is **no** delete affordance on any tile (directory, manage, or sidebar); delete is reachable only inside `CoachDetailView` and still works.
8. **Directory back-nav:** open a coach from the directory → Back returns to the directory list (with filters intact).

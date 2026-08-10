# iOS Public Profile — Design Spec

**Date:** 2026-08-10
**Feature:** Bring the web app's "Public Profile" tab to iOS at full parity.
**Repo:** recruiting-compass-ios

---

## 1. Goal

Web has a **Public Profile** tab on player-details (`/settings/player-details`) that lets an
athlete configure and share a public recruiting card coaches view at
`myrecruitingcompass.com/p/<slug>`. iOS has none of it. Add it as a **5th segment** on the iOS
Player Profile screen, at **full parity**:

1. **Editor** — publish toggle, share-link copy, vanity slug, bio, header color, 4 section toggles.
2. **Native SwiftUI preview card** — the "what coaches see" card, rendered natively.
3. **Send Profile** — per-coach tracking link, launched from the iOS coach detail screen.

**Out of scope (v1):** view-count analytics UI (data still collected server-side); iOS does **not**
render the coach-facing `/p/<slug>` page — that stays web-only.

---

## 2. Key Decisions (locked)

| Decision | Choice | Why |
|---|---|---|
| Scope | Full parity (editor + card + tracking) | User directive |
| Data path | **Reuse web API** (`/api/player/profile`, tracking-links) | Public profile is web-owned end-to-end; keeps slug reserved/unique validation single-source; matches Action Items precedent |
| Preview card | **Native SwiftUI** rebuild of `PublicProfileCard` | Native feel, honors toggles live, works pre-publish |
| Placement | **5th segment "Public"** on `PlayerDetailsView` | Mirrors web tab placement |
| Film section | **Reuse existing iOS `VideoLinksService`** | iOS already has full video_links CRUD — no new code (gap dissolved) |
| Analytics UI | **Skip v1** | User directive |

---

## 3. Backend — already exists (no DB/API work)

All server-side infra is live in web + Supabase. iOS is a **second client**.

**Web API endpoints iOS consumes:**
- `GET /api/player/profile` → full `player_profiles` row (auto-creates on first access, generates `hash_slug`).
- `PUT /api/player/profile` → `{ success: true }`. Zod body, all optional:
  - `bio` string max 300, nullable
  - `is_published` bool
  - `show_academics` / `show_athletic` / `show_film` / `show_schools` bool
  - `header_color` enum `slate|blue|emerald|violet|rose|amber|teal|indigo`
  - `vanity_slug` string `^[a-z0-9][a-z0-9-]{0,28}[a-z0-9]$` nullable (empty → clears to null)
  - Errors: **422** invalid/reserved slug, **409** slug taken, **403** not family member.
  - Reserved slugs: `api, p, auth, login, signup, join, admin, settings, dashboard, coaches, schools, help`.
- `GET /api/player/profile/tracking-links/{coachId}` → `ProfileTrackingLink` or `null`.
- `POST /api/player/profile/tracking-links/{coachId}` → existing-or-created `ProfileTrackingLink`.
  `ref_token` = `[a-z0-9]{8}`. **No URL returned** — client builds `…/p/<slug>?ref=<ref_token>`.
  Errors: 403 not member, 404 no profile.

**CSRF:** mutating web-API calls (PUT/POST) require the same CSRF dance the Suggestions
mutations use — `GET /api/csrf-token`, read `csrf-token` cookie from
`HTTPCookieStorage.shared.cookies(for: baseURL/api)`, send as `x-csrf-token` header. Reads (GET)
do not.

**Auth:** `Authorization: Bearer <authManager.session?.accessToken>`. On 401 →
`authManager.refreshSession()` → retry once (copy Suggestions pattern).

**`API_BASE_URL` unset:** degrade gracefully like Suggestions — editor shows
"Set up your public profile on the web" and disables controls. `SupabaseConfig.apiBaseURL` is
`URL?` (nil in DEBUG when unset; prod fallback `https://myrecruitingcompass.com`).

---

## 4. Models (Swift Codable — mirror web `types/models.ts`)

New file `Features/PublicProfile/Models/PlayerProfile.swift`:

```swift
struct PlayerProfile: Codable, Equatable, Sendable {
    let id: String
    let userId: String
    let familyUnitId: String
    let hashSlug: String
    var vanitySlug: String?
    var isPublished: Bool
    var bio: String?
    var headerColor: String        // one of the 8 keys; default "slate"
    var showAcademics: Bool
    var showAthletic: Bool
    var showFilm: Bool
    var showSchools: Bool
    let createdAt: String
    let updatedAt: String
    // CodingKeys: snake_case → camelCase
}

struct ProfileTrackingLink: Codable, Equatable, Sendable {
    let id: String
    let profileId: String
    let coachId: String
    let refToken: String
    let viewCount: Int
    let lastViewedAt: String?
    let createdAt: String
}
```

**PUT payload** = a separate `UpdateProfilePayload: Encodable` with all-optional fields, so only
changed fields serialize (use explicit `encodeIfPresent`, or send the full known state — send full
state is simpler and matches web auto-save-on-blur semantics).

**Header colors** — static table `[(key, label, Color)]`, 8 entries mapping web Tailwind swatches:
`slate→slate-700, blue→blue-700, indigo→indigo-700, violet→violet-700, rose→rose-700,
amber→amber-600, emerald→emerald-700, teal→teal-700`. Approximate with `AppColors` or literal
hex; default `slate`.

`PublicProfileData` (the assembled card VM input) is **built locally on iOS** from existing
services — it is NOT fetched. See §6.

---

## 5. Service layer

New `Features/PublicProfile/Services/`:

```swift
protocol PublicProfileManaging: Sendable {
    func fetchProfile(accessToken: String?) async throws -> PlayerProfile?
    func updateProfile(_ payload: UpdateProfilePayload, accessToken: String?) async throws
    func fetchTrackingLink(coachId: String, accessToken: String?) async throws -> ProfileTrackingLink?
    func createTrackingLink(coachId: String, accessToken: String?) async throws -> ProfileTrackingLink
}
```

`PublicProfileServiceImpl` — copy the `DashboardServiceImpl` web-API structure verbatim:
guard `apiBaseURL` + token → nil/no-op when unconfigured; Bearer header; JSON decode; CSRF for
PUT/POST; typed error enum `PublicProfileAPIError { case unauthorized, slugTaken, slugInvalid,
notMember, notConfigured }` mapped from 401/409/422/403.

`MockPublicProfileManaging` for tests.

---

## 6. Native preview card — data assembly

`PublicProfileCard` (SwiftUI) takes a `PublicProfileData` VM built from data iOS **already reads**,
scoped to `effectiveUserId` (supports family-member `targetUserId`):

| Card section | Source (existing iOS) | Gate |
|---|---|---|
| Header (name, photo, sport, bio) | name via `users.full_name`, photo via `ProfilePhotoService.currentPhotoURL(userId:)`, sport/position + bio | always; bio from profile config |
| Athletic (positions, height, weight, NCAA/PG/PBR IDs) | `PreferenceService.fetchPreferences(.player, userId:)` → `PlayerDetails` | `showAthletic` |
| Academics (GPA, grad year, SAT/ACT, HS, core courses) | same `PlayerDetails` | `showAcademics` |
| Film (video links) | `VideoLinksService.fetchVideoLinks(userId:)` | `showFilm` |
| Schools (target list) | `SchoolsService.fetchSchools(familyUnitId:)` | `showSchools` |

Toggling a `show_*` switch flips section visibility **live** in the preview without a round-trip.
Card layout mirrors web `PublicProfileCard.vue`: gradient header (from `headerColor`), then the
conditional sections, then a "powered by The Recruiting Compass" footer.

---

## 7. UI — three surfaces

### 7a. Tab wiring (`PlayerDetailsView.swift`)
- Add `String(localized: "Public")` as 5th element (index 4) of `tabTitles`.
- Add `case 4: PublicTab(viewModel: viewModel)` to the `tabContent` switch.
- Picker is data-driven by `tabTitles.enumerated()` — no other Picker changes.
- **Visual check:** 5 segments may crowd on small devices. If cramped, fall back to a compact
  title style or scrollable segment; confirm on iPhone SE-class width during build.

### 7b. `PublicTab` (editor + preview, vertical stack)
Top → editor controls; below → live `PublicProfileCard`. Editor controls (each auto-saves on
commit/toggle via PUT, debounced for text):
- **Publish toggle** (`is_published`) — label "Profile is live / unpublished".
- **Share link** — read-only display of `origin + /p/<vanitySlug ?? hashSlug>` + Copy button
  (`UIPasteboard`). Only meaningful once published; show hint when unpublished.
- **Vanity slug** — text field, client-validate regex for instant feedback; server is authority →
  surface 409 "taken" / 422 "invalid or reserved" inline. Empty clears to null.
- **Bio** — `TextEditor`, 300-char cap + counter.
- **Header color** — 8-swatch picker.
- **Section toggles** — 4 switches "What to show coaches".
- **Unconfigured state** (`apiBaseURL == nil`) — disable controls, show web-setup message.

### 7c. Send Profile (coach detail screen)
Parity with web's `CoachProfileLink`. Add a "Send Profile" action on the iOS coach detail view:
POST tracking-link for that coach → build `…/p/<slug>?ref=<refToken>` → system share sheet
(`ShareLink` / `UIActivityViewController`). Requires a published profile; if none/unpublished,
prompt to publish first.

---

## 8. ViewModel

`PublicProfileViewModel` (`@Observable @MainActor`, `nonisolated deinit {}`):
- Loads `PlayerProfile` on appear (fetchProfile); holds editor state.
- `save()` debounced; maps API errors to inline field messages; 401→refresh→retry once.
- Assembles `PublicProfileData` from the 4 existing services (§6) for the card.
- Exposes `shareURL: URL?` computed from slug.
- Send-Profile logic may live here or in the coach-detail VM; keep tracking-link calls in the
  service either way.

Placement note: the file/feature lives under a new `Features/PublicProfile/` module; `PublicTab`
receives the shared `PlayerDetailsViewModel` for `effectiveUserId`/`targetUserId` context but owns
a `PublicProfileViewModel` for public-profile state (don't bloat `PlayerDetailsViewModel`).

---

## 9. Testing

- `PublicProfileViewModelTests` — load, edit slug (valid/invalid/taken mapping), toggle save,
  publish, unconfigured degrade, 401-refresh-retry.
- `PublicProfileServiceImplTests` — URL/Bearer/CSRF construction, error-code → enum mapping,
  nil-on-unconfigured (mock URLProtocol).
- `PublicProfileCard` view tests — section gating honors `show_*`.
- Mock: `MockPublicProfileManaging`.
- **macOS 26 rule:** `nonisolated deinit {}` on every new `@MainActor` class (VM + any
  `@MainActor` test class).
- Build gate: `xcodebuild build` clean before done.

---

## 10. File plan (new `Features/PublicProfile/`)

```
Features/PublicProfile/
├── Models/
│   ├── PlayerProfile.swift            (PlayerProfile, ProfileTrackingLink, UpdateProfilePayload)
│   ├── PublicProfileData.swift        (card VM input)
│   └── HeaderColor.swift              (8-preset table)
├── Services/
│   ├── PublicProfileManaging.swift
│   ├── PublicProfileServiceImpl.swift
│   └── MockPublicProfileManaging.swift
├── ViewModels/
│   └── PublicProfileViewModel.swift
├── Views/
│   ├── PublicTab.swift                (editor + preview)
│   └── PublicProfileCard.swift        (native card)
└── Components/                        (swatch picker, share-link row, section rows as needed)
```
Edits: `PlayerDetailsView.swift` (tab wiring), iOS coach detail view (Send Profile action).

---

## 11. Open items / risks

- **5-segment crowding** — verify on narrow width; fallback plan in 7a.
- **CSRF cookie lifetime** — reuse Suggestions' `fetchCSRFToken`; confirm cookie domain matches
  `apiBaseURL`.
- **Slug uniqueness race** — server is authority; iOS only mirrors regex for UX. Always trust
  409/422 over client validation.
- **`family_unit_id` for schools/tracking** — confirm the iOS source for the athlete's
  `familyUnitId` at the `PublicTab` call site (same one PlayerDetails/Schools already use).
- **Header color fidelity** — Tailwind `-700` swatches → pick closest SwiftUI Color/hex; exact
  match not required, family recognizable.

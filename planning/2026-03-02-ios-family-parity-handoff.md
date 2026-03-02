# iOS Family Parity Handoff

**Date:** 2026-03-02  
**From:** Web app (Claude)  
**To:** iOS implementation

This document captures schema changes (already live), API contracts, user flows, and implementation checklist for iOS family/invite parity with the web app.

---

## 1. Schema changes (already live)

- **family_units**
  - `player_user_id` → **removed**
  - `created_by_user_id` → **added** (audit only; iOS already uses this in `FamilyUnit`)
  - `pending_player_details` → **added** (JSONB); parent pre-enters player info before sending invite

- **family_invitations**
  - Full table spec with all columns
  - Invite expiry: **7 days → 30 days**
  - `declined_at` → **added** (timestamp when invite was declined)

- **users**
  - `date_of_birth` → **added** (for COPPA age gate on signup/invite accept)

---

## 2. API endpoints (request/response shapes)

Base URL: `API_BASE_URL` (e.g. Vercel app). Auth where noted = `Authorization: Bearer <access_token>`.

| # | Method | Path | Auth | Purpose |
|---|--------|------|------|---------|
| 1 | POST | `/api/family/create` | Yes | Create family (both roles); returns `familyCode`, `familyId`, `familyName?` |
| 2 | GET | (Supabase) family_units + family_members | Yes | Fetch family for user / members |
| 3 | POST | `/api/family/code/join` | Yes | Join family by code (parent) |
| 4 | POST | `/api/family/code/regenerate` | Yes | Regenerate family code |
| 5 | POST | `/api/family/invite` | Yes | Send email invite; body `{ email, role }`; optional `pendingPlayerDetails` for player role |
| 6 | GET | `/api/family/invite/:token` | **No** | Lookup invite by token; returns `InviteDetails` (email, role, familyName, inviterName, emailExists, prefill?) |
| 7 | POST | `/api/family/invite/:token/accept` | Yes | Accept invite (after login/signup if needed) |
| 8 | POST | `/api/family/invite/:token/decline` | **No** | Decline invite (no auth required) |
| 9 | GET | `/api/family/invitations` | Yes | List pending invitations for current user's family |
| 10 | DELETE | `/api/family/invitations/:id` | Yes | Revoke invitation |
| 11 | (various) | List/remove members | Yes | List family members; remove member (e.g. Edge Function or API) |
| 12 | POST | Save player details | Yes | Save parent-entered player details to `pending_player_details` (or to user after accept) |

**Response shapes (representative):**

- **InviteDetails** (GET invite/:token):  
  `invitationId`, `email`, `role`, `familyName`, `inviterName`, `emailExists` (bool), `prefill?` (e.g. `firstName`, `lastName`, `sport?`, `position?`).
- **emailMismatch:** If API returns an `emailMismatch` flag, treat as **informational only** — accept still succeeds; show message if desired.

---

## 3. User flows

### 3.1 New account signup (both roles)

- User selects role (Player / Parent) then fills form.
- **Player:** optional family code (join existing family at signup).
- **Parent:** no code; after signup, create family and optionally go through parent onboarding (player details → invite).
- Both roles can create a family (POST create) if they don’t join one.

### 3.2 Parent onboarding wizard (2-step)

1. **Step 1 – Player details**  
   Parent enters player info (first name, last name, sport, position, grad year, etc.). Stored in `pending_player_details` on family_units or sent with invite.
2. **Step 2 – Invite**  
   Parent enters email, sends invite. Invite payload may include prefill from step 1.

### 3.3 Email invite recipient — 3-branch logic

- **Authenticated:** Show "Connect to [Family]" → accept (or decline).
- **Existing user (emailExists: true):** Show login form (email pre-filled, read-only) → login then accept (or decline).
- **New user (emailExists: false):** Show signup form (prefill first/last from `prefill` if present) → signup then accept (or decline).

### 3.4 Join by family code

- Parent enters code (format `FAM-XXXXXX`), submits.  
- Client-side validate with `FAM-[A-Z0-9]{6}` before submit.  
- POST `/api/family/code/join` (or equivalent).

### 3.5 Family management screen

- **Player:** Show family code, copy/share, regenerate, list members, remove member, pending invites (if any), send invite (e.g. to parent).
- **Parent:** Join family by code, invite player by email, list pending invites, list "My families" with codes.

### 3.6 Family code in profile dropdown

- In Settings (or profile), show family code when available; copy button. Link to Family Management.

---

## 4. Rules for iOS

- **Decline invite:** No auth required; do **not** send Bearer token on POST decline.
- **Invite token lookup:** No auth required; do **not** send Bearer token on GET invite/:token.
- **CSRF:** Skipped for mobile; no special header needed.
- **emailMismatch:** Informational only; accept still succeeds. Optionally show a short message.
- **Sport / position lists:** Replicate from web's parent flow (e.g. `parent.vue`) for parent onboarding and prefill.
- **Family code validation:** Use `FAM-[A-Z0-9]{6}` client-side before submit (already in `FamilyConstants.Validation.codePattern`).

---

## 5. Implementation checklist

### Current iOS status (as of 2026-03-02)

- **FamilyUnit:** Already uses `createdByUserId` only; no `player_user_id`.
- **FamilyInvitation:** Has `expiresAt`, `status`; no `declinedAt` yet. Expiry copy may still say 7 days in UI.
- **InviteDetails / InvitePrefill:** Has `firstName`, `lastName`; no `sport`/`position` in prefill yet.
- **Decline:** Implemented without auth in `FamilyServiceImpl.declineInvite`.
- **Lookup:** Implemented without auth (plain URLSession).
- **Family code validation:** `FamilyConstants.Validation.codePattern` = `^FAM-[A-Z0-9]{6}$`.
- **Signup:** Two-step role → form; create family after signup for both roles; optional family code for player.
- **InviteJoinView:** 3-branch (authenticated / login / signup) with prefill for first/last name.
- **Family Management:** Player and parent views; join by code, invite by email, pending list, my families.
- **Settings:** Family code + copy, link to Family Management.

### Models

- [x] **FamilyUnit** – Uses `created_by_user_id` only.
- [ ] **FamilyUnit** – Add `pendingPlayerDetails` (Codable) when iOS needs to read/write it.
- [ ] **FamilyInvitation** – Add `declinedAt`; update any "7 days" copy to "30 days".
- [ ] **InviteDetails / InvitePrefill** – Add optional `sport`, `position` (and any other prefill fields web sends).
- [ ] **User / signup** – Add `dateOfBirth` if COPPA age gate is implemented; align with web.

### Service layer

- [x] **FamilyManaging / FamilyServiceImpl** – create, join, regenerate, send invite, lookup (no auth), accept (auth), decline (no auth), list/revoke invitations, list/remove members.
- [ ] **Send invite** – If web supports `pendingPlayerDetails`, add parameter and send in POST body when role is player.
- [ ] **Save player details** – New endpoint or Supabase: save parent-entered player details to `pending_player_details` (or to user after accept); implement when product specifies.

### Views / screens

- [x] **Signup** – Two-step (role → form); optional family code for player; create family after signup for both roles.
- [ ] **Parent onboarding wizard** – 2-step: (1) Player details (sport, position, grad year, etc.), (2) Invite by email. Reuse sport/position lists from web.
- [x] **Invite deep link** – Load invite by token (no auth), then: authenticated → accept/decline; existing user → login then accept/decline; new user → signup then accept/decline. Prefill from `InviteDetails.prefill`.
- [x] **Join by family code** – Validate `FAM-[A-Z0-9]{6}`, then POST join (Family Management parent view).
- [x] **Family management** – Player and parent flows; display expiry (update copy to 30 days if needed).
- [x] **Settings / profile** – Family code + copy; link to Family Management.

### State / env

- [x] **FamilyManager** – Loads family unit, members; supports create/join/regenerate/invite/accept/decline/revoke.
- [ ] **Deep link** – Handle invite links (e.g. `/invite/:token`) to open InviteJoinView with token (if not already handled).

### Testing

- [ ] Unit tests for FamilyServiceImpl: create, join, lookup (no auth), accept (auth), decline (no auth), list/revoke.
- [ ] Invite flow: load details with prefill, signup then accept, login then accept, decline.
- [ ] Family code validation and join.
- [ ] Accessibility and E2E for critical paths (invite accept/decline, join by code, parent onboarding).

---

## 6. Reference

- **Web parent flow:** `parent.vue` (or equivalent) for sport/position lists and step order.
- **API base:** Set `API_BASE_URL` in scheme environment (or Release.xcconfig for archive). Required for invite send, lookup, accept, decline, list, revoke, join by code if using web API.

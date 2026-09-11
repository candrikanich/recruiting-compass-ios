# Spec — Guardian-Linked Signup (let players start, keep guardians in the loop)

**Date:** 2026-09-11
**Status:** Proposed — not yet implemented
**Scope:** `recruiting-compass-web`, `recruiting-compass-ios`, shared Supabase schema
**Replaces:** the hard under-18 signup block currently on web `develop`

---

## 1. Problem

A 13–17 player who finds the app cannot start using it. Web signup rejects them with:

> Players under 18 need a parent or guardian to invite them — please ask them to send a family invite instead of signing up here.

That screen offers no path forward — no "invite your parent" action, no email-a-guardian flow. The player is the one with the motivation, and we bounce them at the door and ask them to go recruit an adult. Most won't.

### Current state (verified, not assumed)

| Layer | Rule today | Where |
|---|---|---|
| Web `main` | Blocks **under-13** only | `pages/signup.vue:331` (`isUnderMinimumAge`) |
| Web `develop` | Blocks **under-13 and 13–17** | `pages/signup.vue:347` (`requiresGuardianInvite`) |
| iOS | Blocks **under-13** only | `SignupViewModel.swift:93,148,202` (`COPPAHelper.isUnderAge`) |
| DB trigger `trg_enforce_minimum_age` | Rejects player rows under 13 | `20260821000000_enforce_minimum_age.sql` |
| DB trigger `trg_enforce_minor_requires_invite` | Rejects 13–17 player rows with no family link | `20260822000000_minor_requires_family_invite.sql`, patched `20260925000020` |

Three things follow from this table:

1. **The under-18 block is not yet on `main`.** It lives on `develop`. We can change direction before it reaches production.
2. **iOS never implemented it.** `COPPAHelper.requiresGuardianInvite` exists but is called from zero production files — tests only. The two platforms already disagree, and the DB trigger is what actually enforces the rule on iOS: a minor signing up in the app gets an opaque `check_violation` rather than the web's guided message. **That is a live iOS bug today**, independent of this spec.
3. **The 18 rule is a product decision, not a legal floor.** COPPA is 13, and that is what `trg_enforce_minimum_age` encodes. Nothing in the legal review requires 18. The current copy calls it COPPA; that wording is inaccurate and should change regardless of which direction we go.

The gate has also already proven fragile: `20260925000020_fix_minor_invite_trigger_rls.sql` fixed a SECURITY INVOKER/RLS interaction where the trigger blocked **every** minor invite signup, including valid ones.

### What the gate actually buys

An invited 13–17 player receives their own email, own password, own full login (`InviteJoinViewModel.signupAndConnect`, web `pages/join.vue`). The gate does not constrain what a minor *does* in the app — only how the account got created. It is a one-time proof that a guardian knew, not an ongoing control.

That is worth keeping. It is not worth paying for with the entire self-serve funnel.

---

## 2. Decision

**Keep the requirement that a minor's account is linked to a consenting guardian. Change who is allowed to start it.**

The player may sign up on their own and name a guardian. The account is created immediately in a **`pending_guardian`** state with real but bounded capability. Outward-facing actions stay locked until the guardian claims the account and accepts Terms on the minor's behalf.

This preserves every compliance artifact we have today — `guardian_consent_at`, `guardian_consent_by`, `guardian_consent_terms_version` are still stamped by a real guardian, and enforcement stays at the DB layer where clients can't bypass it. It changes only the direction of the invitation.

Non-goals: no change for 18+ players, no change for parents, no change to the existing parent-initiated invite flow (it stays, unmodified, and remains the path we recommend in marketing).

---

## 3. The flow

### 3a. Player-initiated (new)

1. Player, 13–17, completes signup. The DOB picker reveals one additional required field: **parent/guardian email**, with copy explaining why.
2. On submit we create the `users` row **and** a `guardian_claims` row in one transaction. Account state: `pending_guardian`.
3. Player lands in the app immediately. Dashboard carries a persistent, non-dismissible banner: *"Waiting on <email> to confirm your account. Some features are locked until then."* with **Resend** and **Change email** actions.
4. Guardian receives an email: *"<Player> started a recruiting profile on Recruiting Compass. Confirm you're their parent or guardian to unlock it."*
5. Guardian clicks through → creates their own account (or signs in) → reviews the player's name/DOB/grad year → accepts Terms on the minor's behalf → confirms.
6. On confirm: a `family_unit` is created with the guardian as parent, the player is inserted as a `family_members` row, `guardian_consent_*` is stamped on the player, the claim is marked `claimed`, and every locked capability unlocks. Player gets a push/email: *"You're all set."*

### 3b. Parent-initiated (unchanged)

Existing flow via `FamilyInviteModal` → `family_invitations` → `pages/join.vue` / `InviteJoinView`. Untouched. A player who already has a pending invitation and signs up standalone with a matching email should be routed into the existing accept flow rather than creating a claim (see §7).

---

## 4. Capability gating

`pending_guardian` is not read-only. The player gets the entire planning surface — that is the part that makes them want a guardian to confirm.

| Capability | Pending | Rationale |
|---|---|---|
| Browse / search schools | ✅ | Core discovery value; no outbound exposure |
| Build target list, set status, fit scores | ✅ | The hook |
| Tasks, deadlines, calendar, notes | ✅ | Private planning |
| Performance / academic entry | ✅ | Own data |
| **Draft** coach emails | ✅ | Drafting is value; sending is the gated act |
| **Send** coach email / log outbound interaction | 🔒 | Minor → adult outbound contact |
| Public profile share / share links | 🔒 | Minor PII leaving the product |
| Document upload, video links | 🔒 | Data minimization pre-consent |
| Inbound draft send (`InboundDrafts`) | 🔒 | Outbound |
| Push notification registration | 🔒 | Defer until consented |
| Billing / subscription | 🔒 | Minors can't contract |

Locked surfaces show the same inline component everywhere: a lock glyph, one line of explanation, and a **Remind my guardian** button. Never a dead end — that is the whole point of this spec.

---

## 5. Data model

New migration, both a table and a trigger widening. **No change to `trg_enforce_minimum_age` — the 13 floor stands exactly as-is.**

```sql
-- supabase/migrations/2026XXXXXXXXXX_guardian_claims.sql

create table if not exists public.guardian_claims (
  id                uuid primary key default gen_random_uuid(),
  player_user_id    uuid not null references public.users(id) on delete cascade,
  guardian_email    text not null,
  token             text not null unique,
  status            text not null default 'pending'
                      check (status in ('pending','claimed','expired','revoked')),
  created_at        timestamptz not null default now(),
  expires_at        timestamptz not null default (now() + interval '45 days'),
  claimed_at        timestamptz,
  claimed_by        uuid references public.users(id),
  last_reminder_at  timestamptz,
  reminder_count    int not null default 0
);

create unique index if not exists idx_guardian_claims_active_player
  on public.guardian_claims (player_user_id) where status = 'pending';
create index if not exists idx_guardian_claims_guardian_email_lower
  on public.guardian_claims (lower(guardian_email));
```

Then widen `enforce_minor_requires_invite` with a third acceptance branch. Keep `security definer` + pinned `search_path` — the `20260925000020` fix is load-bearing and must survive.

```sql
-- ... existing two EXISTS branches (family_members, family_invitations) ...
   and not exists (
     -- Or: player-initiated guardian claim, still pending and unexpired
     select 1
     from public.guardian_claims gc
     where gc.player_user_id = new.id
       and gc.status = 'pending'
       and gc.expires_at > now()
   )
```

**Ordering problem to solve at implementation time:** the trigger fires `before insert` on `users`, so the `guardian_claims` row cannot exist yet on the player's very first insert. Two viable resolutions — pick one and note it in the PR:

- **(a) Server endpoint.** Move minor signup behind `POST /api/auth/signup-minor` running service-role, which inserts claim-then-user in a transaction. Cleanest, and it ends the "signup writes go browser → Supabase directly with no server endpoint" limitation that both existing migration comments call out as the reason enforcement had to live in a trigger. **Recommended.**
- **(b) Deferred constraint.** Let the insert through when a `pending_guardian` flag is set on the row, and enforce via a constraint trigger checked at transaction commit. Keeps the browser-direct path but is harder to reason about.

Option (a) also gives us one server-side place to rate-limit guardian-email sends, which (b) does not.

### Retention (this is the part that needs your sign-off)

An unclaimed minor account holds a minor's PII with no guardian consent on record. That is the real legal exposure this design creates, and it must be time-boxed:

| Day | Action |
|---|---|
| 0 | Claim email to guardian |
| 3, 7, 14 | Reminder to guardian; in-app nudge to player |
| 21 | Account frozen to read-only; banner escalates |
| 45 | Claim expires; account and all associated rows purged; final notice to both addresses |

Pre-claim we collect **only** what signup already collects — name, email, DOB, grad year, sport, guardian email. No documents, no video, no messaging. That is defensible data minimization: we need DOB to know they are a minor at all.

---

## 6. Web implementation (`recruiting-compass-web`)

| File | Change |
|---|---|
| `utils/age.ts` | Keep `requiresGuardianInvite` — semantics stay "needs a guardian link". Add `GUARDIAN_CLAIM_EXPIRY_DAYS`. |
| `pages/signup.vue:347` | **Remove the hard block.** Replace with: when `requiresGuardianInvite(dob)`, reveal the required guardian-email field and route submit to the minor endpoint. |
| `server/api/auth/signup-minor.post.ts` | **New.** Service-role: validate DOB ≥13, validate guardian email, create user + claim in one transaction, send claim email. Rate-limited. |
| `server/api/guardian/claim/[token].get.ts` | **New.** Resolve claim for the landing page. |
| `server/api/guardian/claim/[token]/accept.post.ts` | **New.** Guardian signup-or-signin, create `family_unit`, insert `family_members`, stamp `guardian_consent_*` with `CURRENT_TERMS_VERSION`, mark claim `claimed`. Mirror the strict email-binding already in `family/invite/[token]/accept.post.ts`. |
| `pages/guardian/claim/[token].vue` | **New.** Guardian-facing claim page. |
| `composables/useGuardianStatus.ts` | **New.** Exposes `isPendingGuardian` for gating. |
| `components/GuardianPendingBanner.vue` | **New.** Dashboard banner with Resend / Change email. |
| `components/GuardianLockedAction.vue` | **New.** The inline locked-capability component from §4. |
| `server/api/cron/guardian-claim-reminders.get.ts` | **New.** Drives the §5 retention table. Follow the existing cron pattern in `server/api/cron/`. |
| `pages/legal/privacy.vue`, `pages/legal/terms.vue` | Update minor-account language to describe player-initiated + guardian confirmation. |

Existing `server/api/family/invite/[token]/accept.post.ts` is unchanged.

## 7. iOS implementation (`recruiting-compass-ios`)

Per `.claude/skills/platform-parity`, iOS ships the same capability set, same copy, same states — in native containers.

| File | Change |
|---|---|
| `Core/Utilities/COPPAHelper.swift` | No logic change. `requiresGuardianInvite` finally gets a production caller. |
| `Features/Auth/ViewModels/SignupViewModel.swift` | Add `guardianEmail` + validation. Include in `isFormValid` only when `requiresGuardianInvite(dobString)`. Route minor signup to the new endpoint. |
| `Features/Auth/Views/SignupView.swift` | Conditionally reveal the guardian-email field when DOB lands in 13–17, with the same explanatory copy as web. |
| `Core/Models/AuthError.swift` | Add `guardianEmailRequired`, `guardianEmailInvalid`. **Also map the DB's `check_violation` "Players under 18 must join through..." to a readable error** — today it surfaces raw. |
| `Core/Services/AuthManager.swift:95` | Extend the age branch to carry guardian email for minors. |
| `Features/Family/Models/GuardianClaim.swift` | **New.** Model + status enum. |
| `Features/Family/ViewModels/GuardianStatusViewModel.swift` | **New.** `isPendingGuardian`, resend, change-email. |
| `Features/Dashboard/Components/GuardianPendingBanner.swift` | **New.** Mirror `ParentOnboardingBanner.swift`. |
| `Shared/Components/GuardianLockedAction.swift` | **New.** Parity with `GuardianLockedAction.vue`. |
| `Features/Interactions/`, `PublicProfile/`, `Documents/`, `VideoLinks/`, `InboundDrafts/` | Apply the §4 lock. |
| `Features/Legal/Views/PrivacyPolicyView.swift:295`, `TermsOfServiceView.swift` | Match web legal copy. |
| `Core/Utilities/DeepLinkHandler.swift`, `DeepLinkRoute.swift` | Add the guardian-claim deep link so the email opens the app when installed. |

**Reuse note:** `SubscriptionStatus.readOnly` in `Features/Entitlement/Models/FamilySubscription.swift` is an existing precedent for a restricted-capability state. Follow that pattern rather than inventing a parallel mechanism — ideally both feed one `AppCapability` resolver so we don't end up with two independent gates fighting each other.

---

## 8. Edge cases

| Case | Behavior |
|---|---|
| Player's guardian email already has an account | Skip signup in the claim flow; sign in and go straight to confirm |
| Guardian email matches the player's own email | Reject at validation, both platforms |
| Player already has a pending `family_invitations` row for their email | Route into the existing accept flow; do **not** create a claim |
| Player turns 18 while pending | Nightly job auto-resolves: claim → `revoked`, full capability. DOB is immutable post-signup, so this can't be gamed |
| Guardian declines | Claim → `revoked`, account frozen, player told to use a different guardian |
| Player changes guardian email | Old claim → `revoked`, new claim issued, expiry clock **does not** reset (prevents indefinite extension) |
| Two players name the same guardian | Supported — guardian claims both into one family unit |
| Claim token replayed after `claimed` | Reject; show "already confirmed" |
| DOB edited post-signup into 13–17 | Existing trigger already covers UPDATE; surface the guided message rather than a raw error |

---

## 9. Copy changes

Retire the COPPA framing from the 13–17 band. COPPA is the 13 floor only.

- **Signup, guardian-email field:** *"Because you're under 18, a parent or guardian needs to confirm your account. We'll email them — you can start setting things up right away."*
- **Pending banner:** *"Waiting on <email> to confirm your account. You can build your school list now; sending messages to coaches unlocks once they confirm."*
- **Locked action:** *"Your guardian needs to confirm your account before you can send messages to coaches."* + **Remind my guardian**
- **Guardian email subject:** *"<Player> started a recruiting profile — confirm you're their parent or guardian"*

---

## 10. Test plan

**Shared/DB** — trigger accepts: 18+ solo, invited minor, minor with pending claim. Trigger rejects: minor with no link, minor with expired claim, minor with revoked claim. Under-13 still rejected on every path. **Regression: the `20260925000020` RLS case — a valid invited minor must still pass.**

**Web** — unit: `utils/age.ts` unchanged behavior, guardian-email validation. Integration: all three new endpoints incl. token replay + rate limiting. E2E: minor signs up → banner → locked action → guardian claims → unlocks.

**iOS** — unit: `SignupViewModelTests` for conditional guardian-email requirement; `AuthErrorTests` for the new cases incl. `check_violation` mapping. `COPPAHelperTests` already covers the band and needs no change. UI: `SignupE2ETests` minor path; accessibility pass on banner + locked component per the repo's WCAG AA bar.

**Parity checklist** (from `.claude/skills/platform-parity`) — locked-capability set identical; banner copy identical; guardian-email validation identical; same states in the same order. Build gate: `npx tsc --noEmit` (web), `xcodebuild build -quiet` (iOS).

---

## 11. Phasing

| Phase | Contents | Ships value |
|---|---|---|
| **0** | Fix the live iOS bug: map the DB `check_violation` to a readable message | Immediately — independent of the rest |
| **1** | Migration + `signup-minor` endpoint + trigger widening | Nothing user-visible |
| **2** | Web signup + claim flow + banner + locks | Web minors unblocked |
| **3** | iOS parity | Both platforms aligned |
| **4** | Reminder cron + retention/purge | Compliance complete |

Phase 4 is not optional — do not leave phases 2–3 in production without it, or we accumulate unclaimed minor PII with no consent record and no expiry.

Recommend holding the `develop` under-18 block **off `main`** until Phase 2 lands, so production never ships the dead-end screen.

---

## 12. Open questions

1. **Retention windows** — 21-day freeze / 45-day purge are my proposal, not researched against counsel's view. Your call.
2. **Draft-but-don't-send** for coach emails — I think it's the right hook, but it means a minor composes a message to an adult that sits in our DB pre-consent. Acceptable to you?
3. **Guardian email verification depth** — click-through only, or a verified-address round trip before unlocking? Click-through matches the existing invite flow's strictness; anything more is a new bar.
4. **Endpoint vs. deferred constraint** (§5) — I recommend the server endpoint. It also retires the browser-direct-write limitation both existing migrations cite.
5. **App Store review notes** — `planning/app-store-submission-plan.md:208,251` commits to "13-17 via parent invite only". That text needs rewriting before the next submission, and the reviewer note should describe guardian confirmation explicitly.

# Pricing Model & Family Entitlement Plumbing — Design Spec

**Date:** 2026-09-03
**Status:** Approved (interview + design approved by Chris, 2026-09-03)
**Scope:** iOS (`recruiting-compass-ios`), web (`recruiting-compass-web`), landing site (`recruiting-compass-landing`), Supabase schema.
**Supersedes:** Freemium Free/$12/$25 tiers in original PRD; "$5–10/mo freemium" in web stakeholder docs; "single tier, amount TBD" in `2026-08-30-launch-readiness-handoff.md` (amount now set).

---

## 1. Decisions (locked)

| # | Decision | Choice |
|---|----------|--------|
| 1 | Billing unit | **Family unit.** One entitlement covers every member of the family. Stored against `family_units.id`, never against a user. |
| 2 | Launch posture | **Launch free with entitlement plumbing in place**, all gates open. Flip pricing on later via config. No IAP in the launch binary. |
| 3 | Model | **Subscription.** Annual anchored, monthly as secondary option. No lifetime/one-time. No permanent free tier. |
| 4 | Payment rails | **RevenueCat**: StoreKit on iOS, Stripe (via RevenueCat Web Billing) on web. Same price on both platforms. Supabase is the entitlement source of truth. |
| 5 | Trial | **30-day full-access trial → read-only.** Card-free, clock owned by Supabase (not Apple intro offer), starts at family creation. |
| 6 | Read-only semantics | Single boolean `can_write`. Read-only blocks all create/update/delete on family content, Quick Comm send, and public-profile publish; **public profile goes dark** on lapse. View, dashboard, analytics, notifications, export, settings, family management (accept invite → pay) stay available. Nothing is free forever. |
| 7 | Founding families | Any family created before `pricing_flip_at` is **free for life** (`status = founding`). Date-capped, not count-capped. Friends/family after flip = manual `comp` status via admin. Apple offer codes / Stripe coupons = later marketing tool only. |
| 8 | Price (working hypothesis) | **$99/yr, $12.99/mo.** Revisit with usage data at flip. Plumbing is price-agnostic. |
| 9 | Flip trigger | **90 days after App Store approval OR 50 active families, whichever first.** Date published on landing site. |
| 10 | Multi-athlete parents | Each family unit subscribes separately. Sibling discount later via coupon. RevenueCat `app_user_id = family_unit_id`. Known edge: same Apple ID cannot hold two active subs of the same product → second family buys via web or another member. Document, don't solve. |
| 11 | In-app visibility pre-flip | **Subtle.** Settings → "Plan" row only ("Founding Family — free for life"). No banners/badges. Landing site carries the urgency. |
| 12 | Legal/store housekeeping | Add subscription clause to ToS now (both platforms). Landing site copy updated now. Remove "completely free" from App Store submission plan. Enroll in Apple Small Business Program (Chris). Privacy label changes deferred to Phase 1. |

### Rationale summary
- Zero audience at launch → paywall gates nobody; only adds review risk and support surface.
- Free→paid is not an anti-pattern **when early users are grandfathered**. Founding-forever is the launch hook.
- Subscription fatigue is real for forgettable apps; recruiting is finite, high-stakes, and parents already spend $1k–$10k/yr. Annual matches the season; monthly invites off-season churn.
- School-count freemium fights the product (value is breadth). Time-boxed full trial + read-only degrade = one gate, identical on web/iOS/RLS, no data hostage.
- Apple requires IAP for in-app digital features → Stripe-only is not an option; RevenueCat is free under $2.5k MTR and removes weeks of webhook/receipt work.

---

## 2. Architecture

**Principle:** entitlement is DB-authoritative, enforced by RLS, mirrored to clients for UI. Stores (Apple/Stripe) write into the DB via webhook; founding/comp families never touch a store.

Rejected: client-only gating (drifts across platforms, bypassable); RevenueCat-authoritative (no store at launch; founding/comp have no store record).

### 2.1 Schema

Migration lives in the **web repo only** (`recruiting-compass-web/supabase/migrations/`); the iOS repo's migrations dir is a stale slice and is not updated.

```sql
-- enums
create type subscription_status as enum ('founding','trialing','active','read_only','comp');
create type subscription_source as enum ('founding','comp','apple','stripe');

create table family_subscriptions (
  family_unit_id       uuid primary key references family_units(id) on delete cascade,
  status               subscription_status not null,
  source               subscription_source not null,
  trial_ends_at        timestamptz,
  current_period_end   timestamptz,
  provider_customer_id text,            -- RevenueCat app_user_id; equals family_unit_id::text
  provider_product_id  text,            -- e.g. 'trc_annual', 'trc_monthly'
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create table app_config (
  id               boolean primary key default true check (id),   -- single row
  pricing_flip_at  timestamptz,                                   -- null = pre-flip
  trial_days       integer not null default 30
);
insert into app_config default values;
```

**Trigger** `on insert family_units`:
- `pricing_flip_at` is null or `> now()` → insert `family_subscriptions (status='founding', source='founding')`.
- else → `status='trialing', source='founding', trial_ends_at = now() + trial_days`.

**Backfill:** every existing `family_units` row → `founding`.

**Function:**
```sql
create or replace function family_can_write(p_family_unit_id uuid)
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from family_subscriptions s
    where s.family_unit_id = p_family_unit_id
      and (
        s.status in ('founding','active','comp')
        or (s.status = 'trialing' and s.trial_ends_at > now())
      )
  );
$$;
```
Note: `NULL` family_unit_id returns `true` (non-family-scoped rows are not gated). `trialing` past `trial_ends_at` reads as not-writable without a cron; a nightly job may later normalize it to `read_only` for reporting, but correctness does not depend on it.

### 2.2 Enforcement (RLS)
- Every table carrying `family_unit_id` (schools, coaches, interactions, events, offers, tasks, performance_metrics, video_links, documents, communication_templates, player prefs, public profile settings, etc. — enumerate from `20260805000000_family_unit_id_columns_trigger_backfill.sql`): gain one `RESTRICTIVE` policy per verb (`<table>_<verb>_requires_entitlement`) calling `family_can_write(family_unit_id)`; existing permissive policies are untouched. SELECT untouched.
- `family_subscriptions`: SELECT for members of that family; INSERT/UPDATE/DELETE service-role only.
- `app_config`: SELECT authenticated; writes service-role only.
- Post-launch every family is `founding` → zero behavior change. Verified by test that flips one family to `read_only`.

### 2.3 Clients (parity)
| | iOS | Web |
|---|---|---|
| State | `EntitlementStore` — `@Observable @MainActor`, `nonisolated deinit {}` | `useEntitlement()` composable |
| Loads | on session restore + active-family change | on auth ready + family change |
| Exposes | `plan: Plan`, `canWrite: Bool`, `trialEndsAt: Date?`, `currentPeriodEnd: Date?` | same |
| Display | Settings → "Plan" row | Settings → "Plan" row |
| Plan labels | Founding Family — free for life · Trial — N days left · Active — renews {date} · Complimentary · Read-only | same |

Phase 0 exposes `canWrite`; nothing but the settings row consumes it. Phase 1 wires it into write CTAs and a shared `ReadOnlyBanner`.

### 2.4 Public profile
`p/[slug]` (web) and native preview: when `family_can_write` is false, render "This profile is not currently available." Ships in Phase 1 (no family can be non-writable before flip).

### 2.5 Store integration (Phase 1)
- RevenueCat project; `app_user_id = family_unit_id`. Any member can purchase on the family's behalf; client calls `Purchases.logIn(familyUnitId)` after family resolves.
- Products: `trc_annual` ($99/yr), `trc_monthly` ($12.99/mo) in App Store Connect + Stripe; single RevenueCat entitlement `full_access`.
- Supabase edge function `revenuecat-webhook`: verifies auth header, upserts `family_subscriptions` (`active` / `read_only`, `source`, `current_period_end`, product id). Idempotent on event id.
- Paywall: iOS `PaywallView` (RevenueCat Paywalls or custom), web `/settings/plan`. Both reachable from Settings → Plan row and from ReadOnlyBanner.
- Admin comp toggle: web `admin/` page action → sets `status='comp'`, optional `current_period_end` as expiry.

---

## 3. Phases

### Phase 0 — pre-submit (this work)
1. Migration: enums, `family_subscriptions`, `app_config`, trigger, backfill, `family_can_write`, RLS write-policy amendments, subscription-table policies.
2. iOS `EntitlementStore` + Settings Plan row + tests.
3. Web `useEntitlement` + Settings Plan row + tests.
4. ToS subscription clause (iOS `TermsOfServiceView.swift`, web `pages/legal/terms.vue`): auto-renewal, billing through Apple / Stripe, cancellation via store, refunds per store policy, price-change notice, founding-family grant, read-only on lapse, data export.
5. Landing site: founding offer + deadline copy; remove JSON-LD `price: "0"`; rewrite FAQ "finalizing pricing"; fold "survey participants special pricing" into founding offer; state $99/yr / $12.99/mo post-flip.
6. Docs: strip "completely free" from `app-store-submission-plan.md`; rewrite §4 Business Model in `business-plan-update-recommendations.md`; note stale web stakeholder docs.
7. Chris: enroll Apple Small Business Program.

### Phase 1 — post-launch, pre-flip
RevenueCat + products + Stripe, webhook edge fn, paywall (both), ReadOnlyBanner + CTA gating (both), public-profile dark, admin comp toggle, privacy nutrition label update, trial-expiry cron (optional).

### Phase 2 — flip day
Set `app_config.pricing_flip_at`; release IAP binary; landing copy → live pricing; announce to founding families.

---

## 4. Testing
- **Live-DB Vitest integration spec (`tests/integration/rls/rls-family-subscriptions.integration.spec.ts`):** trigger yields `founding` pre-flip and `trialing`+30d post-flip; `family_can_write` truth table (5 statuses × trial expiry); RLS: `read_only` family SELECT ok / INSERT-UPDATE-DELETE denied on ≥3 representative tables; `founding` family unaffected.
- **iOS unit:** `EntitlementStore` decode + derived `plan`/`canWrite`; Plan row label per status.
- **Web unit (vitest):** `useEntitlement` same matrix; Plan row render.
- **Regression:** full existing suites green (RLS change touches every write path).

---

## 5. Open items / risks
- Trial clock starts at family creation, not first launch — a family created pre-flip is founding regardless, so no issue until flip.
- Same-Apple-ID two-family limitation (Decision 10) — document in help.
- Price research before flip: competitor matrix (FieldLevel, NextUp, NCSA/IMG) still owed per business-plan doc.
- Web stakeholder docs (`PRODUCT_BRIEF`, `PITCH_DECK_OUTLINE`, `PRESS_KIT`, `LANDING_PAGE_COPY`) still say freemium $5–10 — update when those docs are next touched.

# Family Entitlement Plumbing (Phase 0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the free-launch entitlement plumbing: a per-family subscription record, a DB-enforced `family_can_write` gate (open for everyone at launch), a Settings "Plan" row on iOS + web, a subscription clause in the ToS, and consistent landing/doc copy — with no paywall and no IAP.

**Architecture:** Supabase is the entitlement source of truth. A trigger stamps every new `family_units` row with a `family_subscriptions` row (`founding` before `app_config.pricing_flip_at`, `trialing` after). `family_can_write(uuid)` is a STABLE SECURITY DEFINER SQL function; one `RESTRICTIVE` policy per family-content table ANDs it onto the existing permissive write policies, so no existing policy is edited. Clients read the row and expose `canWrite` + a plan label; in Phase 0 only the Settings row consumes it.

**Tech Stack:** Postgres/Supabase (RLS, plpgsql), Nuxt 3 + Vitest (web), SwiftUI + `@Observable` + XCTest (iOS), Nuxt (landing).

**Spec:** `planning/2026-09-03-pricing-model-and-entitlement-plumbing-spec.md` (iOS repo). Read it first.

## Global Constraints

- Repos: web `/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web` (branch base `develop`), iOS `/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios` (base `main`), landing `/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-landing` (base = its default branch; check with `git branch --show-current`).
- **Migrations live in the web repo only** (`recruiting-compass-web/supabase/migrations/`). The iOS repo's `supabase/migrations/` is a stale slice; do not add files there. (Spec §2.1 said "mirrored" — Task 10 corrects the spec.)
- Feature branches in worktrees: `.worktrees/feat-family-entitlement-plumbing/` in each repo. Confirm `pwd && git branch --show-current` before every write.
- iOS source root is double-nested: `TheRecruitingCompass/TheRecruitingCompass/…`; tests in `TheRecruitingCompass/TheRecruitingCompassTests/…`. Every `@MainActor` class (prod and test) gets `nonisolated deinit {}`. SwiftLint line length 140. Semantic fonts only.
- iOS build/test from `recruiting-compass-ios/TheRecruitingCompass/`: `xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`; tests via `-only-testing:TheRecruitingCompassTests/<Class>`.
- Web: `npx vitest run <path>`, `npx nuxi typecheck`, `npx eslint <files>`.
- Statuses: `founding | trialing | active | read_only | comp`. Sources: `founding | comp | apple | stripe`. Price copy: **$99/year, $12.99/month**. Trial: **30 days**.
- Plan labels (identical on both platforms): `Founding Family — free for life` · `Free trial — N days left` · `Active — renews {date}` · `Complimentary access` · `Read-only — subscription needed` · `Plan unavailable` (no row).
- No `git add -A`. Commit messages `<type>: <desc>`; end with `Claude-Session: https://claude.ai/code/session_01BdCVhhV2h7f8seTSWX2YyX`.
- Do NOT gate any UI on `canWrite` in this phase. Do NOT add StoreKit/RevenueCat/Stripe.

---

## File Structure

**Web (`recruiting-compass-web`)**
- Create `supabase/migrations/20260916000000_family_subscriptions.sql` — schema, trigger, backfill, function, RLS.
- Create `tests/integration/rls/rls-family-subscriptions.integration.spec.ts` — live-DB proof of trigger + gate.
- Modify `types/database.ts` — add two tables, one function, two enums.
- Create `composables/useEntitlement.ts` — pure derivation fns + composable.
- Create `tests/unit/composables/useEntitlement.spec.ts`.
- Create `pages/settings/plan.vue`; modify `pages/settings/index.vue` (add Plan card).
- Modify `pages/legal/terms.vue` (new §22, contact → §23, Last Updated), `utils/legal.ts` (version).
- Modify `claude/database.md` (document `family_can_write`).

**iOS (`recruiting-compass-ios/TheRecruitingCompass/TheRecruitingCompass/`)**
- Create `Features/Entitlement/Models/FamilySubscription.swift` — enums + struct + derived label/canWrite.
- Create `Features/Entitlement/Services/EntitlementManaging.swift`, `EntitlementServiceImpl.swift`, `EntitlementStore.swift`.
- Create `Features/Entitlement/Views/PlanView.swift`.
- Modify `Features/Settings/Views/SettingsView.swift` (Plan section + destination + load), `TheRecruitingCompassApp.swift` (inject store).
- Modify `Features/Legal/Views/TermsOfServiceView.swift` (new §22, contact → §23), `Features/Legal/Models/LegalRevision.swift` + `TermsOfService.swift` (terms-specific date).
- Tests under `TheRecruitingCompassTests/Features/Entitlement/`: `FamilySubscriptionTests.swift`, `EntitlementStoreTests.swift`, `MockEntitlementService.swift`.

**Landing (`recruiting-compass-landing`)**
- Modify `pages/index.vue` (faqs[0], drop `offers`), `components/sections/FaqSection.vue` (faqs[0]), `components/sections/CtaSection.vue` (card 2).

**Docs (iOS repo `planning/`)**
- Modify `app-store-submission-plan.md`, `business-plan-update-recommendations.md`, `2026-09-03-pricing-model-and-entitlement-plumbing-spec.md`.

---

### Task 1: Migration — schema, trigger, backfill, gate function, RLS

**Files:**
- Create: `recruiting-compass-web/supabase/migrations/20260916000000_family_subscriptions.sql`
- Test: `recruiting-compass-web/tests/integration/rls/rls-family-subscriptions.integration.spec.ts`

**Interfaces:**
- Produces: tables `public.family_subscriptions`, `public.app_config`; enums `subscription_status`, `subscription_source`; function `public.family_can_write(p_family_unit_id uuid) returns boolean`; trigger `family_units_create_subscription`; restrictive policies named `<table>_write_requires_entitlement`.

- [ ] **Step 1: Create worktree + branch (web)**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
git fetch origin && git worktree add .worktrees/feat-family-entitlement-plumbing -b feat/family-entitlement-plumbing origin/develop
cd .worktrees/feat-family-entitlement-plumbing && pwd && git branch --show-current
```

- [ ] **Step 2: Write the failing integration test**

Create `tests/integration/rls/rls-family-subscriptions.integration.spec.ts`. Copy lines 16–57 of `tests/integration/rls/rls-family-deferrals.integration.spec.ts` verbatim for imports, `hasLiveSupabase`, `adminClient`, `signIn`, then:

```ts
const RUN_ID = Date.now();
const PASSWORD = "FamilySubsRlsTest123!";

describe.skipIf(!hasLiveSupabase)(
  "family_subscriptions — trigger, family_can_write, restrictive write gate",
  () => {
    const admin = hasLiveSupabase ? adminClient() : (null as never);
    let playerId: string;
    let familyId: string;
    let email: string;

    const setStatus = async (
      status: string,
      extra: Record<string, unknown> = {},
    ) => {
      const { error } = await admin
        .from("family_subscriptions")
        .update({ status, ...extra })
        .eq("family_unit_id", familyId);
      if (error) throw new Error(`setStatus(${status}): ${error.message}`);
    };

    const insertSchoolAsPlayer = async () => {
      const client = await signIn(email, PASSWORD);
      return client
        .from("schools")
        .insert({
          user_id: playerId,
          family_unit_id: familyId,
          name: `[e2e-subs-${RUN_ID}] ${Math.random()}`,
        })
        .select("id")
        .single();
    };

    beforeAll(async () => {
      if (!hasLiveSupabase) return;
      email = `e2e-rls-subs-${RUN_ID}-player@example.com`;
      const { data: userData, error: userErr } =
        await admin.auth.admin.createUser({
          email,
          password: PASSWORD,
          email_confirm: true,
          user_metadata: { role: "player" },
        });
      if (userErr || !userData.user) throw new Error(userErr?.message);
      playerId = userData.user.id;
      await admin.from("users").insert({ id: playerId, email, role: "player" });
      const { data: family, error: familyErr } = await admin
        .from("family_units")
        .insert({ created_by_user_id: playerId, family_name: "Subs Fam" })
        .select("id")
        .single();
      if (familyErr || !family) throw new Error(familyErr?.message);
      familyId = family.id as string;
      await admin
        .from("family_members")
        .insert({ family_unit_id: familyId, user_id: playerId, role: "player" });
    }, 30000);

    afterAll(async () => {
      if (!hasLiveSupabase) return;
      await admin.from("schools").delete().eq("family_unit_id", familyId);
      await admin.from("family_units").delete().eq("id", familyId);
      await admin.auth.admin.deleteUser(playerId);
    });

    it("trigger creates a founding row for a new family (pre-flip)", async () => {
      const { data } = await admin
        .from("family_subscriptions")
        .select("status, source")
        .eq("family_unit_id", familyId)
        .single();
      expect(data).toEqual({ status: "founding", source: "founding" });
    });

    it("member can SELECT own family_subscriptions row", async () => {
      const client = await signIn(email, PASSWORD);
      const { data, error } = await client
        .from("family_subscriptions")
        .select("status")
        .eq("family_unit_id", familyId)
        .single();
      expect(error).toBeNull();
      expect(data?.status).toBe("founding");
    });

    it("member cannot UPDATE family_subscriptions", async () => {
      const client = await signIn(email, PASSWORD);
      const { data } = await client
        .from("family_subscriptions")
        .update({ status: "comp" })
        .eq("family_unit_id", familyId)
        .select("status");
      expect(data ?? []).toHaveLength(0);
    });

    it("family_can_write matrix", async () => {
      const can = async () => {
        const { data, error } = await admin.rpc("family_can_write", {
          p_family_unit_id: familyId,
        });
        if (error) throw new Error(error.message);
        return data as boolean;
      };
      await setStatus("founding");
      expect(await can()).toBe(true);
      await setStatus("active");
      expect(await can()).toBe(true);
      await setStatus("comp");
      expect(await can()).toBe(true);
      await setStatus("read_only");
      expect(await can()).toBe(false);
      await setStatus("trialing", {
        trial_ends_at: new Date(Date.now() + 86_400_000).toISOString(),
      });
      expect(await can()).toBe(true);
      await setStatus("trialing", {
        trial_ends_at: new Date(Date.now() - 86_400_000).toISOString(),
      });
      expect(await can()).toBe(false);
      await setStatus("founding");
    });

    it("read_only family: INSERT denied, SELECT allowed, UPDATE denied", async () => {
      await setStatus("founding");
      const seeded = await insertSchoolAsPlayer();
      expect(seeded.error).toBeNull();
      const schoolId = seeded.data!.id as string;

      await setStatus("read_only");
      const denied = await insertSchoolAsPlayer();
      expect(denied.error).not.toBeNull();

      const client = await signIn(email, PASSWORD);
      const { data: rows } = await client
        .from("schools")
        .select("id")
        .eq("id", schoolId);
      expect(rows).toHaveLength(1);

      const { data: updated } = await client
        .from("schools")
        .update({ name: "renamed" })
        .eq("id", schoolId)
        .select("id");
      expect(updated ?? []).toHaveLength(0);

      await setStatus("founding");
    });
  },
);
```

- [ ] **Step 3: Run test to verify it fails**

Requires local stack: `npx supabase start` then `npx supabase db reset` (applies all migrations). Env: `TEST_SUPABASE_URL`, `NUXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` from `npx supabase status`.

Run: `npx vitest run tests/integration/rls/rls-family-subscriptions.integration.spec.ts`
Expected: FAIL — `relation "public.family_subscriptions" does not exist` (or the first `it` fails on `data` being null).

- [ ] **Step 4: Write the migration**

Create `supabase/migrations/20260916000000_family_subscriptions.sql`:

```sql
-- Family entitlement plumbing (Phase 0). Spec:
-- recruiting-compass-ios/planning/2026-09-03-pricing-model-and-entitlement-plumbing-spec.md
-- Every family gets a subscription row; family_can_write() gates writes via
-- RESTRICTIVE policies. Pre-flip (app_config.pricing_flip_at IS NULL) every
-- family is 'founding' => gate is open; no behaviour change at launch.

create type public.subscription_status as enum
  ('founding', 'trialing', 'active', 'read_only', 'comp');
create type public.subscription_source as enum
  ('founding', 'comp', 'apple', 'stripe');

create table public.app_config (
  id boolean primary key default true check (id),
  pricing_flip_at timestamptz,
  trial_days integer not null default 30 check (trial_days > 0),
  updated_at timestamptz not null default now()
);
comment on table public.app_config is 'Single-row app configuration. pricing_flip_at NULL = pricing not yet launched.';
insert into public.app_config default values;

create table public.family_subscriptions (
  family_unit_id uuid primary key references public.family_units(id) on delete cascade,
  status public.subscription_status not null,
  source public.subscription_source not null,
  trial_ends_at timestamptz,
  current_period_end timestamptz,
  provider_customer_id text,
  provider_product_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.family_subscriptions is 'One entitlement row per family unit. Written only by service role (trigger, admin, billing webhooks).';

create or replace function public.touch_family_subscriptions_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
create trigger family_subscriptions_touch_updated_at
  before update on public.family_subscriptions
  for each row execute function public.touch_family_subscriptions_updated_at();

-- Stamp a subscription on every new family.
create or replace function public.create_family_subscription()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_flip_at timestamptz;
  v_trial_days integer;
begin
  select pricing_flip_at, trial_days into v_flip_at, v_trial_days
  from public.app_config where id = true;

  if v_flip_at is null or v_flip_at > now() then
    insert into public.family_subscriptions (family_unit_id, status, source)
    values (new.id, 'founding', 'founding')
    on conflict (family_unit_id) do nothing;
  else
    insert into public.family_subscriptions (family_unit_id, status, source, trial_ends_at)
    values (new.id, 'trialing', 'founding', now() + make_interval(days => coalesce(v_trial_days, 30)))
    on conflict (family_unit_id) do nothing;
  end if;
  return new;
end;
$$;
create trigger family_units_create_subscription
  after insert on public.family_units
  for each row execute function public.create_family_subscription();

-- Backfill: every existing family is a founding family.
insert into public.family_subscriptions (family_unit_id, status, source)
select id, 'founding', 'founding' from public.family_units
on conflict (family_unit_id) do nothing;

-- Gate. NULL family_unit_id => true: such rows are not family-scoped and are
-- already constrained by the permissive policies; the gate only applies to
-- family content.
create or replace function public.family_can_write(p_family_unit_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select case
    when p_family_unit_id is null then true
    else exists (
      select 1 from public.family_subscriptions s
      where s.family_unit_id = p_family_unit_id
        and (
          s.status in ('founding', 'active', 'comp')
          or (s.status = 'trialing' and s.trial_ends_at is not null and s.trial_ends_at > now())
        )
    )
  end;
$$;
revoke all on function public.family_can_write(uuid) from public;
grant execute on function public.family_can_write(uuid) to authenticated, service_role;

-- RLS on the new tables.
alter table public.family_subscriptions enable row level security;
create policy family_subscriptions_select_member on public.family_subscriptions
  for select to authenticated
  using (public.user_is_family_member(family_unit_id));
-- No insert/update/delete policies for authenticated: service role only.

alter table public.app_config enable row level security;
create policy app_config_select_authenticated on public.app_config
  for select to authenticated using (true);

-- Restrictive write gate on family content tables. ANDs with existing
-- permissive policies; no existing policy is modified.
do $$
declare
  t text;
begin
  foreach t in array array[
    'schools', 'coaches', 'interactions', 'events', 'offers',
    'performance_metrics', 'documents', 'video_links',
    'communication_templates', 'user_deadlines', 'recommendation_letters',
    'athlete_messages', 'profile_contacts', 'school_recommendation_dismissals',
    'player_profiles'
  ] loop
    execute format(
      'create policy %I on public.%I as restrictive for insert to authenticated with check (public.family_can_write(family_unit_id))',
      t || '_insert_requires_entitlement', t);
    execute format(
      'create policy %I on public.%I as restrictive for update to authenticated using (public.family_can_write(family_unit_id)) with check (public.family_can_write(family_unit_id))',
      t || '_update_requires_entitlement', t);
    execute format(
      'create policy %I on public.%I as restrictive for delete to authenticated using (public.family_can_write(family_unit_id))',
      t || '_delete_requires_entitlement', t);
  end loop;
end;
$$;
```

- [ ] **Step 5: Apply and run the test**

Run: `npx supabase db reset && npx vitest run tests/integration/rls/rls-family-subscriptions.integration.spec.ts`
Expected: PASS, 5 tests. If `db reset` errors on a table name in the `foreach` list, that table does not exist locally — check `types/database.ts` and remove it from the list only if it is truly absent from the schema.

- [ ] **Step 6: Run the other RLS integration specs to prove no regression**

Run: `npx vitest run tests/integration/rls/`
Expected: all PASS (existing families are backfilled `founding` → gate open).

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/20260916000000_family_subscriptions.sql tests/integration/rls/rls-family-subscriptions.integration.spec.ts
git commit -m "feat(db): family_subscriptions + family_can_write restrictive write gate

Claude-Session: https://claude.ai/code/session_01BdCVhhV2h7f8seTSWX2YyX"
```

---

### Task 2: Web types for the new schema

**Files:**
- Modify: `recruiting-compass-web/types/database.ts` (Tables block ~L1254 near `family_units`, `Functions` block L3318, `Enums` block L3413)

**Interfaces:**
- Produces: `Database["public"]["Tables"]["family_subscriptions"]["Row"]`, `…["app_config"]["Row"]`, `Database["public"]["Enums"]["subscription_status"]`.

- [ ] **Step 1: Regenerate if the local stack is running, else hand-add**

Preferred: `npx supabase gen types typescript --local > types/database.ts` then `git diff --stat types/database.ts` — the diff must only add the new tables/function/enums. If the diff touches unrelated tables, discard and hand-add instead.

Hand-add, alphabetically inside `Tables` (before `family_units`? no — after `family_members`, before `family_units`):

```ts
      family_subscriptions: {
        Row: {
          created_at: string;
          current_period_end: string | null;
          family_unit_id: string;
          provider_customer_id: string | null;
          provider_product_id: string | null;
          source: Database["public"]["Enums"]["subscription_source"];
          status: Database["public"]["Enums"]["subscription_status"];
          trial_ends_at: string | null;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          current_period_end?: string | null;
          family_unit_id: string;
          provider_customer_id?: string | null;
          provider_product_id?: string | null;
          source: Database["public"]["Enums"]["subscription_source"];
          status: Database["public"]["Enums"]["subscription_status"];
          trial_ends_at?: string | null;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          current_period_end?: string | null;
          family_unit_id?: string;
          provider_customer_id?: string | null;
          provider_product_id?: string | null;
          source?: Database["public"]["Enums"]["subscription_source"];
          status?: Database["public"]["Enums"]["subscription_status"];
          trial_ends_at?: string | null;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "family_subscriptions_family_unit_id_fkey";
            columns: ["family_unit_id"];
            isOneToOne: true;
            referencedRelation: "family_units";
            referencedColumns: ["id"];
          },
        ];
      };
```

`app_config` (alphabetically first in `Tables`):

```ts
      app_config: {
        Row: {
          id: boolean;
          pricing_flip_at: string | null;
          trial_days: number;
          updated_at: string;
        };
        Insert: {
          id?: boolean;
          pricing_flip_at?: string | null;
          trial_days?: number;
          updated_at?: string;
        };
        Update: {
          id?: boolean;
          pricing_flip_at?: string | null;
          trial_days?: number;
          updated_at?: string;
        };
        Relationships: [];
      };
```

In `Functions` (alphabetical):
```ts
      family_can_write: { Args: { p_family_unit_id: string }; Returns: boolean };
```

In `Enums`:
```ts
      subscription_source: "founding" | "comp" | "apple" | "stripe";
      subscription_status: "founding" | "trialing" | "active" | "read_only" | "comp";
```

- [ ] **Step 2: Typecheck**

Run: `npx nuxi typecheck`
Expected: no new errors.

- [ ] **Step 3: Commit**

```bash
git add types/database.ts
git commit -m "chore(types): add family_subscriptions, app_config, family_can_write

Claude-Session: https://claude.ai/code/session_01BdCVhhV2h7f8seTSWX2YyX"
```

---

### Task 3: Web `useEntitlement` composable

**Files:**
- Create: `recruiting-compass-web/composables/useEntitlement.ts`
- Test: `recruiting-compass-web/tests/unit/composables/useEntitlement.spec.ts`

**Interfaces:**
- Consumes: `useSupabase()`, `useFamilyContext().activeFamilyId` (`ComputedRef<string | null>`), `Database` types from Task 2.
- Produces:
  ```ts
  export type SubscriptionStatus = Database["public"]["Enums"]["subscription_status"];
  export interface FamilySubscription { familyUnitId: string; status: SubscriptionStatus; source: string; trialEndsAt: string | null; currentPeriodEnd: string | null; }
  export const canWriteFrom = (sub: FamilySubscription | null, now?: Date): boolean;
  export const trialDaysLeftFrom = (sub: FamilySubscription | null, now?: Date): number | null;
  export const planLabelFrom = (sub: FamilySubscription | null, now?: Date): string;
  export const useEntitlement = () => ({ subscription, loading, error, canWrite, planLabel, trialDaysLeft, load });
  ```

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/composables/useEntitlement.spec.ts`:

```ts
import { describe, it, expect, vi, beforeEach } from "vitest";
import { ref, computed, nextTick } from "vue";

const captured: { table?: string; eqArgs?: unknown[]; row?: unknown } = {};
const activeFamilyId = ref<string | null>("fam-1");

vi.mock("~/composables/useSupabase", () => ({
  useSupabase: vi.fn(() => ({
    from: vi.fn((table: string) => {
      captured.table = table;
      return {
        select: vi.fn(() => ({
          eq: vi.fn((...args: unknown[]) => {
            captured.eqArgs = args;
            return {
              maybeSingle: vi.fn(() =>
                Promise.resolve({ data: captured.row ?? null, error: null }),
              ),
            };
          }),
        })),
      };
    }),
  })),
}));

vi.mock("~/composables/useFamilyContext", () => ({
  useFamilyContext: vi.fn(() => ({
    activeFamilyId: computed(() => activeFamilyId.value),
  })),
}));

import {
  canWriteFrom,
  planLabelFrom,
  trialDaysLeftFrom,
  useEntitlement,
  type FamilySubscription,
} from "~/composables/useEntitlement";

const NOW = new Date("2026-09-03T12:00:00Z");
const sub = (over: Partial<FamilySubscription>): FamilySubscription => ({
  familyUnitId: "fam-1",
  status: "founding",
  source: "founding",
  trialEndsAt: null,
  currentPeriodEnd: null,
  ...over,
});

describe("canWriteFrom", () => {
  it("null row → false", () => expect(canWriteFrom(null, NOW)).toBe(false));
  it("founding/active/comp → true", () => {
    for (const status of ["founding", "active", "comp"] as const) {
      expect(canWriteFrom(sub({ status }), NOW)).toBe(true);
    }
  });
  it("read_only → false", () =>
    expect(canWriteFrom(sub({ status: "read_only" }), NOW)).toBe(false));
  it("trialing before end → true, after end → false", () => {
    expect(
      canWriteFrom(sub({ status: "trialing", trialEndsAt: "2026-09-10T00:00:00Z" }), NOW),
    ).toBe(true);
    expect(
      canWriteFrom(sub({ status: "trialing", trialEndsAt: "2026-09-01T00:00:00Z" }), NOW),
    ).toBe(false);
    expect(canWriteFrom(sub({ status: "trialing", trialEndsAt: null }), NOW)).toBe(false);
  });
});

describe("trialDaysLeftFrom", () => {
  it("non-trial → null", () => expect(trialDaysLeftFrom(sub({}), NOW)).toBeNull());
  it("rounds up remaining days, floors at 0", () => {
    expect(
      trialDaysLeftFrom(sub({ status: "trialing", trialEndsAt: "2026-09-10T00:00:00Z" }), NOW),
    ).toBe(7);
    expect(
      trialDaysLeftFrom(sub({ status: "trialing", trialEndsAt: "2026-09-01T00:00:00Z" }), NOW),
    ).toBe(0);
  });
});

describe("planLabelFrom", () => {
  it.each([
    [sub({}), "Founding Family — free for life"],
    [sub({ status: "comp" }), "Complimentary access"],
    [sub({ status: "read_only" }), "Read-only — subscription needed"],
    [
      sub({ status: "trialing", trialEndsAt: "2026-09-10T00:00:00Z" }),
      "Free trial — 7 days left",
    ],
    [
      sub({ status: "active", currentPeriodEnd: "2027-09-03T00:00:00Z" }),
      "Active — renews Sep 3, 2027",
    ],
    [null, "Plan unavailable"],
  ])("labels %#", (row, expected) => {
    expect(planLabelFrom(row as FamilySubscription | null, NOW)).toBe(expected);
  });
});

describe("useEntitlement", () => {
  beforeEach(() => {
    captured.row = undefined;
    activeFamilyId.value = "fam-1";
  });

  it("loads the active family's row and maps snake_case", async () => {
    captured.row = {
      family_unit_id: "fam-1",
      status: "founding",
      source: "founding",
      trial_ends_at: null,
      current_period_end: null,
    };
    const ent = useEntitlement();
    await ent.load();
    expect(captured.table).toBe("family_subscriptions");
    expect(captured.eqArgs).toEqual(["family_unit_id", "fam-1"]);
    expect(ent.subscription.value?.status).toBe("founding");
    expect(ent.canWrite.value).toBe(true);
    expect(ent.planLabel.value).toBe("Founding Family — free for life");
  });

  it("no active family → null subscription, canWrite false", async () => {
    activeFamilyId.value = null;
    const ent = useEntitlement();
    await ent.load();
    expect(ent.subscription.value).toBeNull();
    expect(ent.canWrite.value).toBe(false);
  });

  it("reloads when activeFamilyId changes", async () => {
    captured.row = {
      family_unit_id: "fam-1",
      status: "founding",
      source: "founding",
      trial_ends_at: null,
      current_period_end: null,
    };
    const ent = useEntitlement();
    await ent.load();
    activeFamilyId.value = "fam-2";
    await nextTick();
    await new Promise((r) => setTimeout(r, 0));
    expect(captured.eqArgs).toEqual(["family_unit_id", "fam-2"]);
  });
});
```

- [ ] **Step 2: Run to verify failure**

Run: `npx vitest run tests/unit/composables/useEntitlement.spec.ts`
Expected: FAIL — cannot resolve `~/composables/useEntitlement`.

- [ ] **Step 3: Implement**

Create `composables/useEntitlement.ts`:

```ts
import { computed, ref, watch } from "vue";
import { useSupabase } from "./useSupabase";
import { useFamilyContext } from "./useFamilyContext";
import type { Database } from "~/types/database";
import { createClientLogger } from "~/utils/logger";

const logger = createClientLogger("useEntitlement");

type Row = Database["public"]["Tables"]["family_subscriptions"]["Row"];
export type SubscriptionStatus = Database["public"]["Enums"]["subscription_status"];

export interface FamilySubscription {
  familyUnitId: string;
  status: SubscriptionStatus;
  source: string;
  trialEndsAt: string | null;
  currentPeriodEnd: string | null;
}

const DAY_MS = 86_400_000;

const toSubscription = (row: Row): FamilySubscription => ({
  familyUnitId: row.family_unit_id,
  status: row.status,
  source: row.source,
  trialEndsAt: row.trial_ends_at,
  currentPeriodEnd: row.current_period_end,
});

/** Mirrors SQL `family_can_write` exactly. Keep in lockstep with the migration. */
export const canWriteFrom = (
  sub: FamilySubscription | null,
  now: Date = new Date(),
): boolean => {
  if (!sub) return false;
  if (sub.status === "founding" || sub.status === "active" || sub.status === "comp") {
    return true;
  }
  if (sub.status === "trialing" && sub.trialEndsAt) {
    return new Date(sub.trialEndsAt).getTime() > now.getTime();
  }
  return false;
};

export const trialDaysLeftFrom = (
  sub: FamilySubscription | null,
  now: Date = new Date(),
): number | null => {
  if (!sub || sub.status !== "trialing" || !sub.trialEndsAt) return null;
  const remaining = new Date(sub.trialEndsAt).getTime() - now.getTime();
  return Math.max(0, Math.ceil(remaining / DAY_MS));
};

const formatDate = (iso: string): string =>
  new Date(iso).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    timeZone: "UTC",
  });

export const planLabelFrom = (
  sub: FamilySubscription | null,
  now: Date = new Date(),
): string => {
  if (!sub) return "Plan unavailable";
  switch (sub.status) {
    case "founding":
      return "Founding Family — free for life";
    case "comp":
      return "Complimentary access";
    case "read_only":
      return "Read-only — subscription needed";
    case "trialing":
      return `Free trial — ${trialDaysLeftFrom(sub, now) ?? 0} days left`;
    case "active":
      return sub.currentPeriodEnd
        ? `Active — renews ${formatDate(sub.currentPeriodEnd)}`
        : "Active";
  }
};

export const useEntitlement = () => {
  const supabase = useSupabase();
  const { activeFamilyId } = useFamilyContext();

  const subscription = ref<FamilySubscription | null>(null);
  const loading = ref(false);
  const error = ref<string | null>(null);

  const load = async () => {
    const familyId = activeFamilyId.value;
    if (!familyId) {
      subscription.value = null;
      return;
    }
    loading.value = true;
    error.value = null;
    try {
      const { data, error: fetchError } = await supabase
        .from("family_subscriptions")
        .select("*")
        .eq("family_unit_id", familyId)
        .maybeSingle();
      if (fetchError) throw fetchError;
      subscription.value = data ? toSubscription(data as Row) : null;
    } catch (err) {
      const message = err instanceof Error ? err.message : "Failed to load plan";
      error.value = message;
      subscription.value = null;
      logger.error("[useEntitlement] load failed:", message);
    } finally {
      loading.value = false;
    }
  };

  watch(activeFamilyId, () => {
    void load();
  });

  const canWrite = computed(() => canWriteFrom(subscription.value));
  const planLabel = computed(() => planLabelFrom(subscription.value));
  const trialDaysLeft = computed(() => trialDaysLeftFrom(subscription.value));

  return { subscription, loading, error, canWrite, planLabel, trialDaysLeft, load };
};
```

- [ ] **Step 4: Run tests**

Run: `npx vitest run tests/unit/composables/useEntitlement.spec.ts`
Expected: PASS (13 tests). Then `npx eslint composables/useEntitlement.ts tests/unit/composables/useEntitlement.spec.ts`.

- [ ] **Step 5: Commit**

```bash
git add composables/useEntitlement.ts tests/unit/composables/useEntitlement.spec.ts
git commit -m "feat(web): useEntitlement composable with canWrite + plan label

Claude-Session: https://claude.ai/code/session_01BdCVhhV2h7f8seTSWX2YyX"
```

---

### Task 4: Web Settings "Plan" card + `/settings/plan` page

**Files:**
- Create: `recruiting-compass-web/pages/settings/plan.vue`
- Modify: `recruiting-compass-web/pages/settings/index.vue` (insert a new section before the "Profile & Player Info" `<div class="mb-8">` at ~L19; script block ~L160)
- Test: `recruiting-compass-web/tests/unit/pages/settings/plan.spec.ts`

**Interfaces:**
- Consumes: `useEntitlement()` from Task 3.

- [ ] **Step 1: Write the failing page test**

Create `tests/unit/pages/settings/plan.spec.ts`:

```ts
import { describe, it, expect, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { ref, computed } from "vue";

const planLabel = ref("Founding Family — free for life");
const load = vi.fn(() => Promise.resolve());

vi.mock("~/composables/useEntitlement", () => ({
  useEntitlement: vi.fn(() => ({
    subscription: ref({ status: "founding" }),
    loading: ref(false),
    error: ref(null),
    canWrite: computed(() => true),
    planLabel: computed(() => planLabel.value),
    trialDaysLeft: computed(() => null),
    load,
  })),
}));

vi.mock("#app", () => ({ definePageMeta: vi.fn() }));

import PlanPage from "~/pages/settings/plan.vue";

describe("settings/plan", () => {
  it("renders the plan label and loads on mount", async () => {
    const wrapper = mount(PlanPage, {
      global: { stubs: { NuxtLink: { template: "<a><slot /></a>" }, UIcon: true } },
    });
    await Promise.resolve();
    expect(load).toHaveBeenCalled();
    expect(wrapper.text()).toContain("Founding Family — free for life");
    expect(wrapper.text()).toContain("whole family");
  });
});
```

- [ ] **Step 2: Run to verify failure**

Run: `npx vitest run tests/unit/pages/settings/plan.spec.ts`
Expected: FAIL — cannot resolve `~/pages/settings/plan.vue`.

- [ ] **Step 3: Create the page**

`pages/settings/plan.vue`:

```vue
<template>
  <div class="mx-auto max-w-2xl px-4 py-8">
    <NuxtLink
      to="/settings"
      class="mb-6 inline-flex items-center gap-1 text-sm text-slate-500 hover:text-slate-700"
    >
      <UIcon name="i-heroicons-chevron-left" class="h-4 w-4" />
      Settings
    </NuxtLink>

    <h1 class="text-2xl font-bold text-slate-900">Plan</h1>
    <p class="mt-1 text-sm text-slate-500">
      Your plan covers your whole family — every parent and athlete in this
      family account.
    </p>

    <div class="mt-6 rounded-xl border border-slate-200 bg-white p-5 shadow-xs">
      <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">
        Current plan
      </p>
      <p class="mt-1 text-lg font-semibold text-slate-900">
        <span v-if="loading">Loading…</span>
        <span v-else>{{ planLabel }}</span>
      </p>
      <p v-if="error" class="mt-2 text-sm text-red-600">{{ error }}</p>
      <p
        v-else-if="subscription?.status === 'founding'"
        class="mt-2 text-sm text-slate-600"
      >
        You joined during our founding period. Your family keeps full access
        at no charge for as long as this account is active. Thank you for
        being early.
      </p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted } from "vue";
import { useEntitlement } from "~/composables/useEntitlement";

definePageMeta({ middleware: "auth" });

const { subscription, loading, error, planLabel, load } = useEntitlement();

onMounted(() => {
  void load();
});
</script>
```

- [ ] **Step 4: Add the card to `pages/settings/index.vue`**

Insert as the first section inside the page's main container (before the "Profile & Player Info" section):

```vue
      <div class="mb-8">
        <h2 class="mb-4 text-xs font-semibold uppercase tracking-wide text-slate-500">
          Plan
        </h2>
        <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
          <SettingsCard
            to="/settings/plan"
            icon="⭐"
            title="Plan"
            :description="planLabel"
            variant="blue"
          />
        </div>
      </div>
```

Match the existing `<h2>` classes used by the neighbouring sections exactly (copy from L19). In `<script setup>` add:

```ts
import { onMounted } from "vue";
import { useEntitlement } from "~/composables/useEntitlement";
const { planLabel, load: loadEntitlement } = useEntitlement();
onMounted(() => {
  void loadEntitlement();
});
```

- [ ] **Step 5: Run tests + typecheck + lint**

Run: `npx vitest run tests/unit/pages/settings/ && npx nuxi typecheck && npx eslint pages/settings/plan.vue pages/settings/index.vue`
Expected: PASS / clean. If an existing `tests/unit/pages/settings/index.spec.ts` exists and now fails on the unmocked `useEntitlement`, add the same `vi.mock("~/composables/useEntitlement", …)` block from Step 1 to it.

- [ ] **Step 6: Commit**

```bash
git add pages/settings/plan.vue pages/settings/index.vue tests/unit/pages/settings/plan.spec.ts
git commit -m "feat(web): Settings Plan card and /settings/plan page

Claude-Session: https://claude.ai/code/session_01BdCVhhV2h7f8seTSWX2YyX"
```

---

### Task 5: iOS `FamilySubscription` model + derived plan state

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Entitlement/Models/FamilySubscription.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Entitlement/FamilySubscriptionTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum SubscriptionStatus: String, Codable, Sendable { case founding, trialing, active, readOnly = "read_only", comp, unknown }
  struct FamilySubscription: Codable, Sendable, Equatable {
    let familyUnitId: String; let status: SubscriptionStatus; let source: String
    let trialEndsAt: Date?; let currentPeriodEnd: Date?
    func canWrite(now: Date = .now) -> Bool
    func trialDaysLeft(now: Date = .now) -> Int?
    func planLabel(now: Date = .now) -> String
  }
  enum PlanLabel { static let unavailable: String }
  ```

- [ ] **Step 1: Create worktree + branch (iOS)**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
git worktree add .worktrees/feat-family-entitlement-plumbing -b feat/family-entitlement-plumbing main
cp TheRecruitingCompass/Release.xcconfig .worktrees/feat-family-entitlement-plumbing/TheRecruitingCompass/Release.xcconfig 2>/dev/null || true
cd .worktrees/feat-family-entitlement-plumbing && pwd && git branch --show-current
```

- [ ] **Step 2: Write the failing tests**

`TheRecruitingCompassTests/Features/Entitlement/FamilySubscriptionTests.swift`:

```swift
import XCTest
@testable import TheRecruitingCompass

final class FamilySubscriptionTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_788_264_000) // 2026-09-03T12:00:00Z

  private func sub(
    _ status: SubscriptionStatus,
    trialEndsAt: Date? = nil,
    currentPeriodEnd: Date? = nil
  ) -> FamilySubscription {
    FamilySubscription(
      familyUnitId: "fam-1", status: status, source: "founding",
      trialEndsAt: trialEndsAt, currentPeriodEnd: currentPeriodEnd
    )
  }

  func test_canWrite_matrix() {
    XCTAssertTrue(sub(.founding).canWrite(now: now))
    XCTAssertTrue(sub(.active).canWrite(now: now))
    XCTAssertTrue(sub(.comp).canWrite(now: now))
    XCTAssertFalse(sub(.readOnly).canWrite(now: now))
    XCTAssertFalse(sub(.unknown).canWrite(now: now))
    XCTAssertTrue(sub(.trialing, trialEndsAt: now.addingTimeInterval(86_400)).canWrite(now: now))
    XCTAssertFalse(sub(.trialing, trialEndsAt: now.addingTimeInterval(-86_400)).canWrite(now: now))
    XCTAssertFalse(sub(.trialing, trialEndsAt: nil).canWrite(now: now))
  }

  func test_trialDaysLeft() {
    XCTAssertNil(sub(.founding).trialDaysLeft(now: now))
    XCTAssertEqual(sub(.trialing, trialEndsAt: now.addingTimeInterval(7 * 86_400)).trialDaysLeft(now: now), 7)
    XCTAssertEqual(sub(.trialing, trialEndsAt: now.addingTimeInterval(-86_400)).trialDaysLeft(now: now), 0)
  }

  func test_planLabel() {
    XCTAssertEqual(sub(.founding).planLabel(now: now), "Founding Family — free for life")
    XCTAssertEqual(sub(.comp).planLabel(now: now), "Complimentary access")
    XCTAssertEqual(sub(.readOnly).planLabel(now: now), "Read-only — subscription needed")
    XCTAssertEqual(
      sub(.trialing, trialEndsAt: now.addingTimeInterval(7 * 86_400)).planLabel(now: now),
      "Free trial — 7 days left"
    )
    let renews = Date(timeIntervalSince1970: 1_819_800_000) // 2027-09-03
    XCTAssertTrue(sub(.active, currentPeriodEnd: renews).planLabel(now: now).hasPrefix("Active — renews "))
    XCTAssertEqual(PlanLabel.unavailable, "Plan unavailable")
  }

  func test_decodesSnakeCaseAndUnknownStatus() throws {
    let json = """
    {"family_unit_id":"fam-1","status":"paused","source":"apple",
     "trial_ends_at":null,"current_period_end":"2027-09-03T00:00:00+00:00",
     "provider_customer_id":null,"provider_product_id":null,
     "created_at":"2026-09-03T00:00:00+00:00","updated_at":"2026-09-03T00:00:00+00:00"}
    """.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(FamilySubscription.self, from: json)
    XCTAssertEqual(decoded.status, .unknown)
    XCTAssertEqual(decoded.source, "apple")
    XCTAssertNotNil(decoded.currentPeriodEnd)
  }
}
```

- [ ] **Step 3: Run to verify failure**

Run (from `TheRecruitingCompass/`): `xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/FamilySubscriptionTests -quiet`
Expected: BUILD FAILED — `cannot find type 'FamilySubscription'`.

- [ ] **Step 4: Implement the model**

`Features/Entitlement/Models/FamilySubscription.swift`:

```swift
import Foundation

enum SubscriptionStatus: String, Codable, Sendable {
  case founding, trialing, active, comp
  case readOnly = "read_only"
  /// Decode-only fallback for statuses this build does not know. Never written back.
  case unknown

  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = SubscriptionStatus(rawValue: raw) ?? .unknown
  }
}

enum PlanLabel {
  static let unavailable = String(localized: "Plan unavailable")
}

struct FamilySubscription: Codable, Sendable, Equatable {
  let familyUnitId: String
  let status: SubscriptionStatus
  let source: String
  let trialEndsAt: Date?
  let currentPeriodEnd: Date?

  enum CodingKeys: String, CodingKey {
    case familyUnitId = "family_unit_id"
    case status, source
    case trialEndsAt = "trial_ends_at"
    case currentPeriodEnd = "current_period_end"
  }

  /// Mirrors SQL `family_can_write` exactly. Keep in lockstep with the migration.
  func canWrite(now: Date = .now) -> Bool {
    switch status {
    case .founding, .active, .comp:
      return true
    case .trialing:
      guard let trialEndsAt else { return false }
      return trialEndsAt > now
    case .readOnly, .unknown:
      return false
    }
  }

  func trialDaysLeft(now: Date = .now) -> Int? {
    guard status == .trialing, let trialEndsAt else { return nil }
    let remaining = trialEndsAt.timeIntervalSince(now)
    return max(0, Int((remaining / 86_400).rounded(.up)))
  }

  func planLabel(now: Date = .now) -> String {
    switch status {
    case .founding:
      return String(localized: "Founding Family — free for life")
    case .comp:
      return String(localized: "Complimentary access")
    case .readOnly, .unknown:
      return String(localized: "Read-only — subscription needed")
    case .trialing:
      return String(localized: "Free trial — \(trialDaysLeft(now: now) ?? 0) days left")
    case .active:
      guard let currentPeriodEnd else { return String(localized: "Active") }
      let date = currentPeriodEnd.formatted(date: .abbreviated, time: .omitted)
      return String(localized: "Active — renews \(date)")
    }
  }
}
```

- [ ] **Step 5: Run tests**

Same command as Step 3. Expected: PASS, 4 tests.

- [ ] **Step 6: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Entitlement/Models/FamilySubscription.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/Entitlement/FamilySubscriptionTests.swift
git commit -m "feat(entitlement): FamilySubscription model with canWrite + plan label

Claude-Session: https://claude.ai/code/session_01BdCVhhV2h7f8seTSWX2YyX"
```

---

### Task 6: iOS entitlement service + `EntitlementStore`

**Files:**
- Create: `Features/Entitlement/Services/EntitlementManaging.swift`, `Features/Entitlement/Services/EntitlementServiceImpl.swift`, `Features/Entitlement/Services/EntitlementStore.swift`
- Test: `TheRecruitingCompassTests/Features/Entitlement/MockEntitlementService.swift`, `TheRecruitingCompassTests/Features/Entitlement/EntitlementStoreTests.swift`

**Interfaces:**
- Consumes: `FamilySubscription` (Task 5), `SupabaseManager` (`supabaseManager.client`).
- Produces:
  ```swift
  protocol EntitlementManaging: Sendable { func fetchSubscription(familyUnitId: String) async throws -> FamilySubscription? }
  @Observable @MainActor final class EntitlementStore {
    var subscription: FamilySubscription?; var isLoading: Bool; var errorMessage: String?
    var canWrite: Bool; var planLabel: String
    init(service: any EntitlementManaging = EntitlementServiceImpl(supabaseManager: .shared))
    func load(familyUnitId: String?) async
  }
  ```

- [ ] **Step 1: Write the mock + failing tests**

`TheRecruitingCompassTests/Features/Entitlement/MockEntitlementService.swift`:

```swift
import Foundation
@testable import TheRecruitingCompass

final class MockEntitlementService: EntitlementManaging, @unchecked Sendable {
  var subscription: FamilySubscription?
  var error: Error?
  private(set) var requestedFamilyIds: [String] = []

  func fetchSubscription(familyUnitId: String) async throws -> FamilySubscription? {
    requestedFamilyIds.append(familyUnitId)
    if let error { throw error }
    return subscription
  }
}
```

`TheRecruitingCompassTests/Features/Entitlement/EntitlementStoreTests.swift`:

```swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class EntitlementStoreTests: XCTestCase {
  nonisolated deinit {}

  private func makeStore(_ sub: FamilySubscription?) -> (EntitlementStore, MockEntitlementService) {
    let mock = MockEntitlementService()
    mock.subscription = sub
    return (EntitlementStore(service: mock), mock)
  }

  private let founding = FamilySubscription(
    familyUnitId: "fam-1", status: .founding, source: "founding", trialEndsAt: nil, currentPeriodEnd: nil
  )

  func test_loadPopulatesSubscriptionAndDerivedState() async {
    let (store, mock) = makeStore(founding)
    await store.load(familyUnitId: "fam-1")
    XCTAssertEqual(mock.requestedFamilyIds, ["fam-1"])
    XCTAssertEqual(store.subscription, founding)
    XCTAssertTrue(store.canWrite)
    XCTAssertEqual(store.planLabel, "Founding Family — free for life")
    XCTAssertNil(store.errorMessage)
  }

  func test_nilFamilyClearsState() async {
    let (store, mock) = makeStore(founding)
    await store.load(familyUnitId: "fam-1")
    await store.load(familyUnitId: nil)
    XCTAssertNil(store.subscription)
    XCTAssertFalse(store.canWrite)
    XCTAssertEqual(store.planLabel, PlanLabel.unavailable)
    XCTAssertEqual(mock.requestedFamilyIds, ["fam-1"])
  }

  func test_missingRowIsUnavailableNotError() async {
    let (store, _) = makeStore(nil)
    await store.load(familyUnitId: "fam-1")
    XCTAssertNil(store.subscription)
    XCTAssertFalse(store.canWrite)
    XCTAssertEqual(store.planLabel, PlanLabel.unavailable)
    XCTAssertNil(store.errorMessage)
  }

  func test_serviceErrorSetsMessageAndClears() async {
    let (store, mock) = makeStore(founding)
    await store.load(familyUnitId: "fam-1")
    mock.error = URLError(.notConnectedToInternet)
    await store.load(familyUnitId: "fam-1")
    XCTAssertNil(store.subscription)
    XCTAssertFalse(store.canWrite)
    XCTAssertNotNil(store.errorMessage)
  }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/EntitlementStoreTests -quiet`
Expected: BUILD FAILED — `cannot find type 'EntitlementManaging'`.

- [ ] **Step 3: Implement protocol, service, store**

`Features/Entitlement/Services/EntitlementManaging.swift`:

```swift
import Foundation

protocol EntitlementManaging: Sendable {
  /// Returns nil when the family has no subscription row (should not happen after the trigger, but tolerate it).
  func fetchSubscription(familyUnitId: String) async throws -> FamilySubscription?
}
```

`Features/Entitlement/Services/EntitlementServiceImpl.swift`:

```swift
import Foundation

final class EntitlementServiceImpl: EntitlementManaging, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager = .shared) {
    self.supabaseManager = supabaseManager
  }

  func fetchSubscription(familyUnitId: String) async throws -> FamilySubscription? {
    let rows: [FamilySubscription] = try await supabaseManager.client
      .from("family_subscriptions")
      .select()
      .eq("family_unit_id", value: familyUnitId)
      .limit(1)
      .execute()
      .value
    return rows.first
  }
}
```

`Features/Entitlement/Services/EntitlementStore.swift`:

```swift
import Foundation
import Observation
import OSLog

/// App-wide family entitlement state. Source of truth is `family_subscriptions` in Supabase;
/// this mirrors it for UI. Phase 0: only the Settings Plan row reads it.
@Observable
@MainActor
final class EntitlementStore {
  nonisolated deinit {}

  private(set) var subscription: FamilySubscription?
  private(set) var isLoading = false
  private(set) var errorMessage: String?

  private let service: any EntitlementManaging
  private let logger = Logger(subsystem: "com.therecruitingcompass", category: "EntitlementStore")

  var canWrite: Bool { subscription?.canWrite() ?? false }
  var planLabel: String { subscription?.planLabel() ?? PlanLabel.unavailable }

  init(service: any EntitlementManaging = EntitlementServiceImpl(supabaseManager: .shared)) {
    self.service = service
  }

  func load(familyUnitId: String?) async {
    guard let familyUnitId else {
      subscription = nil
      errorMessage = nil
      return
    }
    isLoading = true
    defer { isLoading = false }
    do {
      subscription = try await service.fetchSubscription(familyUnitId: familyUnitId)
      errorMessage = nil
    } catch {
      subscription = nil
      errorMessage = error.localizedDescription
      logger.error("Failed to load entitlement: \(error.localizedDescription)")
    }
  }
}
```

If `SupabaseManager` exposes its client under a different property name than `client`, match `VideoLinksServiceImpl.swift:36-49`. If the project's Logger subsystem constant differs, copy the one used in `FamilyManager.swift`.

- [ ] **Step 4: Run tests**

Same command as Step 2. Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Entitlement/Services TheRecruitingCompass/TheRecruitingCompassTests/Features/Entitlement/MockEntitlementService.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/Entitlement/EntitlementStoreTests.swift
git commit -m "feat(entitlement): EntitlementStore + Supabase-backed service

Claude-Session: https://claude.ai/code/session_01BdCVhhV2h7f8seTSWX2YyX"
```

---

### Task 7: iOS Settings "Plan" row + `PlanView` + environment injection

**Files:**
- Create: `Features/Entitlement/Views/PlanView.swift`
- Modify: `Features/Settings/Views/SettingsView.swift` (enum L3-14, Family section L33-73, destination switch L220-260, `.task` L261-264), `TheRecruitingCompassApp.swift` (`@State` L18-22, `.environment` L142-146)

**Interfaces:**
- Consumes: `EntitlementStore` (Task 6), `FamilyManager.familyUnitId`.

- [ ] **Step 1: Create `PlanView`**

`Features/Entitlement/Views/PlanView.swift`:

```swift
import SwiftUI

struct PlanView: View {
  @Environment(EntitlementStore.self) private var entitlementStore
  @Environment(FamilyManager.self) private var familyManager

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 6) {
          Text("Current plan")
            .font(.caption)
            .foregroundStyle(.secondary)
          if entitlementStore.isLoading {
            ProgressView()
          } else {
            Text(entitlementStore.planLabel)
              .font(.headline)
          }
          if let message = entitlementStore.errorMessage {
            Text(message)
              .font(.caption)
              .foregroundStyle(.red)
          } else if entitlementStore.subscription?.status == .founding {
            Text("You joined during our founding period. Your family keeps full access at no charge for as long as this account is active. Thank you for being early.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
      } footer: {
        Text("Your plan covers your whole family — every parent and athlete in this family account.")
      }
    }
    .navigationTitle("Plan")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await entitlementStore.load(familyUnitId: familyManager.familyUnitId)
    }
  }
}

#Preview {
  NavigationStack {
    PlanView()
      .environment(EntitlementStore())
      .environment(FamilyManager.shared)
  }
}
```

- [ ] **Step 2: Wire `SettingsView`**

In `SettingsView.swift`:
1. Add `case plan` to `SettingsDestination` (after `familyManagement`).
2. Add `@Environment(EntitlementStore.self) private var entitlementStore` beside the other environments.
3. Insert a new `Section` **before** the Family section:

```swift
        Section {
          NavigationLink(value: SettingsDestination.plan) {
            SettingsRow(
              icon: "star.fill",
              title: String(localized: "Plan"),
              description: entitlementStore.planLabel,
              color: .orange
            )
          }
        } header: {
          Text("Plan")
        }
```

4. In the `navigationDestination` switch add `case .plan: PlanView()`.
5. In the existing `.task`, after `await familyManager.loadFamilyData()`, add `await entitlementStore.load(familyUnitId: familyManager.familyUnitId)`.
6. Update the `#Preview` to add `.environment(EntitlementStore())`.

- [ ] **Step 3: Inject the store at the app root**

In `TheRecruitingCompassApp.swift`: add `@State private var entitlementStore = EntitlementStore()` after L22 (`nuxProgressManager`), and `.environment(entitlementStore)` after L146. Any other `SettingsView()` construction sites (grep `SettingsView(` across `TheRecruitingCompass/`) inherit the environment; previews that construct `SettingsView` need `.environment(EntitlementStore())`.

- [ ] **Step 4: Build + run Settings/Entitlement tests**

Run: `xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: EXIT 0, no errors. Then run any existing Settings tests: `grep -rl "SettingsView\|SettingsViewModel" TheRecruitingCompassTests | head` and run those classes with `-only-testing:`. Expected: PASS.

- [ ] **Step 5: Manual sim check**

Launch on iPhone 17 sim, sign in, Settings → Plan row shows "Founding Family — free for life"; tap → PlanView renders the same label + founding paragraph. VoiceOver reads the row as "Plan: Founding Family — free for life".

- [ ] **Step 6: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Entitlement/Views/PlanView.swift TheRecruitingCompass/TheRecruitingCompass/Features/Settings/Views/SettingsView.swift TheRecruitingCompass/TheRecruitingCompass/TheRecruitingCompassApp.swift
git commit -m "feat(settings): Plan row and PlanView backed by EntitlementStore

Claude-Session: https://claude.ai/code/session_01BdCVhhV2h7f8seTSWX2YyX"
```

---

### Task 8: Terms of Service — Subscriptions & Payments clause (both platforms)

**Files:**
- Modify (iOS): `Features/Legal/Views/TermsOfServiceView.swift` (assembly L41-62, §22 Contact at L467), `Features/Legal/Models/LegalRevision.swift`, `Features/Legal/Models/TermsOfService.swift:11`
- Modify (web): `pages/legal/terms.vue` (L28 Last Updated, §22 Contact at L534), `utils/legal.ts:8`

**Canonical clause text** (use verbatim on both platforms; heading numbers differ only by platform section count — both are 22):

> **22. Subscriptions and Payments**
>
> (a) Free access. The Service is currently offered at no charge. Families who create an account before we begin charging ("Founding Families") keep full access at no charge for as long as their family account remains active.
>
> (b) Paid plans. We may introduce paid subscription plans. Where offered, a subscription is billed per family account, covers every member of that family, and renews automatically at the end of each billing period until cancelled. The price and billing period are shown before you subscribe.
>
> (c) Billing and cancellation. Subscriptions purchased through the Apple App Store are billed and managed by Apple; cancel through your Apple ID subscription settings. Subscriptions purchased on our website are billed by our payment processor; cancel from your account settings. Cancellation takes effect at the end of the current billing period.
>
> (d) Refunds. Refunds for App Store purchases are governed by Apple's policies. For website purchases, contact us at the address in Section 23; refunds are at our discretion except where required by law.
>
> (e) Free trials and read-only access. We may offer a free trial. When a trial or subscription ends, your family account becomes read-only: you can view and export your data but cannot add or change it, and your public athlete profile is not available until a subscription is active.
>
> (f) Price changes. We will give existing subscribers at least 30 days' notice before a price change takes effect.
>
> (g) Your data. We do not delete your data when a subscription lapses. Section 14 continues to apply.

- [ ] **Step 1: iOS — add `section22Subscriptions`, renumber Contact to 23**

In `TermsOfServiceView.swift`:
1. Rename `// MARK: - Section 22: Contact Information` → `Section 23`, rename property `section22ContactInformation` → `section23ContactInformation`, change its `LegalSectionHeader(text: "22. Contact Information")` → `"23. Contact Information"`. Update the call in the assembly (L62).
2. Insert before the Contact MARK:

```swift
  // MARK: - Section 22: Subscriptions and Payments

  @ViewBuilder
  private var section22Subscriptions: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "22. Subscriptions and Payments")
      LegalBodyText(text:
        "(a) Free access. The Service is currently offered at no charge. Families who create an account before we begin charging " +
          "(\"Founding Families\") keep full access at no charge for as long as their family account remains active."
      )
      LegalBodyText(text:
        "(b) Paid plans. We may introduce paid subscription plans. Where offered, a subscription is billed per family account, covers " +
          "every member of that family, and renews automatically at the end of each billing period until cancelled. The price and " +
          "billing period are shown before you subscribe."
      )
      LegalBodyText(text:
        "(c) Billing and cancellation. Subscriptions purchased through the Apple App Store are billed and managed by Apple; cancel " +
          "through your Apple ID subscription settings. Subscriptions purchased on our website are billed by our payment processor; " +
          "cancel from your account settings. Cancellation takes effect at the end of the current billing period."
      )
      LegalBodyText(text:
        "(d) Refunds. Refunds for App Store purchases are governed by Apple's policies. For website purchases, contact us at the " +
          "address in Section 23; refunds are at our discretion except where required by law."
      )
      LegalBodyText(text:
        "(e) Free trials and read-only access. We may offer a free trial. When a trial or subscription ends, your family account " +
          "becomes read-only: you can view and export your data but cannot add or change it, and your public athlete profile is not " +
          "available until a subscription is active."
      )
      LegalBodyText(text:
        "(f) Price changes. We will give existing subscribers at least 30 days' notice before a price change takes effect."
      )
      LegalBodyText(text:
        "(g) Your data. We do not delete your data when a subscription lapses. Section 14 continues to apply."
      )
    }
  }
```

3. In the assembly (L41-62) insert `section22Subscriptions` between `section21GeneralProvisions` and `section23ContactInformation`.

- [ ] **Step 2: iOS — terms-specific revision date**

`LegalRevision.swift` — add a second constant and keep privacy on the old date:

```swift
enum LegalRevision {
  /// August 16, 2026 — current Privacy Policy revision.
  static let lastUpdated: Date = makeDate(year: 2026, month: 8, day: 16)

  /// September 3, 2026 — Terms revision that added §22 Subscriptions and Payments.
  /// Mirrors web `CURRENT_TERMS_VERSION` (utils/legal.ts) and pages/legal/terms.vue "Last Updated". Bump in lockstep.
  static let termsLastUpdated: Date = makeDate(year: 2026, month: 9, day: 3)

  private static func makeDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return Calendar(identifier: .gregorian).date(from: components) ?? .now
  }
}
```

`TermsOfService.swift:11` → `TermsOfService(lastUpdated: LegalRevision.termsLastUpdated)`. `PrivacyPolicy.swift:11` unchanged.

- [ ] **Step 3: iOS — build + legal tests**

Run: `xcodebuild build … -quiet` then `-only-testing:TheRecruitingCompassTests/TermsOfServiceViewModelTests` (if the class exists; `grep -rl "TermsOfService" TheRecruitingCompassTests`). If a test asserts the Aug 16 date for Terms, it is stale by spec — update it to Sep 3, 2026.

- [ ] **Step 4: iOS — commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Legal
git add TheRecruitingCompass/TheRecruitingCompassTests  # only if a legal test changed; otherwise skip
git commit -m "docs(legal): add Subscriptions and Payments to Terms (§22), bump terms revision

Claude-Session: https://claude.ai/code/session_01BdCVhhV2h7f8seTSWX2YyX"
```

- [ ] **Step 5: Web — insert §22, renumber Contact to 23, bump dates**

In `pages/legal/terms.vue`:
1. L28: `August 16, 2026` → `September 3, 2026`.
2. Before the `<section class="mb-8">` whose `<h2>` is "22. Contact Information" (L534), insert a new section using the same `<section>/<h2>/<p>` markup as its neighbours, heading `22. Subscriptions and Payments`, one `<p>` per lettered paragraph (a)–(g) with the canonical text above.
3. Change the Contact heading to `23. Contact Information`.
4. Search the file for any anchor/id or table-of-contents referencing section 22 (`grep -n "section-22\|#22\|Section 22" pages/legal/terms.vue`) and update.

`utils/legal.ts:8` → `export const CURRENT_TERMS_VERSION = "2026-09-03";`. Update its doc comment to say the Privacy page keeps its own date.

- [ ] **Step 6: Web — tests + lint**

Run: `grep -rl "CURRENT_TERMS_VERSION\|2026-08-16" tests/ | head`; update any assertion on the version string to `"2026-09-03"`. Then `npx vitest run tests/unit/utils/legal* tests/unit/pages/legal 2>/dev/null; npx eslint pages/legal/terms.vue utils/legal.ts`.
Expected: PASS / clean. Note: bumping `CURRENT_TERMS_VERSION` may re-prompt guardian acceptance for minors' accounts — acceptable pre-launch; confirm by grepping `CURRENT_TERMS_VERSION` usages and reading the comparison logic once.

- [ ] **Step 7: Web — commit**

```bash
git add pages/legal/terms.vue utils/legal.ts
git commit -m "docs(legal): add Subscriptions and Payments to Terms (§22), bump terms version

Claude-Session: https://claude.ai/code/session_01BdCVhhV2h7f8seTSWX2YyX"
```

---

### Task 9: Landing site copy — founding offer

**Files:**
- Modify: `recruiting-compass-landing/pages/index.vue` (faqs[0] L43-46; JSON-LD `offers` L101), `components/sections/FaqSection.vue` (faqs[0] L44-48), `components/sections/CtaSection.vue` (card 2, L38-40)

- [ ] **Step 1: Branch**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-landing && git branch --show-current
git worktree add .worktrees/feat-founding-pricing-copy -b feat/founding-pricing-copy HEAD
cd .worktrees/feat-founding-pricing-copy && pwd
```

- [ ] **Step 2: Write the failing test**

Create `tests/pricingCopy.spec.ts`:

```ts
import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";

const read = (p: string) => readFileSync(new URL(`../${p}`, import.meta.url), "utf8");

describe("pricing copy is consistent", () => {
  const faqAnswer =
    "It's free right now. Every family that signs up during our founding period keeps full access free for life — no card, no catch. After the founding window closes, new families get a 30-day free trial, then $99/year or $12.99/month for the whole family.";

  it("FAQ answer matches in both copies", () => {
    expect(read("components/sections/FaqSection.vue")).toContain(faqAnswer);
    expect(read("pages/index.vue")).toContain(faqAnswer);
  });

  it("no stale pricing lines remain", () => {
    for (const file of [
      "pages/index.vue",
      "components/sections/FaqSection.vue",
      "components/sections/CtaSection.vue",
    ]) {
      const src = read(file);
      expect(src).not.toContain("still finalizing pricing");
      expect(src).not.toContain("Special pricing for early survey participants");
      expect(src).not.toContain('price: "0"');
    }
  });

  it("CTA card advertises free for life", () => {
    expect(read("components/sections/CtaSection.vue")).toContain("Free for Life");
  });
});
```

- [ ] **Step 3: Run to verify failure**

Run: `npx vitest run tests/pricingCopy.spec.ts`
Expected: FAIL on all three.

- [ ] **Step 4: Edit copy**

1. `components/sections/FaqSection.vue` faqs[0] and `pages/index.vue` faqs[0]: keep the question `How much does The Recruiting Compass cost?`; set `answer` to the exact `faqAnswer` string from the test.
2. `pages/index.vue` L101: delete the `offers: { price: "0", priceCurrency: "USD" },` line entirely (do not replace with a price — schema.org `offers` will be added at flip with the real price).
3. `components/sections/CtaSection.vue` card 2: title `Exclusive Discounts` → `Free for Life`; body `Special pricing for early survey participants.` → `Founding families keep full access free, forever. No card required.`
4. Grep for other stale mentions: `grep -rn "free\b\|pricing\|\$[0-9]" components pages --include=*.vue -i | grep -v node_modules` — only touch lines that state or imply a price; leave feature copy alone.

- [ ] **Step 5: Run test, lint, typecheck**

Run: `npx vitest run tests/pricingCopy.spec.ts && npx eslint . && npx nuxi typecheck`
Expected: PASS / clean.

- [ ] **Step 6: Commit**

```bash
git add tests/pricingCopy.spec.ts pages/index.vue components/sections/FaqSection.vue components/sections/CtaSection.vue
git commit -m "chore(copy): founding-family free-for-life offer, drop free-price schema

Claude-Session: https://claude.ai/code/session_01BdCVhhV2h7f8seTSWX2YyX"
```

---

### Task 10: Docs — submission plan, business plan §4, spec correction, web DB notes

**Files:**
- Modify (iOS repo): `planning/app-store-submission-plan.md:197-198`, `planning/business-plan-update-recommendations.md:229-243`, `planning/2026-09-03-pricing-model-and-entitlement-plumbing-spec.md` (§2.1 header line and Phase 0 item 1)
- Modify (web repo): `claude/database.md` (helper-functions list near L120)

- [ ] **Step 1: App Store submission plan**

Replace L197-198:

```
NO IN-APP PURCHASES:
This build contains no in-app purchases or subscriptions; every feature is
available at no charge. Paid family subscriptions may be added in a future
release via In-App Purchase.
```

- [ ] **Step 2: Business plan §4 rewrite**

Replace the whole `### 4. BUSINESS MODEL — Still Placeholder` section (L229-243) with:

```markdown
### 4. BUSINESS MODEL — Decided 2026-09-03

**Model:** Family subscription, annual-anchored. Working price **$99/year or $12.99/month**, one subscription covers every member of a family unit. 30-day full-access free trial, then read-only (data preserved, public profile dark) until subscribed. No permanent free tier.

**Launch posture:** Launch free with entitlement plumbing in place (`family_subscriptions`, `family_can_write` RLS gate). Every family created before the pricing flip is a **Founding Family — free for life**. Flip trigger: 90 days after App Store approval or 50 active families, whichever first.

**Rails:** RevenueCat (StoreKit on iOS, Stripe web billing on web), same price everywhere. Apple Small Business Program (15%).

**Founding-period economics:** $0 revenue by design; goal is testimonials + willingness-to-pay signal before flip. Price to be re-validated against FieldLevel/NextUp/NCSA at flip.

Full decision log and architecture: `planning/2026-09-03-pricing-model-and-entitlement-plumbing-spec.md`.
```

Also update the Roadmap item that reads "Monetization launch — Stripe, pricing page, tier enforcement" to "Monetization flip — RevenueCat, paywall, read-only mode (Phase 1/2 of the pricing spec)".

- [ ] **Step 3: Spec correction**

In `2026-09-03-pricing-model-and-entitlement-plumbing-spec.md`:
- §2.1 heading paragraph: `### 2.1 Schema` → add a first line: `Migration lives in the **web repo only** (`recruiting-compass-web/supabase/migrations/`); the iOS repo's migrations dir is a stale slice and is not updated.`
- §2.2 first bullet: replace "INSERT / UPDATE / DELETE policies gain `AND family_can_write(family_unit_id)`" with "gain one `RESTRICTIVE` policy per verb (`<table>_<verb>_requires_entitlement`) calling `family_can_write(family_unit_id)`; existing permissive policies are untouched."
- §3 Phase 0 item 1: delete "Mirrored to both repos' `supabase/migrations/`."
- §4 Testing: replace "SQL (pgTAP or migration test script)" with "Live-DB Vitest integration spec (`tests/integration/rls/rls-family-subscriptions.integration.spec.ts`)".
- §2.1 function body: note that `NULL` family id returns `true` (non-family-scoped rows are not gated).

- [ ] **Step 4: Web DB notes**

In `recruiting-compass-web/claude/database.md`, in the helper-functions list, add:
`- `family_can_write(p_family_unit_id uuid) → boolean` — entitlement gate; STABLE SECURITY DEFINER; used by `*_requires_entitlement` RESTRICTIVE policies on family content tables. NULL → true. Mirror in `composables/useEntitlement.ts` and iOS `FamilySubscription.canWrite`.`
And under tables: `family_subscriptions` (1:1 with `family_units`, service-role writes only) and `app_config` (single row; `pricing_flip_at` NULL = pre-flip).

- [ ] **Step 5: Commit (two repos)**

```bash
# iOS worktree
git add planning/app-store-submission-plan.md planning/business-plan-update-recommendations.md planning/2026-09-03-pricing-model-and-entitlement-plumbing-spec.md
git commit -m "docs: align submission plan, business model, and spec with entitlement plumbing

Claude-Session: https://claude.ai/code/session_01BdCVhhV2h7f8seTSWX2YyX"
# web worktree
git add claude/database.md
git commit -m "docs(db): document family_subscriptions, app_config, family_can_write

Claude-Session: https://claude.ai/code/session_01BdCVhhV2h7f8seTSWX2YyX"
```

---

### Task 11: Ship — full gates, PRs, apply migration to prod

- [ ] **Step 1: Web full gate**

In the web worktree: `npx vitest run && npx nuxi typecheck && npx eslint .`
Expected: green. Then push and open PR to `develop` with the `ship` skill. PR body: link the spec, list the 15 gated tables, state "no behaviour change: all families backfilled `founding`".

- [ ] **Step 2: iOS full gate**

In the iOS worktree: `xcodebuild build … -quiet` then run `EntitlementStoreTests`, `FamilySubscriptionTests`, and every test class that references `SettingsView` or `TermsOfService`. SwiftLint: `swiftlint lint --config .swiftlint.yml --strict` on changed files. Push and open PR to `main` via `ship`.

- [ ] **Step 3: Landing gate + PR**

`npx vitest run && npx eslint . && npx nuxi typecheck`; push; PR to its default branch via `ship`.

- [ ] **Step 4: Apply migration to prod (after web PR merges)**

Confirm with Chris first ("Ready to run?"). Then `npx supabase db push` from the web repo against the linked prod project, or `mcp__claude_ai_Supabase__apply_migration` with the file content. Verify:

```sql
select status, count(*) from public.family_subscriptions group by 1;      -- all 'founding'
select count(*) from public.family_units f
  left join public.family_subscriptions s on s.family_unit_id = f.id
  where s.family_unit_id is null;                                        -- 0
select public.family_can_write(id) from public.family_units limit 5;     -- all true
```

Then run `mcp__claude_ai_Supabase__get_advisors` (security) and confirm no new findings on the two tables.

- [ ] **Step 5: Device QA + memory**

On device: Settings → Plan shows founding label; create a school/coach/interaction still works (gate open). Web: `/settings` card + `/settings/plan`. Then save a memory note `family-entitlement-plumbing-shipped.md` and add the MEMORY.md pointer; remove the worktrees.

---

## Self-review

- **Spec coverage:** §1 decisions 1–12 → Tasks 1 (unit, trial clock, founding, gate), 4/7 (decision 11 subtle row), 8 (decision 12 ToS), 9 (landing), 10 (docs). §2.1 schema → Task 1. §2.2 RLS → Task 1 (restrictive form; spec corrected in Task 10). §2.3 clients → Tasks 3–7. §2.4 public profile → Phase 1, intentionally absent. §2.5 stores → Phase 1, absent. §3 Phase 0 items 1–6 → Tasks 1–10; item 7 (Small Business Program) is Chris's, listed in Global note only. §4 testing → Tasks 1, 3, 4, 5, 6.
- **Placeholders:** none. Every code step has full content. The two "if the project differs" notes in Task 6 Step 3 and Task 2 Step 1 point to a concrete existing file to copy from.
- **Type consistency:** `FamilySubscription` fields (`familyUnitId, status, source, trialEndsAt, currentPeriodEnd`) identical across Task 5 model, Task 6 tests, Task 3 TS interface. Statuses `read_only`/`.readOnly` mapped via raw value. `PlanLabel.unavailable` used in Tasks 5–6. `EntitlementStore.load(familyUnitId:)` signature identical in Tasks 6–7. Policy names `<table>_<verb>_requires_entitlement` consistent between Task 1 and Task 10.

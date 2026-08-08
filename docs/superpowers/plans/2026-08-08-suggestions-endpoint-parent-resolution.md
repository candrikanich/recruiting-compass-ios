# Suggestions Endpoint Parent→Athlete Resolution (web) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Let a parent's dismiss/complete of an action item persist by resolving the parent to their linked player before scoping the update.

**Architecture:** Extract the parent→player resolution currently inlined in `GET /api/suggestions` into a shared `resolveAthleteId` helper; use it in the dismiss and complete PATCH endpoints (which today scope `.eq("athlete_id", user.id)` and silently no-op for parents). The server Supabase client is service-role, so resolving the id is the sole, sufficient scope guard.

**Tech Stack:** Nuxt 3 / h3 server routes, Supabase JS, Vitest.

**Repo:** `recruiting-compass-web`.

## Global Constraints

- **BLOCKED until the shared web checkout is free.** As of 2026-08-08 the checkout sits on branch `feat/coach-outreach-templates` with another session's uncommitted work. Do NOT branch-switch or commit into that tree. Start this plan only once the comms session has landed and the working tree is clean (or a dedicated worktree exists).
- Run tests with `npx vitest run <path>`.
- No DB migration — behavior change only.

---

### Task 1: Extract `resolveAthleteId` helper

**Files:**
- Create: `server/utils/resolveAthleteId.ts`
- Modify: `server/api/suggestions/index.get.ts:21-44` (replace inline block with the helper)
- Test: `tests/unit/server/utils/resolveAthleteId.spec.ts`

**Interfaces:**
- Produces: `export async function resolveAthleteId(userId: string, supabase: SupabaseClient): Promise<string>` — returns `userId` for players; for a parent, returns the family's `player` member's `user_id`; falls back to `userId` when unresolved.

- [ ] **Step 1: Write the failing test**

```ts
import { describe, it, expect, vi } from "vitest";
import { resolveAthleteId } from "~/server/utils/resolveAthleteId";

function mockSupabase(roleRow: unknown, parentRow: unknown, playerRow: unknown) {
  const calls: Record<string, unknown[]> = {};
  const from = (table: string) => {
    const builder: Record<string, unknown> = {};
    const chain = () => builder;
    Object.assign(builder, {
      select: chain, eq: chain,
      maybeSingle: () =>
        Promise.resolve({
          data:
            table === "users" ? roleRow
            : table === "family_members"
              ? (calls.fm ? playerRow : ((calls.fm = [1]), parentRow))
              : null,
        }),
      single: () => Promise.resolve({ data: roleRow }),
    });
    return builder;
  };
  return { from } as never;
}

describe("resolveAthleteId", () => {
  it("returns the user id for a player", async () => {
    const sb = mockSupabase({ role: "player" }, null, null);
    expect(await resolveAthleteId("player-1", sb)).toBe("player-1");
  });

  it("resolves a parent to the linked player", async () => {
    const sb = mockSupabase(
      { role: "parent" },
      { family_unit_id: "fam-1" },
      { user_id: "player-9" }
    );
    expect(await resolveAthleteId("parent-1", sb)).toBe("player-9");
  });

  it("falls back to the user id when a parent has no family", async () => {
    const sb = mockSupabase({ role: "parent" }, null, null);
    expect(await resolveAthleteId("parent-1", sb)).toBe("parent-1");
  });
});
```

Adjust the mock to match how `index.get.ts` currently determines role (it calls `getUserRole(user.id, supabase)`; the helper should call the same `getUserRole`). If `getUserRole` is a separate util, mock it with `vi.mock` instead of the `users` table read. Inspect `index.get.ts:21-44` and `server/utils/auth.ts` first and mirror exactly.

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run tests/unit/server/utils/resolveAthleteId.spec.ts`
Expected: FAIL — module not found.

- [ ] **Step 3: Create the helper**

Port the exact logic from `index.get.ts:21-44` (role check via `getUserRole`; parent → `family_members` role `parent` → `family_unit_id` → `family_members` role `player` → `user_id`).

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import { getUserRole } from "~/server/utils/auth";

export async function resolveAthleteId(
  userId: string,
  supabase: SupabaseClient,
): Promise<string> {
  const role = await getUserRole(userId, supabase);
  if (role !== "parent") return userId;

  const { data: parentMembership } = await supabase
    .from("family_members")
    .select("family_unit_id")
    .eq("user_id", userId)
    .eq("role", "parent")
    .maybeSingle();
  if (!parentMembership) return userId;

  const { data: playerMember } = await supabase
    .from("family_members")
    .select("user_id")
    .eq("family_unit_id", parentMembership.family_unit_id)
    .eq("role", "player")
    .maybeSingle();

  return playerMember?.user_id ?? userId;
}
```

- [ ] **Step 4: Replace the inline block in `index.get.ts`**

Swap lines 21-44 for:

```ts
    const athleteId = await resolveAthleteId(user.id, supabase);
```

and add the import. Behavior is unchanged (verify existing suggestions tests still pass).

- [ ] **Step 5: Run tests**

Run: `npx vitest run tests/unit/server/utils/resolveAthleteId.spec.ts tests/unit/server/api/suggestions`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add server/utils/resolveAthleteId.ts server/api/suggestions/index.get.ts tests/unit/server/utils/resolveAthleteId.spec.ts
git commit -m "refactor: extract resolveAthleteId helper from suggestions GET"
```

---

### Task 2: Use resolution in dismiss + complete endpoints

**Files:**
- Modify: `server/api/suggestions/[id]/dismiss.patch.ts:25-29`
- Modify: `server/api/suggestions/[id]/complete.patch.ts` (analogous update block)
- Test: `tests/unit/server/api/suggestions/dismiss-complete-parent.spec.ts`

**Interfaces:**
- Consumes: `resolveAthleteId` (Task 1).

- [ ] **Step 1: Write the failing test**

Assert the update is scoped to the resolved player id when a parent calls. Mirror the existing suggestions endpoint test setup (check `tests/unit/server/api/suggestions/` for the harness that invokes these handlers and mocks `requireAuth`/supabase). Skeleton:

```ts
import { describe, it, expect, vi } from "vitest";

vi.mock("~/server/utils/resolveAthleteId", () => ({
  resolveAthleteId: vi.fn().mockResolvedValue("player-9"),
}));

// ... import the handler and a supabase mock that records .eq("athlete_id", <id>)
// Invoke as a parent; assert the recorded athlete_id === "player-9".
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run tests/unit/server/api/suggestions/dismiss-complete-parent.spec.ts`
Expected: FAIL — endpoints still scope by `user.id`.

- [ ] **Step 3: Update both endpoints**

In `dismiss.patch.ts`, after `const user = await requireAuth(event);` and the client creation, add:

```ts
    const athleteId = await resolveAthleteId(user.id, supabase);
```

and change `.eq("athlete_id", user.id)` → `.eq("athlete_id", athleteId)`. Keep audit-log `userId: user.id` (who acted). Apply the identical change in `complete.patch.ts`.

- [ ] **Step 4: Run tests**

Run: `npx vitest run tests/unit/server/api/suggestions`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add server/api/suggestions/[id]/dismiss.patch.ts server/api/suggestions/[id]/complete.patch.ts tests/unit/server/api/suggestions/dismiss-complete-parent.spec.ts
git commit -m "fix: resolve parent to athlete when dismissing/completing suggestions"
```

---

## Self-Review

**Spec coverage:** helper extraction (T1), dismiss+complete resolution (T2), index.get.ts reuse (T1). ✓
**Placeholder scan:** the two endpoint/helper tests reference the existing suggestions test harness by instruction rather than inventing one — the codebase's current mock must be matched. Handler logic and endpoint edits carry concrete code.
**Type consistency:** `resolveAthleteId(userId, supabase): Promise<string>` consistent across T1 definition and T2 consumption.

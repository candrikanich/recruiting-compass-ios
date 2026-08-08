# Video Links — Phase B (Web) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the web app read/write the canonical `public.video_links` table everywhere video appears — CRUD API, suggestion rules, action-item CTAs, the settings editor, a link-health cron, coach-comms template variables, and packet/public-profile — so video action items are completable and video reaches coaches.

**Architecture:** Nuxt 3 app in the `feat/video-links` worktree (same branch as Phase A, so migrations + app code ship together). New `/api/video-links` per-row CRUD (service-role client with explicit owner/family filters, player-write guard). Repoint every current video reader (rules read a non-existent `videos` table; editor/packet/profile read `user_preferences.data.video_links` JSONB) at the new table. A Vercel cron marks links healthy/broken.

**Tech Stack:** Nuxt 3 / Nitro (`server/api`), Vue 3 `<script setup>`, Supabase JS, zod, Vitest (happy-dom), Vercel crons.

## Global Constraints

- Work in worktree `/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web/.worktrees/video-links`, branch `feat/video-links`. Commit there. Local Supabase stack must be up (`supabase status`); psql only via container: `docker exec -i supabase_db_recruiting-compass-web psql -U postgres -X`.
- `video_links` columns (Phase A, authoritative): `id, user_id, family_unit_id, platform (hudl|youtube|vimeo), url, title, position, health_status (healthy|broken|unknown), last_health_check, created_at, updated_at`. Max 5 per user (DB trigger backstop). RLS: owner-or-family SELECT, owning-player write.
- `createServerSupabaseClient()` is **service-role → bypasses RLS**. Every route MUST add explicit `.eq("user_id", …)` / family filters — never rely on RLS on the server.
- Player-write guard: `assertNotParent(userId, supabase)` (`server/utils/auth.ts:240`) throws 403. Use on POST/PATCH/DELETE.
- Auth: `requireAuth(event)` (`server/utils/auth.ts:40`) → `{id,email,…}`.
- Zod schemas live in `utils/validation/schemas.ts` (`.safeParse` → 422 on failure).
- Tests: Vitest, `vitest.config.ts`; server-route mock pattern from `tests/unit/server/api/cron/daily-suggestions.spec.ts`; component pattern from `tests/unit/components/Suggestion/SuggestionCard.spec.ts`. Run: `npx vitest run <path>`.
- Platform/health string values must match the DB CHECKs exactly.
- Do NOT drop `user_preferences.data.video_links` in this phase — a later cleanup migration does, once every reader is cut over (all readers are cut over by end of this plan, but the drop stays out of scope here).

---

### Task 1: Extend `VideoLink` type + zod schemas

**Files:**
- Modify: `types/models.ts:357-361` (the `VideoLink` type)
- Modify: `utils/validation/schemas.ts` (add create/update schemas near the other resource schemas, e.g. after `createDeadlineSchema`)
- Test: `tests/unit/utils/validation/videoLinks.spec.ts` (create)

**Interfaces:**
- Produces: `VideoLinkRow` (full table row) and `VideoLink` (kept as the display shape `{platform,url,title}` for packet/profile back-comat); `createVideoLinkSchema`, `updateVideoLinkSchema`, and their `z.infer` types.

- [ ] **Step 1: Write failing schema test**

```ts
// tests/unit/utils/validation/videoLinks.spec.ts
import { describe, it, expect } from "vitest";
import { createVideoLinkSchema, updateVideoLinkSchema } from "~/utils/validation/schemas";

describe("video-link schemas", () => {
  it("accepts a valid create payload", () => {
    const r = createVideoLinkSchema.safeParse({ platform: "hudl", url: "https://hudl.com/x", title: "Fall reel", position: 0 });
    expect(r.success).toBe(true);
  });
  it("rejects an unknown platform", () => {
    expect(createVideoLinkSchema.safeParse({ platform: "tiktok", url: "https://x", position: 0 }).success).toBe(false);
  });
  it("rejects a non-URL", () => {
    expect(createVideoLinkSchema.safeParse({ platform: "hudl", url: "not-a-url", position: 0 }).success).toBe(false);
  });
  it("update allows partial fields", () => {
    expect(updateVideoLinkSchema.safeParse({ title: "New" }).success).toBe(true);
  });
});
```

- [ ] **Step 2: Run — expect fail** `npx vitest run tests/unit/utils/validation/videoLinks.spec.ts` → FAIL (schemas undefined).

- [ ] **Step 3: Implement**

In `utils/validation/schemas.ts`:
```ts
export const videoPlatformEnum = z.enum(["hudl", "youtube", "vimeo"]);
export const createVideoLinkSchema = z.object({
  platform: videoPlatformEnum,
  url: z.string().url().max(2048),
  title: z.string().max(200).optional(),
  position: z.number().int().min(0).max(4).optional(),
});
export const updateVideoLinkSchema = z.object({
  platform: videoPlatformEnum.optional(),
  url: z.string().url().max(2048).optional(),
  title: z.string().max(200).nullable().optional(),
  position: z.number().int().min(0).max(4).optional(),
}).refine((o) => Object.keys(o).length > 0, { message: "At least one field required" });
export type CreateVideoLinkInput = z.infer<typeof createVideoLinkSchema>;
export type UpdateVideoLinkInput = z.infer<typeof updateVideoLinkSchema>;
```
In `types/models.ts`, keep `VideoLink` as-is (display shape) and add:
```ts
export interface VideoLinkRow {
  id: string; user_id: string; family_unit_id: string | null;
  platform: "hudl" | "youtube" | "vimeo"; url: string; title: string | null;
  position: number; health_status: "healthy" | "broken" | "unknown";
  last_health_check: string | null; created_at: string; updated_at: string;
}
```

- [ ] **Step 4: Run — expect pass.** `npx vitest run tests/unit/utils/validation/videoLinks.spec.ts`

- [ ] **Step 5: Commit** `feat(web): add VideoLinkRow type + video-link zod schemas`

---

### Task 2: `/api/video-links` CRUD

**Files:**
- Create: `server/api/video-links/index.get.ts`, `index.post.ts`, `[id].patch.ts`, `[id].delete.ts`
- Test: `tests/unit/server/api/video-links/crud.spec.ts` (create)

**Interfaces:**
- Consumes: `requireAuth`, `assertNotParent`, `createServerSupabaseClient`, schemas from Task 1.
- Produces: `GET /api/video-links` → `{ videoLinks: VideoLinkRow[] }` (caller's own + family, ordered by `position`); `POST` → `{ videoLink }` (201-ish); `PATCH /api/video-links/:id`; `DELETE /api/video-links/:id`. Consumed by Tasks 4/5/7 and iOS Phase C.

- [ ] **Step 1: Write failing route tests** (mirror `tests/unit/server/api/cron/daily-suggestions.spec.ts` mock style — `vi.mock` supabase, unwrap `defineEventHandler`, stub `requireAuth`/`assertNotParent`). Cover: GET returns rows filtered by `user_id`; POST rejects a parent (403 via `assertNotParent`); POST validates body (422 on bad platform); DELETE enforces ownership (404 when row not owned).

```ts
// tests/unit/server/api/video-links/crud.spec.ts  (abbreviated — write all four cases)
import { describe, it, expect, vi, beforeEach } from "vitest";
const mockSupabase = { from: vi.fn() };
vi.mock("~/server/utils/supabase", () => ({ createServerSupabaseClient: () => mockSupabase }));
vi.mock("~/server/utils/auth", () => ({
  requireAuth: vi.fn(async () => ({ id: "user-1", email: "p@t" })),
  assertNotParent: vi.fn(async () => {}),
}));
vi.mock("~/server/utils/logger", () => ({ useLogger: () => ({ info: vi.fn(), error: vi.fn(), warn: vi.fn() }) }));
vi.mock("h3", async (o) => { const a = await o<typeof import("h3")>(); return { ...a, defineEventHandler: (f:any)=>f }; });
(globalThis as any).createError = (c:any) => { const e:any = new Error(c.statusMessage||c.message); e.statusCode=c.statusCode; return e; };

beforeEach(() => { vi.clearAllMocks(); });

it("GET returns caller's video links ordered by position", async () => {
  mockSupabase.from.mockReturnValue({ select: () => ({ or: () => ({ order: () => Promise.resolve({ data: [{ id:"v1", position:0 }], error:null }) }) }) });
  const handler = (await import("~/server/api/video-links/index.get")).default;
  const res = await handler({ /* event */ } as any);
  expect(res.videoLinks).toHaveLength(1);
});
```

- [ ] **Step 2: Run — expect fail** (`Cannot find module …/index.get`).

- [ ] **Step 3: Implement the four handlers.**

`index.get.ts` — owner OR family read (service-role, so filter explicitly). Resolve the caller's family_unit_ids once, then `.or(...)`:
```ts
export default defineEventHandler(async (event) => {
  const logger = useLogger(event, "video-links/list");
  try {
    const user = await requireAuth(event);
    const supabase = createServerSupabaseClient();
    const { data: fams } = await supabase.from("family_members").select("family_unit_id").eq("user_id", user.id);
    const familyIds = (fams ?? []).map((f) => f.family_unit_id).filter(Boolean);
    let query = supabase.from("video_links").select("*");
    query = familyIds.length
      ? query.or(`user_id.eq.${user.id},family_unit_id.in.(${familyIds.join(",")})`)
      : query.eq("user_id", user.id);
    const { data, error } = await query.order("position", { ascending: true });
    if (error) throw createError({ statusCode: 500, statusMessage: "Failed to load video links" });
    return { videoLinks: data ?? [] };
  } catch (err) { if (err instanceof Error && "statusCode" in err) throw err; logger.error("list failed", err); throw createError({ statusCode: 500, statusMessage: "Failed to load video links" }); }
});
```
`index.post.ts` — player-only, max-5 pre-check (friendly 409 before the DB trigger), resolve `family_unit_id` from the player's `family_members` row, default `position` to current count:
```ts
const user = await requireAuth(event);
const supabase = createServerSupabaseClient();
await assertNotParent(user.id, supabase);                       // 403 if parent
const parsed = createVideoLinkSchema.safeParse(await readBody(event));
if (!parsed.success) throw createError({ statusCode: 422, statusMessage: parsed.error.issues[0].message });
const { count } = await supabase.from("video_links").select("id", { count: "exact", head: true }).eq("user_id", user.id);
if ((count ?? 0) >= 5) throw createError({ statusCode: 409, statusMessage: "Maximum of 5 video links reached" });
const { data: fam } = await supabase.from("family_members").select("family_unit_id").eq("user_id", user.id).eq("role", "player").maybeSingle();
const insert = { user_id: user.id, family_unit_id: fam?.family_unit_id ?? null, platform: parsed.data.platform, url: parsed.data.url, title: parsed.data.title ?? null, position: parsed.data.position ?? (count ?? 0) };
const { data, error } = await supabase.from("video_links").insert(insert).select().single();
if (error) throw createError({ statusCode: 500, statusMessage: "Failed to create video link" });
return { videoLink: data };
```
`[id].patch.ts` — `requireUuidParam(event,"id")` (see `athlete-tasks/[taskId].patch.ts`), `assertNotParent`, `updateVideoLinkSchema`, ownership `.eq("id",id).eq("user_id",user.id)` on the update; 404 if no row updated. Editing a url should reset health so the cron re-checks: when `url` present in the patch, also set `health_status:"unknown", last_health_check:null`.
`[id].delete.ts` — mirror `deadlines/[id].delete.ts:11-64`: ownership `maybeSingle` check → 404 if not owned → delete.

- [ ] **Step 4: Run — expect pass.** `npx vitest run tests/unit/server/api/video-links/`

- [ ] **Step 5: Commit** `feat(web): video-links CRUD API (owner/family read, player-only writes, max-5)`

---

### Task 3: Repoint suggestion rules to `video_links`

**Files:**
- Modify: `server/api/suggestions/evaluate.post.ts:42, 80-84, 105` (the `videosSelect` + `(supabase as any).from("videos")` cast)
- Modify: `server/utils/triggerSuggestionUpdate.ts` (same `.from("videos")` cast — grep to confirm exact lines)
- Modify (only if needed): `server/utils/rules/videoLinkHealth.ts` message uses `title` — the table has `title`, so likely no change; confirm.
- Test: `tests/unit/server/utils/rules/videoRules.spec.ts` (create; mirror existing `rules/` tests)

**Interfaces:**
- Consumes: `video_links` table, `RuleContext.videos` (`server/utils/rules/index.ts:5`).
- Produces: `context.videos` populated from `video_links` for the athlete; `missingVideoRule`/`videoLinkHealthRule` fire on real data.

**Risk to resolve first:** the old query filtered `videos.athlete_id`; `video_links` keys on `user_id` (the player's auth user). In `evaluate.post.ts`, determine what `athleteId` is — if it is the player's `user_id`, filter `video_links.eq("user_id", athleteId)`; if it is a `player_profiles`/`family_members` id, resolve to the player `user_id` first (look at how `athleteId` is derived earlier in the file, ~`:20-60`). Document the resolved mapping in the commit message.

- [ ] **Step 1: Write failing rule tests** — construct a `RuleContext` with `videos: [{ health_status: "broken", title: "Reel" }]` → `videoLinkHealthRule` returns an `update_video` suggestion; `videos: []` + `athlete.grade_level: 11` → `missingVideoRule` returns `add_video`; `videos:[{health_status:"healthy"}]` → both return null. (These test the rules directly; they already exist logically — if `tests/unit/server/utils/rules/` already covers them, extend rather than duplicate.)

- [ ] **Step 2: Run — expect fail** (new assertions) `npx vitest run tests/unit/server/utils/rules/videoRules.spec.ts`

- [ ] **Step 3: Implement the repoint.** In `evaluate.post.ts`:
```ts
const videosSelect = "id, health_status, title";  // columns exist on video_links
// was: (supabase as any).from("videos").select(videosSelect).eq("athlete_id", athleteId)
const videos = await supabase.from("video_links").select(videosSelect).eq("user_id", athletePlayerUserId);
```
Replace the `as any` cast (the table is now in the schema; regenerate types if the repo commits `Database` types — check `types/database.ts` / `supabase gen types`). Apply the identical change in `triggerSuggestionUpdate.ts`. If the rules themselves need no change (title/health_status already match), leave them.

- [ ] **Step 4: Run — expect pass.** `npx vitest run tests/unit/server/utils/rules/`

- [ ] **Step 5: Commit** `fix(web): suggestion rules read video_links table (drop phantom videos cast)`

---

### Task 4: Fix SuggestionCard CTAs + player-details `?tab=` deep-link

**Files:**
- Modify: `components/Suggestion/SuggestionCard.vue:147-164` (the `add_video`/`update_video` navigate targets)
- Modify: `pages/settings/player-details.vue:348-359` (add `route.query.tab` → `currentTab` wiring)
- Test: `tests/unit/components/Suggestion/SuggestionCard.spec.ts` (extend)

**Interfaces:**
- Produces: `add_video`/`update_video` CTAs navigate to `/settings/player-details?tab=athletics`; that page opens on the Athletics tab.

- [ ] **Step 1: Write failing tests** — extend the SuggestionCard spec: mounting with `action_type: "add_video"` and clicking the CTA calls `navigateTo("/settings/player-details?tab=athletics")` (not `/videos`). (Reuse the existing `vi.mock("#app", …navigateTo)` in the file.)

- [ ] **Step 2: Run — expect fail.**

- [ ] **Step 3: Implement.**
In `SuggestionCard.vue`:
```ts
case "add_video":
case "update_video":
  navigateTo("/settings/player-details?tab=athletics"); break;
```
In `pages/settings/player-details.vue`, make the tab honor the query param:
```ts
const route = useRoute();
const validTabs = ["basics", "athletics", /* …existing ids from :349-359 */];
const currentTab = ref(validTabs.includes(route.query.tab as string) ? (route.query.tab as string) : "basics");
```
(Keep existing tab-switch behavior otherwise.)

- [ ] **Step 4: Run — expect pass.** `npx vitest run tests/unit/components/Suggestion/SuggestionCard.spec.ts`

- [ ] **Step 5: Commit** `fix(web): video CTAs open player-details Athletics tab (kill dead /videos link)`

---

### Task 5: Migrate the settings editor from JSONB to the API

**Files:**
- Modify: `components/Settings/PlayerDetailsAthleticsTab.vue:195-294` (video section)
- Modify: `composables/usePlayerDetailsForm.ts:87,104-117,163-175,288` (video_links load/add/remove/save)
- Modify: `composables/usePreferenceManager.ts:197-219` (stop merging `video_links` into player JSONB)
- Create: `composables/useVideoLinks.ts` (thin client over `/api/video-links`)
- Test: `tests/unit/composables/useVideoLinks.spec.ts` (create)

**Interfaces:**
- Consumes: `/api/video-links` (Task 2).
- Produces: `useVideoLinks()` → `{ links, load, add, update, remove }`; the Athletics tab edits links via per-row API calls; `video_links` no longer travels in the player-details JSONB.

**Design note:** per-row CRUD (not a bulk JSONB save) so the cron-written `health_status`/`last_health_check` survive edits. `add` → POST; field blur → PATCH that row; remove → DELETE; the max-5 "Add" hide stays.

- [ ] **Step 1: Write failing composable test** — `useVideoLinks().add(...)` POSTs to `/api/video-links` and appends the returned row; `remove(id)` DELETEs and drops it. Mock `$fetch`.

- [ ] **Step 2: Run — expect fail.**

- [ ] **Step 3: Implement** `useVideoLinks.ts` (`$fetch` GET/POST/PATCH/DELETE, local reactive `links`), rewire the Athletics tab to use it, and remove `video_links` from `usePlayerDetailsForm` (`:87,288`) and from the `setPlayerDetails` merge in `usePreferenceManager` (`:197-219`). Load links via `useVideoLinks().load()` on tab mount.

- [ ] **Step 4: Run — expect pass** (composable test + existing player-details tests still green): `npx vitest run tests/unit/composables/useVideoLinks.spec.ts` and any `usePlayerDetailsForm`/settings specs.

- [ ] **Step 5: Commit** `feat(web): edit video links via API, preserving link health across edits`

---

### Task 6: Link-health cron

**Files:**
- Create: `server/api/cron/video-health-check.get.ts`
- Modify: `vercel.json` (add a `crons` entry)
- Test: `tests/unit/server/api/cron/video-health-check.spec.ts` (create)

**Interfaces:**
- Consumes: `video_links` table, `verifySharedSecret`/`CRON_SECRET` (`server/utils/secrets.ts`, pattern in `daily-suggestions.get.ts:28-45`).
- Produces: each link's `health_status` (`healthy` on 2xx/3xx, `broken` otherwise) + `last_health_check`.

- [ ] **Step 1: Write failing test** — mirror `daily-suggestions.spec.ts`: rejects without the secret (401); with the secret, fetches each link, and a non-OK URL results in an update setting `health_status:"broken"`. Mock global `fetch` and the supabase update chain.

- [ ] **Step 2: Run — expect fail.**

- [ ] **Step 3: Implement.** Secret gate (copy `daily-suggestions.get.ts:28-45`), select links needing a check (`.or("last_health_check.is.null,health_status.neq.healthy")` plus a periodic full sweep is fine at this scale — select all, batched), `HEAD` each url with a timeout, `PATCH` `health_status`/`last_health_check`. Add to `vercel.json`:
```json
{ "path": "/api/cron/video-health-check", "schedule": "0 6 * * *" }
```

- [ ] **Step 4: Run — expect pass.** `npx vitest run tests/unit/server/api/cron/video-health-check.spec.ts`

- [ ] **Step 5: Commit** `feat(web): daily video-link health-check cron`

---

### Task 7: Coach-comms template variable

**Files:**
- Modify: `utils/templateVariables.ts:13-80` (add a variable)
- Modify: `components/TemplateSendModal.vue:213-227` (populate it from video links)
- Test: `tests/unit/utils/templateVariables.spec.ts` (extend or create) + a TemplateSendModal interpolation test if one exists

**Interfaces:**
- Consumes: `/api/video-links` (Task 2) / `useVideoLinks` (Task 5).
- Produces: `{{highlightVideo}}` (primary healthy link URL) and `{{filmLinks}}` (all links, `Title (PLATFORM): url` newline-joined) available in coach templates.

- [ ] **Step 1: Write failing test** — `AVAILABLE_VARIABLES` contains `highlightVideo` and `filmLinks`; `renderTemplate("{{highlightVideo}}", { highlightVideo: "https://hudl.com/x" })` substitutes it.

- [ ] **Step 2: Run — expect fail.**

- [ ] **Step 3: Implement.** Add the two entries to `AVAILABLE_VARIABLES` (name/key/description/example). In `TemplateSendModal.vue`, when building the `variables` object (`:217-227`), load the athlete's links (via `useVideoLinks` or a passed prop) and set `highlightVideo` = first healthy link url (fallback first link, else `""`) and `filmLinks` = joined list.

- [ ] **Step 4: Run — expect pass.** `npx vitest run tests/unit/utils/templateVariables.spec.ts`

- [ ] **Step 5: Commit** `feat(web): highlightVideo/filmLinks coach-comms template variables`

---

### Task 8: Packet + public-profile read from the table

**Files:**
- Modify: `composables/useRecruitingPacket.ts:42,88-90,108` (source video_links from the table)
- Modify: `server/api/public/profile/[slug].get.ts:83-89,133-136` (`film` from the table)
- Modify (if the interface field needs it): `utils/recruitingPacketExport.ts:27` stays `VideoLink[]` (display shape) — only the data source upstream changes.
- Test: `tests/unit/composables/useRecruitingPacket.spec.ts` (extend) + `tests/unit/server/api/public/profile.spec.ts` (extend/create)

**Interfaces:**
- Consumes: `video_links` table.
- Produces: recruiting packet + public profile `film` render links from `video_links` (ordered by `position`), not the JSONB.

- [ ] **Step 1: Write failing tests** — packet build returns `video_links` sourced from a mocked `video_links` query; public profile `[slug].get` returns `film` from `video_links` when `show_film` is true, `null` when false.

- [ ] **Step 2: Run — expect fail.**

- [ ] **Step 3: Implement.** In `useRecruitingPacket.ts`, replace the `getPlayerDetails().video_links` source (`:108`) with a `video_links` query for the athlete (`user_id`, order `position`), mapping rows → the `{platform,url,title}` display shape. In `[slug].get.ts`, replace `details?.video_links` (`:133-136`) with a `video_links` query gated by `profile.show_film` (admin client + explicit `.eq(user_id/family_unit_id)`, same shape as the schools read at `:94-97`).

- [ ] **Step 4: Run — expect pass.** `npx vitest run tests/unit/composables/useRecruitingPacket.spec.ts tests/unit/server/api/public/`

- [ ] **Step 5: Commit** `feat(web): recruiting packet + public profile read video_links table`

---

## Self-Review

- **Spec coverage (design §5):** API (T2), rules fixed (T3), CTAs fixed (T4), editor migrated (T5), health cron (T6), comms vars (T7), packet/profile (T8), plus the type/schema foundation (T1). All seven §5 items covered. ✓
- **Placeholder scan:** every code step carries real code or exact file:line anchors; no TBD. ✓
- **Type consistency:** `VideoLinkRow`/`CreateVideoLinkInput` names used consistently T1→T8; API return shape `{ videoLinks }`/`{ videoLink }` consistent T2→T5/T8. ✓
- **Open risks flagged inline:** athlete→user_id mapping in T3; `?tab=` wiring in T4; service-role-needs-explicit-filters in the Global Constraints.

## Execution Handoff

Depends on Phase A's `video_links` table (present on this branch). Independent of Phase C (iOS) — both consume the same table/contract and can run in parallel. Recommended order within B: T1 → T2 first (everything else consumes the API), then T3–T8 in any order.

# Sport Calendar — Phase 2+3: Data + Resolver + Consumer Rewire Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the baseball-only hard-coded recruiting calendar with a sport-, gender-, and division-aware calendar (all 13 NCAA 2026-27 D1 calendars + Other-default + D2), and rewire every consumer so non-baseball athletes stop seeing wrong dead/quiet/contact windows and milestones.

**Architecture:** New `utils/recruitingCalendar/` module — pure, client-safe (server re-exports it, as today). A `SPORT_RECRUITING_CALENDAR` dataset (`Record<NcaaCalendarKey, SportCalendar>` for D1 + `D2_ALL_SPORTS` + `D3` fallback), a resolver (`app sport (+gender/subdivision/division) → SportCalendar`), and sport-aware period/milestone query functions. The legacy `utils/ncaaRecruitingCalendar.ts` becomes a thin shim (or is deleted once callers migrate). Web-only; iOS calendar is Phase 4.

**Tech Stack:** Nuxt 3 / Vue 3 / TypeScript / Zod / Vitest.

**Spec:** `planning/2026-08-23-sport-recruiting-calendar-design.md` (§3, §5, §6, §8.1). Read it alongside this plan.

**Transcribed source data (read these to build the dataset — do NOT re-fetch the PDFs):**
- `.superpowers/sdd/2026-08-23-sport-calendar-phase1-gender-field-plan/p2-spike-mba-calendar.md` (Baseball/MBA)
- `.superpowers/sdd/2026-08-23-sport-calendar-phase1-gender-field-plan/p2-data-softball-basketball.md` (WSB, MBB, WBB)
- `.superpowers/sdd/2026-08-23-sport-calendar-phase1-gender-field-plan/p2-data-football-track.md` (FBS, FCS, XCTF)
- `.superpowers/sdd/2026-08-23-sport-calendar-phase1-gender-field-plan/p2-data-vball-golf-lacrosse.md` (WVB, MGO, MLA, WLA)
- `.superpowers/sdd/2026-08-23-sport-calendar-phase1-gender-field-plan/p2-data-other-d2.md` (Other-D1, D2_ALL)
(These live in the iOS repo's workspace; the implementer reads them by absolute path.)

## Global Constraints

- **TDD is mandatory for every task** (user directive: tests for all new logic/functionality). Every function gets unit tests written first (RED), then implementation (GREEN). No task is done without covering tests that assert real behavior.
- **Period taxonomy = 5 types:** `dead | quiet | contact | evaluation | recruiting_shutdown`. Each sport uses only its real subset. Preserve the legend's exact term in each period's `description`.
- **Every `SportCalendar` carries `source` (NCAA PDF URL) + `verifiedOn: "2026-08-23"`** (L1 audit). Every period carries `confidence: "HIGH"|"MEDIUM"|"LOW"`.
- **Edge-case handling (locked):** MBB "TBD" combine rows → **omit** (leave a code comment noting them). MLA "@ NOON" boundaries → round to the day, add "(effective noon)" to the description. MBB legend "Recruiting Period" → `contact`.
- **Dates as ISO strings** (`"YYYY-MM-DD"`); parse via the project's approved date util, NOT `new Date("YYYY-MM-DD")` (the `local/no-date-only-string-constructor` lint rule).
- **New query functions require `sport` (no silent default)** so type-check forces every caller to migrate — nothing ships on a wrong baseball default.
- **App sport → calendar mapping** (from spec §3.1): Baseball→MBA, Softball→WSB, Basketball→MBB/WBB(gender), Football→FBS/FCS(subdivision toggle, default FBS), Track&Field/CrossCountry→XCTF, Volleyball→WVB, Golf→MGO(male)/Other(else), Lacrosse→MLA/WLA(gender), {Soccer,Swimming,Tennis,Wrestling,IceHockey,FieldHockey,Rowing,WaterPolo}→Other. Gender `null`/`other`/`prefer_not_to_say` on a gendered sport → default men's + view-level toggle (toggle is a UI concern, resolver takes an explicit gender/subdivision override).
- **Division:** D1 = per-key data; D2 = `D2_ALL_SPORTS` for every sport; D3 = `Other`/D1 fallback (documented as such).
- **Branch:** continue on `feat/sport-recruiting-calendar` (web). Data files are read-only inputs.

---

## File Structure

- Create `utils/recruitingCalendar/types.ts` — `RecruitingPeriod`, `CalendarMilestone`, `SportCalendar`, `NcaaCalendarKey`, `Division`, `AppSport`, resolver option types.
- Create `utils/recruitingCalendar/calendarData.ts` — `D1_CALENDARS`, `D2_ALL_SPORTS`, `D3_FALLBACK` (assembled from the fragments).
- Create `utils/recruitingCalendar/resolver.ts` — `resolveCalendarKey`, `getSportCalendar`, and sport-aware `isDeadPeriod`/`isQuietPeriod`/`getDeadPeriodMessage`/`getNextDeadPeriod`/`getUpcomingMilestones`.
- Create `utils/recruitingCalendar/index.ts` — barrel re-export.
- Modify `utils/ncaaRecruitingCalendar.ts` — keep the still-generic exports (SAT/ACT/deadline milestone lists, `getMilestoneTypeIcon`), delegate the sport-specific ones to the new module, drop `RECRUITING_CALENDAR_2026`/`BASEBALL_SIGNING_PERIODS_2026`.
- Modify consumers: `server/utils/ruleEngine.ts`, `pages/dashboard.vue`, `pages/timeline/index.vue`, `components/Dashboard/RecruitingCalendar.vue`, `components/Timeline/UpcomingMilestones.vue`.
- Tests under `tests/unit/utils/recruitingCalendar/` + consumer tests alongside existing ones.

---

## Task 1: Types + resolver (mapping logic, no data yet)

**Files:**
- Create: `utils/recruitingCalendar/types.ts`, `utils/recruitingCalendar/resolver.ts` (resolveCalendarKey only)
- Test: `tests/unit/utils/recruitingCalendar/resolver.spec.ts`

**Interfaces:**
- Produces: `type NcaaCalendarKey = "MBA"|"WSB"|"MBB"|"WBB"|"FBS"|"FCS"|"XCTF"|"WVB"|"MGO"|"MLA"|"WLA"|"Other"`; `type Division="D1"|"D2"|"D3"`; `type AppSport` (the 17 app sport strings); `function resolveCalendarKey(sport: AppSport, opts?: { gender?: string|null; footballSubdivision?: "FBS"|"FCS" }): NcaaCalendarKey`.

- [ ] **Step 1: Write the failing test** — `resolver.spec.ts`, one assertion per sport + the gender/subdivision/fallback branches:

```ts
import { describe, it, expect } from "vitest";
import { resolveCalendarKey } from "~/utils/recruitingCalendar/resolver";

describe("resolveCalendarKey", () => {
  it("maps single-calendar sports", () => {
    expect(resolveCalendarKey("Baseball")).toBe("MBA");
    expect(resolveCalendarKey("Softball")).toBe("WSB");
    expect(resolveCalendarKey("Track & Field")).toBe("XCTF");
    expect(resolveCalendarKey("Cross Country")).toBe("XCTF");
    expect(resolveCalendarKey("Volleyball")).toBe("WVB");
  });
  it("resolves gender-split sports", () => {
    expect(resolveCalendarKey("Basketball", { gender: "male" })).toBe("MBB");
    expect(resolveCalendarKey("Basketball", { gender: "female" })).toBe("WBB");
    expect(resolveCalendarKey("Lacrosse", { gender: "female" })).toBe("WLA");
    expect(resolveCalendarKey("Basketball", { gender: null })).toBe("MBB"); // default men's
    expect(resolveCalendarKey("Basketball", { gender: "prefer_not_to_say" })).toBe("MBB");
  });
  it("golf: men→MGO, else Other", () => {
    expect(resolveCalendarKey("Golf", { gender: "male" })).toBe("MGO");
    expect(resolveCalendarKey("Golf", { gender: "female" })).toBe("Other");
  });
  it("football subdivision toggle, default FBS", () => {
    expect(resolveCalendarKey("Football")).toBe("FBS");
    expect(resolveCalendarKey("Football", { footballSubdivision: "FCS" })).toBe("FCS");
  });
  it("no-calendar sports fall to Other", () => {
    for (const s of ["Soccer","Swimming","Tennis","Wrestling","Ice Hockey","Field Hockey","Rowing","Water Polo"] as const) {
      expect(resolveCalendarKey(s)).toBe("Other");
    }
  });
});
```

- [ ] **Step 2: Run test → FAIL** (`npx vitest run tests/unit/utils/recruitingCalendar/resolver.spec.ts`) — module missing.
- [ ] **Step 3: Implement** `types.ts` (the type aliases above; use the exact 17 `AppSport` string values from `utils/metrics/canonical.ts` `SPORT_METRICS` keys — read that file to copy them verbatim) and `resolveCalendarKey` in `resolver.ts` per the §3.1 mapping.
- [ ] **Step 4: Run test → PASS.**
- [ ] **Step 5: Type-check** (`npm run -s type-check | grep "error TS" || echo NO_TS_ERRORS`).
- [ ] **Step 6: Commit** `feat(calendar): sport→NCAA-calendar resolver + types`.

## Task 2: Assemble the calendar dataset

**Files:**
- Create: `utils/recruitingCalendar/calendarData.ts`
- Test: `tests/unit/utils/recruitingCalendar/calendarData.spec.ts`

**Interfaces:**
- Consumes: `types.ts` (Task 1).
- Produces: `export const D1_CALENDARS: Record<NcaaCalendarKey, SportCalendar>`; `export const D2_ALL_SPORTS: SportCalendar`; `export const D3_FALLBACK: SportCalendar`. `SportCalendar = { periods: RecruitingPeriod[]; milestones: CalendarMilestone[]; source: string; verifiedOn: string }`.

- [ ] **Step 1: Write the failing data-integrity + plausibility test** — `calendarData.spec.ts`:

```ts
import { describe, it, expect } from "vitest";
import { D1_CALENDARS, D2_ALL_SPORTS, D3_FALLBACK } from "~/utils/recruitingCalendar/calendarData";

const ALL_KEYS = ["MBA","WSB","MBB","WBB","FBS","FCS","XCTF","WVB","MGO","MLA","WLA","Other"] as const;
const ISO = /^\d{4}-\d{2}-\d{2}$/;

describe("calendarData integrity (L1)", () => {
  it("has every D1 calendar with source + verifiedOn", () => {
    for (const k of ALL_KEYS) {
      const c = D1_CALENDARS[k];
      expect(c, k).toBeTruthy();
      expect(c.source, k).toMatch(/ncaaorg\.s3\.amazonaws\.com/);
      expect(c.verifiedOn, k).toBe("2026-08-23");
      expect(c.periods.length, k).toBeGreaterThan(0);
    }
  });
  it("every period is well-formed and start<=end", () => {
    for (const k of ALL_KEYS) for (const p of D1_CALENDARS[k].periods) {
      expect(p.start, `${k} ${p.description}`).toMatch(ISO);
      expect(p.end).toMatch(ISO);
      expect(p.start <= p.end, `${k} ${p.description}`).toBe(true);
      expect(["dead","quiet","contact","evaluation","recruiting_shutdown"]).toContain(p.type);
      expect(["HIGH","MEDIUM","LOW"]).toContain(p.confidence);
    }
  });
});

describe("plausibility (L3)", () => {
  const month = (iso: string) => Number(iso.slice(5, 7));
  it("dead/shutdown windows sit in plausible months (no summer-holiday-in-spring typos)", () => {
    // Thanksgiving-ish shutdowns land in Nov; winter shutdowns in Dec/Jan; July-4 dead in Jul.
    for (const k of ALL_KEYS) for (const p of D1_CALENDARS[k].periods) {
      if (/thanksgiving/i.test(p.description)) expect(month(p.start), `${k}`).toBe(11);
      if (/winter|holiday/i.test(p.description) && p.type !== "contact")
        expect([12, 1]).toContain(month(p.start));
      if (/july 4|independence/i.test(p.description)) expect(month(p.start)).toBe(7);
    }
  });
  it("no period spans more than ~10 months (catches a swapped start/end year)", () => {
    for (const k of ALL_KEYS) for (const p of D1_CALENDARS[k].periods) {
      const days = (Date.parse(p.end) - Date.parse(p.start)) / 86400000;
      expect(days, `${k} ${p.description}`).toBeLessThan(310);
      expect(days).toBeGreaterThanOrEqual(0);
    }
  });
});

describe("D2/D3 fallbacks", () => {
  it("D2_ALL_SPORTS + D3_FALLBACK are populated with source + verifiedOn", () => {
    for (const c of [D2_ALL_SPORTS, D3_FALLBACK]) {
      expect(c.periods.length).toBeGreaterThan(0);
      expect(c.verifiedOn).toBe("2026-08-23");
    }
  });
});
```

- [ ] **Step 2: Run → FAIL** (module missing).
- [ ] **Step 3: Assemble `calendarData.ts`** by transcribing every period + milestone from the five data fragment files (absolute paths in the plan header). For each `NcaaCalendarKey`, copy the fragment's period table rows verbatim into `RecruitingPeriod[]` (type, start, end ISO, description incl. legend term, confidence) and milestones into `CalendarMilestone[]`. Apply the locked edge-case rules: omit MBB "TBD" rows (leave a `// TBD combine windows omitted` comment), round MLA "@ NOON" to the day + append "(effective noon)". Set each calendar's `source` to its PDF URL and `verifiedOn: "2026-08-23"`. `D2_ALL_SPORTS` from the D2 fragment's "All Other Sports" track; `D3_FALLBACK` = the `Other` calendar's default track (document the choice in a comment).
- [ ] **Step 4: Run → PASS.** If a plausibility assertion fails, it caught a transcription error — fix the datum against the fragment (do not weaken the test).
- [ ] **Step 5: Type-check.**
- [ ] **Step 6: Commit** `feat(calendar): assemble 13 NCAA 2026-27 calendars dataset (cited, confidence-tagged)`.

## Task 3: Sport-aware query functions

**Files:**
- Modify: `utils/recruitingCalendar/resolver.ts` (+ `getSportCalendar`, period/milestone queries), create `utils/recruitingCalendar/index.ts`
- Test: `tests/unit/utils/recruitingCalendar/queries.spec.ts`

**Interfaces:**
- Consumes: Tasks 1-2.
- Produces (all require `sport`; `opts` carries `gender`/`footballSubdivision`):
  - `getSportCalendar(sport: AppSport, division: Division, opts?): SportCalendar`
  - `isDeadPeriod(date: Date, sport: AppSport, division: Division, opts?): boolean`
  - `isQuietPeriod(date: Date, sport: AppSport, division: Division, opts?): boolean`
  - `getDeadPeriodMessage(date: Date, sport: AppSport, division: Division, opts?): string | null`
  - `getNextDeadPeriod(date: Date, sport: AppSport, division: Division, opts?): RecruitingPeriod | null`
  - `getUpcomingMilestones(params: { sport: AppSport; division: Division; graduationYear?: number; limit?: number; opts?: ... }): CalendarMilestone[]`

- [ ] **Step 1: Write failing tests** — `queries.spec.ts`. Include a **regression guard proving the bug is fixed**: a non-baseball sport returns ITS dead periods, not baseball's.

```ts
import { describe, it, expect } from "vitest";
import { getSportCalendar, isDeadPeriod, getDeadPeriodMessage } from "~/utils/recruitingCalendar";

describe("sport-aware queries", () => {
  it("getSportCalendar returns the resolved sport's calendar (D1)", () => {
    expect(getSportCalendar("Softball", "D1").source).toContain("WSB");
    expect(getSportCalendar("Basketball", "D1", { gender: "female" }).source).toContain("WBB");
  });
  it("D2 → all-sports calendar regardless of sport", () => {
    expect(getSportCalendar("Baseball", "D2")).toEqual(getSportCalendar("Soccer", "D2"));
  });
  it("isDeadPeriod is sport-specific (regression: non-baseball ≠ baseball dates)", () => {
    // Pick a date that is dead for baseball but NOT for <some other sport> per the data.
    // (implementer: choose the concrete date from calendarData once assembled; assert the two sports disagree on at least one date)
    const d = new Date("2027-07-04T12:00:00Z"); // July-4 dead for baseball
    expect(isDeadPeriod(d, "Baseball", "D1")).toBe(true);
    // a sport whose data has no July-4 dead window must return false
    expect(isDeadPeriod(d, "Tennis", "D1")).toBe(false); // Tennis → Other
  });
  it("getDeadPeriodMessage returns null outside any dead window", () => {
    expect(getDeadPeriodMessage(new Date("2026-10-15T12:00:00Z"), "Softball", "D1")).toBeNull();
  });
});
```

- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** the query functions: resolve the calendar via `resolveCalendarKey` + division, then run the same period/milestone logic the legacy file used, scoped to that calendar. `getUpcomingMilestones` merges the sport calendar's milestones with the still-generic SAT/ACT/deadline lists (imported from the legacy file — see Task 4). Parse ISO dates via the project date util. Add the barrel `index.ts`.
- [ ] **Step 4: Run → PASS.** Confirm the regression test's date choices against the assembled data (adjust the concrete dates to real values from `calendarData.ts`, keeping the "two sports disagree" assertion meaningful).
- [ ] **Step 5: Type-check. Commit** `feat(calendar): sport-aware period + milestone queries`.

## Task 4: Migrate the legacy file to the new module

**Files:**
- Modify: `utils/ncaaRecruitingCalendar.ts`
- Test: `tests/unit/utils/ncaaRecruitingCalendar.spec.ts` (existing — update)

**Interfaces:**
- Keeps exporting the generic milestone lists (`SAT_TEST_DATES_2026`, `ACT_TEST_DATES_2026`, `NCAA_DEADLINES_2026`, `NAIA_DEADLINES_2026`, `COLLEGE_APPLICATION_DEADLINES_2026`), `getMilestoneTypeIcon`, `getMilestonesByDateRange`, the `Milestone`/`RecruitingPeriod` types. Removes `RECRUITING_CALENDAR_2026`, `BASEBALL_SIGNING_PERIODS_2026`, and the old signatureless `isDeadPeriod`/`isQuietPeriod`/`getDeadPeriodMessage`/`getNextDeadPeriod`/`getRecruitingCalendar` (now require sport, live in the new module).

- [ ] **Step 1: Update the existing spec** — the current `tests/unit/utils/ncaaRecruitingCalendar.spec.ts` calls the old sportless signatures; rewrite those cases to the new module's sport-aware calls (or move them there), and keep coverage of the still-generic milestone lists here. Write the updated tests first; run → FAIL where old symbols are gone.
- [ ] **Step 2: Edit the legacy file** — delete the baseball constant + old period functions; re-export the generic pieces; keep the `~/utils` location so `server/utils/ncaaRecruitingCalendar.ts` re-export still works.
- [ ] **Step 3: Run the updated spec → PASS. Type-check** — the removed symbols will surface every stale caller as a TS error; that is the migration checklist for Task 5. Record the error list.
- [ ] **Step 4: Commit** `refactor(calendar): retire baseball constant; legacy file keeps generic milestones only`.

## Task 5: Rewire consumers

**Files:**
- Modify: `server/utils/ruleEngine.ts`, `pages/dashboard.vue`, `pages/timeline/index.vue`, `components/Dashboard/RecruitingCalendar.vue`, `components/Timeline/UpcomingMilestones.vue`
- Test: `tests/unit/server/ruleEngine.deadPeriod.spec.ts` (new), plus existing consumer specs updated

**Interfaces:**
- Consumes Task 3's sport-aware functions. Each consumer must source the athlete's `sport` (and `gender` for gendered sports) from the data it already loads.

- [ ] **Step 1: Write the ruleEngine regression test first** — `ruleEngine.deadPeriod.spec.ts`: a `RuleContext` for a non-baseball athlete (e.g. Softball) whose schools are all in a date that is dead for BASEBALL but not softball must NOT skip contact rules (the exact bug). Assert the contact rule is NOT suppressed. Run → FAIL (current code uses baseball dates).
- [ ] **Step 2: ruleEngine** — read `RuleContext` (its type + where `context` is built) to find the athlete's `sport`/`gender`; pass them into `isDeadPeriod(now, sport, division, { gender })`. Keep the per-school division logic. Run the new spec → PASS.
- [ ] **Step 3: dashboard.vue** (`getDeadPeriodMessage` at :230/:232) — source the athlete's sport/gender from the page's loaded profile (find how `primary_sport` is already read on this page); pass through. Update/add a component test if one exists; otherwise assert via a small composable test.
- [ ] **Step 4: timeline/index.vue** (`getUpcomingMilestones` at :333) — add `sport`/`division` to the params object from the loaded profile. Update the timeline spec.
- [ ] **Step 5: RecruitingCalendar.vue + UpcomingMilestones.vue** — pass sport/gender/division through; `getMilestoneTypeIcon` is unchanged (still imported from the legacy file). Where gender is null/other on a gendered sport, expose the men's/women's + FBS/FCS **self-select toggle** (default men's/FBS) so the user can switch; persist the choice in component state.
- [ ] **Step 6: Type-check must be clean** (zero remaining references to the removed baseball symbols). Run the full affected test set:
  `npx vitest run tests/unit/utils/recruitingCalendar/ tests/unit/utils/ncaaRecruitingCalendar.spec.ts tests/unit/server/ruleEngine.deadPeriod.spec.ts` → all pass.
- [ ] **Step 7: Commit** `feat(calendar): rewire ruleEngine + dashboard + timeline to sport-aware calendar`.

## Task 6: Runtime disclaimer + staleness (L6a / L6b)

**Files:**
- Modify: `components/Dashboard/RecruitingCalendar.vue` (+ wherever the calendar renders)
- Test: `tests/unit/components/RecruitingCalendar.disclaimer.spec.ts`

- [ ] **Step 1: Write failing tests** — (a) the calendar renders a disclaimer line "Based on NCAA {SEASON}, verified {verifiedOn} — confirm with your compliance office" + an anchor to the resolved calendar's `source` PDF URL; (b) when `today` is past the season end (after 2027-07-31) and no newer data exists, a "may be out of date — verify" banner renders. Use a fixed/injected "now" for (b).
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** the disclaimer (reads the resolved `SportCalendar.source` + `verifiedOn`) and the staleness guard (compare injected now vs a `SEASON_END` constant).
- [ ] **Step 4: Run → PASS. Type-check. Commit** `feat(calendar): compliance disclaimer + staleness banner (L6a/L6b)`.

## Task 7: CODEOWNERS + SEASON constant (L1/L4)

**Files:**
- Modify/create: `.github/CODEOWNERS`, `utils/recruitingCalendar/calendarData.ts` (SEASON const)

- [ ] **Step 1:** Add a `SEASON = "2026-27"` constant used by `source` URLs + the disclaimer, so the annual bump is one edit. (No test — constant; covered indirectly by Task 6.)
- [ ] **Step 2:** Add/extend `.github/CODEOWNERS` so `utils/recruitingCalendar/**` requires the repo owner's review (L4). Verify the file syntax.
- [ ] **Step 3: Commit** `chore(calendar): SEASON constant + CODEOWNERS gate on calendar data`.

---

## Parity + follow-ups (not this plan)
- iOS byte-identical calendar registry = Phase 4 (mirrors `calendarData.ts` + resolver).
- Refresh job (quarterly cloud routine) = Phase 5.
- `scripts/seed-system-calendar.ts` — audit during Task 5: if it writes calendar rows from the old constant, re-point it or note it as a follow-up.

## Self-Review Notes (author)
- **Spec coverage:** §3 (mapping/source), §5 (structure+resolver), §6 (consumer rewire), §8.1 L1/L3/L4/L6a/L6b all have tasks. L2 was satisfied at transcription time (fragments carry confidence + citations).
- **TDD:** every task writes tests first; Tasks 1/2/3/5/6 have concrete test code; Task 4 updates existing tests; Task 7 is config.
- **Backward-compat:** new query fns require `sport` → type-check enumerates every caller (Task 4 Step 3), so no consumer silently keeps baseball behavior.
- **Deferred data note:** MBB TBD combine windows omitted; MLA noon boundaries day-rounded — both documented in `calendarData.ts` comments.

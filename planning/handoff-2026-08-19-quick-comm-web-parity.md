# Web parity handoff — Quick Comm fixes shipped on iOS (2026-08-19)

Five iOS Quick Comm / metrics fixes landed on iOS branch `feat/quick-comm-wizard`.
Several touch **shared state** (prod DB registry, `communication_templates` bodies,
the resolver contract) so the **web app must mirror them or it drifts / regresses**.
Ordered by urgency.

---

## 🔴 P0 — Web renders raw `[[…]]` until it implements optional segments

**What changed:** I added an optional-segment syntax to the iOS resolver and then
**rewrote shared `communication_templates` bodies (prod) to use it.** Because the
bodies are shared, **any web send of those templates right now emits the literal
markers** (e.g. `[[intendedMajor|, planning to study {{intendedMajor}}]]`) unless
web strips/interprets them.

**Affected prod rows (already edited):**
- `First contact` (`28d16e6f-6fde-42f2-9b0a-1a24c2548d48`) — gates the intended-major
  clause **and** the "…feedback on my film…" sentence.
- `First contact — before the contact date` (`1accfd04-…`) — gates the major clause.

**Syntax:** `[[gateKey|visible text]]` — keep the inner text (which may contain its
own `{{tokens}}`) **iff** `gateKey` resolves to a non-empty value; else drop the whole
span. The gate key itself is **never printed**. Runs **before** token substitution.

**iOS reference impl** (`TemplateResolver.applyOptionalSegments`,
`Features/CommunicationTemplates/Models/TemplateResolver.swift`):
- regex `\[\[([A-Za-z]\w*)\|([\s\S]*?)\]\]`, replace right-to-left.
- kept = `values[gate]` present and non-empty after trim.
- `renderClean` calls `applyOptionalSegments(body, values)` first, then `render`, then
  the existing line-level cleanup.

**Web action:** port `applyOptionalSegments` into `utils/templateResolver.ts` (or
wherever `renderClean` lives) byte-for-byte, call it first in `renderClean`. Ship
this **before** the shared template rows reach web sends.

---

## 🟠 P1 — `{{metrics}}` dedupe (most-recent per type)

iOS `TemplateComputed.renderMetrics` now runs `dedupeMostRecentPerType` before
ranking: one row per `metric_type`, the most recent by `recorded_date` (ties →
verified, then primary, then input order). Previously every row rendered, so an
athlete with several velocity/60-time entries listed each.

**Web action:** mirror in `useTemplateResolver.ts` / `templateResolver.ts`
`rankMetrics`/`renderMetrics` so both platforms produce identical metric blocks.

---

## 🟠 P1 — Primary metric ({{carryingTool}}) can now be set on iOS

`{{carryingTool}}` resolves from the metric flagged `performance_metrics.is_primary`.
iOS previously never wrote it; now it does, via a **shared prod RPC**:

```sql
set_primary_metric(p_metric_id uuid)   -- clears prior primary, sets target, one txn,
                                        -- security invoker (RLS-gated), granted to authenticated
```
DB enforces one primary/user via partial unique index
`performance_metrics_one_primary_per_user ON (user_id) WHERE is_primary`.

**Web action:** add a "headline metric" affordance (star/toggle) in the web metrics
UI that calls `rpc('set_primary_metric', { p_metric_id })`. Unset = update the row's
`is_primary=false` directly. The RPC already exists in prod — no migration needed.

---

## 🟡 P2 — Predefined template edit (iOS fix; verify web parity)

iOS bug: tapping a predefined (global, non-owned) template in the editor and hitting
Save silently did nothing — RLS blocked the UPDATE, the error was swallowed. iOS now
routes predefined templates into a **"customize a copy"** flow (Save → create a new
owned template) and surfaces save errors.

**Web action:** confirm web doesn't have the same silent-failure when a user edits a
predefined template. If it does, apply the same copy-on-edit model.

---

## 🟢 P3 — Hometown (no change needed, informational)

`{{hometownCity}}`/`{{hometownState}}` registry `source_path` is **already**
`pref:location.city` / `pref:location.state` in prod `template_variables` (resolves
from the saved home-location pref, not the NULL `users.hometown_*` columns).
`source_type` is still `column` but the resolver dispatches on the `pref:location.`
path prefix. **Web action:** confirm the web resolver supports the `pref:location.`
source-path branch (iOS does). No registry change.

---

## Not started on iOS (for awareness)
- Pre-send prompt for unset Intended Major (asks, saves to prefs, else the P0 segment
  strip removes the clause) — being built on iOS separately; web may want the same UX.

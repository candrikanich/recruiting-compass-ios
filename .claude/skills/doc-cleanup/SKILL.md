---
name: doc-cleanup
description: 3-pass autonomous doc hygiene — reads .doc-cleanup-manifest.json, deletes session debris, compresses completed plans into docs/history/<domain>.md, reviews ambiguous docs. Runs fully autonomously with no confirmation.
trigger: manual or cron
---

# Doc Cleanup

Execute the setup and three passes below autonomously — no confirmation needed.

## Setup

1. **Regenerate the manifest every run**, even if one exists — it is gitignored and a leftover copy can be months old,
   listing paths that are gone or have since become active docs:

   ```bash
   node scripts/doc-cleanup/scanner.mjs
   ```

   Then read `.doc-cleanup-manifest.json` from the repo root.

2. **Work on a branch, never `main`** — `main` takes changes only through PRs. Branch from the current checkout so
   the scoped staging below still applies:

   ```bash
   git switch -c "chore/doc-cleanup-$(date +%F)"
   ```

---

## Pass 1 — Auto-Delete

Read `manifest.autoDelete[]`. For each path, delete the file:

```bash
rm "<path>"
```

After all deletions, log: `Deleted: N files (session debris)`

---

## Pass 2 — Compress

> **Ordering note:** `docs/history/<domain>.md` uses **prepend** (newest entry at top). `COMPLETED_WORK.md` uses **append** (newest entry at bottom). Do not mix these up.

Before writing the first history entry, ensure the directory exists:

```bash
mkdir -p docs/history
```

For each item in `manifest.compress[]`:

1. Read all files listed in `item.paths[]`
2. Write a 1–3 sentence summary combining all files (if paired): what was the goal, what was built/decided, any key pattern worth remembering
3. Infer the domain from content + path using this priority order (first match wins):
   - `family` — family unit, parent, invite, player, family invite
   - `auth` — login, signup, session, JWT, Supabase auth
   - `ios` — SwiftUI, Xcode, iOS, iPhone, UIKit
   - `e2e` — Playwright, E2E, end-to-end, test spec
   - `testing` — Vitest, unit test, coverage, mock
   - `ui` — component, design system, form, layout, TailwindCSS
   - `schools` — school, program, university
   - `coaches` — coach, staff, recruiting coordinator
   - `onboarding` — onboarding, wizard, signup flow
   - `infrastructure` — Vercel, Supabase, deployment, CI/CD, migration
   - `accessibility` — a11y, WCAG, aria, screen reader
   - `performance` — performance, optimization, bundle, speed
   - `marketing` — landing page, copy, email template, press kit
   - `general` — fallback when nothing else matches
4. **Prepend** this entry to `docs/history/<domain>.md` (create the file if it doesn't exist):

```
# History: <Domain>

## YYYY-MM-DD — <Feature Name>
<1–3 sentence summary>

```

If the file already exists, insert the new entry after the `# History:` heading, before the first existing `## ` entry.

5. Delete all original files in `item.paths[]`

Log each compression: `Compressed: <filename> → docs/history/<domain>.md`

---

## Pass 3 — Review

> **Scale rule:** if `manifest.review[]` has **more than ~30 files**, do NOT read them inline — it blows the main context. Delegate: split the list into batches of ~30 and dispatch one classification subagent per batch **in a single message** (parallel). Each subagent reads + classifies its batch and returns ONLY a compact table `| path | classification | domain | summary |` (fill domain+summary for compress rows; brief reason for delete rows) — it does NOT edit or delete anything. The main thread then executes all writes/deletes itself from the returned tables. Prefer `general-purpose` subagents over `Explore` for this — read-only search agents have stalled on the 600s stream watchdog for large batches; if one stalls, retry it as `general-purpose`. Below ~30 files, just read and classify inline.
>
> When classifying, merge obvious design+implementation pairs into a single history entry (one feature, one entry). For undated docs, use an approximate era date in the `## YYYY-MM-DD` heading rather than the run date.

For each file in `manifest.review[]`:

1. Read the file (or receive its classification from a batch subagent per the scale rule above)
2. Classify:
   - **keep** — future-looking, actively referenced, open checklists, security/audit docs, guides, launch plans, RLS policies. **When in doubt, keep.**
   - **compress** — clearly completed work with a concrete outcome → process identically to Pass 2
   - **delete** — stale one-off (old investigation, one-time fix plan, debugging session notes) with no lasting insight

Log your classification and reasoning briefly for each file.

---

## Final Step

**Append** the following to `COMPLETED_WORK.md` (do NOT rewrite existing content — append only):

```
## Doc Cleanup Run — YYYY-MM-DD
- Deleted: N files (session debris)
- Compressed: N files → domain history
- Kept: N files (active/future-looking)

| Doc | Domain | Summary |
|-----|--------|---------|
| filename.md | domain | one-line summary |
```

Then commit **only the docs this run touched**. NEVER use `git add -A` / `git add .` — a blanket stage sweeps in unrelated working changes: in-progress feature code, build-generated files, and secrets. Specifically, `SupabaseConfig.generated.swift` is regenerated with the **real Supabase key on every build** and must never be committed.

**1. Stage only doc paths this run deleted or wrote** — the two output files plus the exact manifest paths processed in passes 1–3 (each scoped with an explicit `--` pathspec, never a bare `git add`):

```bash
git add -- docs/history/ COMPLETED_WORK.md
# Plus each file this run deleted/compressed, by exact path:
git add -- "<path from manifest.autoDelete / compress / review that this run touched>"
# ...repeat one -- pathspec per touched file (records deletions too)
```

**2. Safety gate — abort if anything out of scope is staged.** Doc cleanup only ever touches `.md` files. If any non-`.md` file (or the generated Supabase config) is staged, unstage and STOP without committing:

```bash
staged=$(git diff --cached --name-only)
offenders=$(echo "$staged" | grep -vE '\.md$')
if [ -n "$offenders" ] || echo "$staged" | grep -q 'SupabaseConfig.generated.swift'; then
  echo "ABORT: doc-cleanup must not commit non-doc files (code/config/secrets):"
  echo "$offenders"
  git reset -q
  exit 1
fi
```

**3. Commit** only after the gate passes, then open a PR against `main`:

```bash
git commit -m "chore: doc cleanup run YYYY-MM-DD"
git push -u origin HEAD
gh pr create --base main --title "chore: doc cleanup run YYYY-MM-DD" --body "<the COMPLETED_WORK.md entry>"
```

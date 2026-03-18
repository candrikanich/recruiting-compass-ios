---
name: doc-cleanup
description: 3-pass autonomous doc hygiene — reads .doc-cleanup-manifest.json, deletes session debris, compresses completed plans into docs/history/<domain>.md, reviews ambiguous docs. Runs fully autonomously with no confirmation.
trigger: manual or cron
---

# Doc Cleanup

Read `.doc-cleanup-manifest.json` from the repo root. If it doesn't exist, tell the user to run `node scripts/doc-cleanup/scanner.mjs` first. Then execute the three passes below autonomously — no confirmation needed.

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

For each file in `manifest.review[]`:

1. Read the file
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

Then commit everything:

```bash
git add -A
git commit -m "chore: doc cleanup run YYYY-MM-DD"
```

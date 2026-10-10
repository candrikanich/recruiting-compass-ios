# Lessons Learned

Actionable patterns extracted from articles and project experience.

---

## Design Systems Checklist (Tyler Coderre) — 2026-03-10
Source: https://tylercoderre.com/projects/design-systems-checklist.html?ref=sidebar

- **7-state component completeness**: Every interactive component needs all seven states before it's considered done: default, hover, focus, active/pressed, disabled, error, and loading — missing any one creates inconsistent UX. Example: SwiftUI buttons need `.disabled` styling + loading `ProgressView` swap; Vue form fields need `:error` prop + `aria-invalid`.
- **Reduced motion is a first-class state**: `prefers-reduced-motion` (CSS) and `.accessibilityReduceMotion` (SwiftUI) must be handled at the component level, not added as a global afterthought — animations that can't be disabled fail WCAG 2.3.3.
- **Semantic color tokens over raw hex**: Name colors by role (`color-action-primary`, `color-feedback-error`) rather than value (`#1a73e8`) so dark-mode variants swap automatically — raw hex in TailwindCSS components breaks dark mode and requires manual duplication across all states.
- **8px grid for spacing consistency**: All padding, margin, and gap values should be multiples of 8px (TailwindCSS: `p-2`=8px, `p-4`=16px, `p-8`=32px) — mixing arbitrary values creates visual inconsistency that accumulates across screens.
- **Skeleton loading as a distinct component**: Skeleton screens are a named component state (not just a spinner swap) — each data-driven component (card, list row, profile header) should have a defined skeleton variant so loading states feel intentional rather than bolted on.

## The 6 Claude Code Skills That Replaced My Entire Prompt Library (Ashish Rawat) — 2026-09-21
Source: pasted content

- **Shell injection for live repo state**: A SKILL.md body can run `!`command`` (backtick-wrapped shell) inline to pull current Git output (e.g. `git diff --cached`, `git diff HEAD`) into the prompt before Claude responds — no manual copy-paste of diffs needed. Already used by this repo's `commit`/`review`/`ship` skills; worth auditing them against this pattern if any still expect a pasted diff.
- **Skill body token budget**: Keep an activated SKILL.md body under ~5000 tokens so the loaded procedure leaves room for repo context — frontmatter (`name`+`description`) alone costs ~50-100 tokens at session startup regardless of activation.

## 13 Claude Lessons We Learned After 3,600 Hours (The PyCoach / Gencay) — 2026-09-28
Source: pasted content

- **No tombstones in instruction files**: When removing a rule/option from CLAUDE.md, a skill, memory, or a hook prompt, delete it outright — "X was retired / renamed from Y / do NOT re-add Z" lines still put X in front of the model, which then reaches for it.
- **Always-loaded context budget**: Global CLAUDE.md + rules/ + project CLAUDE.md + CLAUDE.local.md + MEMORY.md is ~33KB (~8k tokens) billed every session — keep only always-true lines there, move conditional procedures to skills, and prune stale facts (e.g. CLAUDE.md "126+ Tests" vs ~3700 actual).
- **Hooks enforce, CLAUDE.md suggests**: Any rule that must hold late in a long session (no `git add -A`, no `add_files_to_xcode.rb`, no `.xcodeproj` edits) belongs in a PreToolUse hook that blocks the call, not only in prose.
- **Stale hook prompts contradict memory**: A SessionStart hook that tells the model to do something memory says was superseded (e.g. register session crons for doc cleanup that now runs as cloud routines) is a tombstone with teeth — delete the hook when the workflow moves.
- **Uniform report shape for scheduled jobs**: Recurring routines (doc-cleanup, etc.) should end with one shared report format defined in a single skill — state line first, "Made" table, "Held back", "Needs you" last, empty sections omitted — so the one actionable line is always in the same place.
- **Cheap models draft, strong model judges**: Fan drafting/search out to Sonnet/Haiku subagents and keep the top model for review and decisions; keep the model table in rules/dev-standards.md current (it still names 4.5-generation models).

## Test the Diff, Not the App (QA.tech, HackerNoon) — 2026-10-01
Source: https://hackernoon.com/test-the-diff-not-the-app

- **Green is not verified**: A PR test plan must split results into "exercised by a test that touches the change", "unverified (suite green but nothing hit the diff)", and "pre-existing failures" — `-only-testing:` on affected classes only selects tests that already exist, so new behavior with no new test is unverified, not passing.
- **Risk-weighted PR scope**: Size verification to the diff's blast radius, not uniformly — docs/planning-only PRs should skip the ~3700-test job, while auth, onboarding, and entitlement changes get the affected classes plus a manual or UI pass. Example: `scripts/ci/has-code-changes.sh` feeding a job-level `if:` in `ci.yml`
- **Path filters vs required checks**: Workflow-level `paths`/`paths-ignore` never starts the workflow, so a required status check stays pending and the PR can't merge — skip at the job level instead (a skipped job reports as passed), and make only an explicit "docs-only" result skip so a broken detector fails toward running tests.
- **XCTSkip hides a dead login**: Most UI tests `throw XCTSkip("Login failed…")`, so a broken login turns the suite green, not red — a smoke run is only evidence once its skip count is zero.
- **Smoke-sized E2E suite**: Keep scheduled E2E to the few flows that would be a launch-blocking outage (login, onboarding, add school, log interaction) and delete specs nobody acts on — each one must justify its maintenance cost, which matters when reviving the paused nightly UITest job.
- **Feedback while the PR is open**: A failure that lands after merge (nightly E2E) is worth far less than one on the open PR — on web, run Playwright against the PR's Vercel preview URL for the routes the diff touches instead of relying on the post-merge full suite.

## Graph Engineering with Claude (rvaniaaa, X article) — 2026-10-07
Source: https://x.com/rvaniaaaa/status/2083542830086000704

- **Hidden edges in parallel agents**: Separate worktrees aren't enough. Parallel iOS agents still share the simulator, DerivedData, the local Docker Supabase stack, and the `chris-mac-e2e` runner. Give each `xcodebuild` agent its own `-destination id=` and `-derivedDataPath`, or run those gates one after another.
- **Merge counts its inputs**: Any fan-out audit (a11y, perf, dual-store, security sweep) must check findings-per-node against the number of nodes it expected and name the missing ones. One dead subagent otherwise produces a report that looks complete.
- **Loop-until-dry dedupe**: Open-ended sweeps should repeat finder rounds until two rounds in a row find nothing new. Dedupe against everything seen, rejected findings included, and also stop at a round cap and a budget cap.
- **Stream, don't barrier**: When `/trc` dispatches several dev agents, verify each PR as it lands instead of waiting for all of them. Wait for everything only when a step really needs all the results, like the train cut or a cross-PR conflict check.
- **Schema-shaped node output**: Subagents feeding a merge step should return a fixed shape, e.g. `{file, line, severity, claim, evidence}` per finding. Then plain code can dedupe and count without reading free text.
- **Cap the first fan-out**: Run a new audit fan-out on 20 or fewer items first and read the usage. Go wider only if the fan-out and the verifier both found something one agent would have missed.

## Two-Way Doors: Don't Code Yourself into a Corner (Google TotT) — 2026-10-07
Source: https://testing.googleblog.com/2026/10/two-way-doors-dont-code-yourself-into.html

- **Shipped binaries are one-way doors**: Every App Store build freezes the Supabase columns, enum values, web API paths, deep links and push payloads it reads until the update gate moves past it — and 1.0 has no gate, so whatever it reads is permanent until 1.0 installs fade out on their own.
- **Server enums need an `unknown` fallback**: A String-backed `Codable` enum without a custom `init(from:)` fails the whole PostgREST response on one unknown value — never add a server enum value until every gated-in build decodes it tolerantly. Example: `Direction`, `Sentiment`, `TaskStatus`, `DeadlineCategory` have no fallback (2026-10-07)
- **Remote kill switch before risky features**: The only remote control is the whole-app version gate, so a broken feature in a live build can't be turned off — add per-feature flags to `app_config` through an RPC, with missing keys meaning "on".
- **Raw tables are the public API**: iOS reads 26 tables directly with snake_case CodingKeys that mirror columns 1:1, so the DB schema is the wire format — only add columns, and route new iOS features through RPCs or views that can change underneath.
- **Version stored on-device data**: Keychain session JSON and UserDefaults Codable blobs aren't versioned, so a shape change logs people out or throws — wrap them in `{version, payload}` and fall back to a reset when decoding fails.

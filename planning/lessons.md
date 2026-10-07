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

## The Test Suite Is the New Code Review (Allen Hutchison) — 2026-10-07
Source: https://allen.hutchison.org/2026/09/17/the-test-suite-is-the-new-code-review/

- **CI is the agent-era bottleneck**: Once agents write and review PRs in minutes, wall-clock CI dominates throughput — iOS PR CI ran 30–46 min on 2026-10-06/07, so cutting it beats any further agent tuning.
- **Test impact analysis for PRs**: Run only the test classes for touched feature folders on PRs (`-only-testing:` from `git diff --name-only origin/main...`), and keep the full ~3700-test run on push to main and nightly. Example: `Features/Coaches/**` → `-only-testing:TheRecruitingCompassTests/Coach*`
- **Batch merges cancel main CI**: Merging several PRs within minutes makes `cancel-in-progress` drop main runs, so intermediate main commits are never tested — merge one at a time, or accept that only the last commit in a burst is verified.
- **Contract tests at the iOS↔Supabase boundary**: Cross-boundary bugs (iOS sending `position` when the column is `role` → PGRST204) slip past green unit suites — assert iOS `CodingKeys` against the schema's real column list, the same way the calendar parity fixture guards web↔iOS.
- **One test crosses the changed boundary**: A PR that touches an encoder, endpoint or query needs at least one test that goes through that boundary, not just mocked unit tests on either side.

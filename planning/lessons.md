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

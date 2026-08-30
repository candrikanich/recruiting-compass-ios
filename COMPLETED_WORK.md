# Completed Work

## Doc Cleanup — 2026-04-05

- **Auto-deleted:** 0 files
- **Compressed:** 0 files
- **Flagged for review:** 33 files (no action taken — requires human review)

## Doc Cleanup Run — 2026-03-18
- Deleted: 39 files (session debris — handoffs, agent team docs, phase complete flags)
- Compressed: 4 files → `docs/history/ios.md` (Phase 1–5 dashboard/family summaries)
- Compressed (Pass 3): 28 files → `docs/history/sessions.md`, `docs/history/infrastructure.md`, `docs/history/accessibility.md`, `docs/history/testing.md`
- Deleted (Pass 3): 86 files (stale one-offs: preferences summaries, accessibility audits, completed implementation plans, old architecture reviews, session quick-refs)
- Kept: 23 files (active specs, plans, guides, design system docs, App Store checklist)

## Doc Cleanup Run — 2026-08-09
- Deleted: 0 files
- Compressed: 0 files
- Kept: 13 files (active/future-looking)
- No-op run: the 21 completed-work plans the scanner re-flagged were already deleted and folded into `docs/history/*.md` by the same-day commit `2512c39`. Only living references and open-work plans remain.

| Doc | Domain | Summary |
|-----|--------|---------|
| planning/2026-03-15-swiftui-modernization.md | ios | Kept — SwiftUI refactor with open tasks (searchable, Swift Regex, .formatted()). |
| planning/2026-03-17-notifications-system.md | infrastructure | Kept — partially-implemented notifications system, iOS items remaining. |
| planning/2026-05-27-e2e-full-suite-green.md | e2e | Kept — phases 3–6 (green suite, CI, coverage gate, flake hardening) still open. |
| planning/SPEC_notifications_system.md | infrastructure | Kept — active spec for partially-built notification system. |
| docs/CODE_PATTERNS.md | general | Kept — living MVVM/pattern reference. |
| docs/CONFIGURATION.md | infrastructure | Kept — living config/deployment reference. |
| docs/E2E_TESTING.md | e2e | Kept — active E2E runbook. |
| docs/TROUBLESHOOTING.md | general | Kept — living troubleshooting reference. |
| docs/cron-schedules.md | infrastructure | Kept — pg_cron job reference. |
| docs/design/colors.md | ui | Kept — design-system reference (BadgeColor roles). |
| docs/design/components.md | ui | Kept — design-system reference (BadgeView). |
| docs/design/states.md | ui | Kept — design-system reference (state→color mapping). |
| docs/design/tokens.md | ui | Kept — design-system reference (brand palette tokens). |

## Doc Cleanup Run — 2026-08-16
- Deleted: 1 file (CoachOutreach send-confirmation handoff — session debris)
- Compressed: 1 file → docs/history/infrastructure.md (1 domain)
- Kept: 24 files (active plans, open specs/checklists, standing references: notifications system, app-store launch checklist, design tokens, code patterns)

| Domain | Compressed | Summary |
|--------|-----------|---------|
| infrastructure | 1 | Video Links Phase A DB plan — canonical video_links table + JSONB backfill, applied live 2026-08-09 |

## Doc Cleanup Run — 2026-08-23
- Deleted: 2 files (public-profile-followups handoff debris; stale test-suite-fixes log)
- Compressed: 37 files → docs/history/{general,ui,auth,infrastructure,accessibility,ios,e2e,family,schools,coaches}.md (10 domains)
- Kept: 24 files (active/future-looking: open phase plans (quick-comm 2b/3, personal-fit), approved specs, App Store launch checklist, design system, config/troubleshooting guides)

| Domain | Compressed | Summary |
|--------|-----------|---------|
| general | 11 | Public Profile tab, video links (web B + iOS C), action-item CTAs, notifications build, Phase 6 Events (list/detail/create) + Document Viewer |
| ui | 6 | Error pages, player-details 4-tab redesign, settings completion badges, design-system token consolidation, player-profile tab reorg |
| auth | 6 | Sign in with Apple (iOS+web), Face ID unlock, parent-login UX fixes, security hardening |
| accessibility | 3 | Localization Phase 6 (a11y labels + text sites), dropped UIHostingController a11y unit tests |
| schools | 3 | School Fit / Academic Fit, Contacted stat card, Distance from Home |
| coaches | 3 | Quick Communication template parity (Phases 1 + 2a), Coaches Needing Follow-up widget |
| family | 2 | Family shared player profile, suggestions endpoint parent resolution |
| infrastructure | 1 | Push notifications (APNs) |
| ios | 1 | SwiftUI modernization |
| e2e | 1 | iOS E2E test environment |

## Doc Cleanup Run — 2026-08-30
- Deleted: 2 files (session handoffs)
- Compressed: 14 files → docs/history/*.md (5 domains)
- Kept: 18 files (active specs, launch checklist, design tokens, guides, multi-sport metrics plans, baseball audit)

| Domain | Compressed | Summary |
|--------|-----------|---------|
| coaches | 7 | Quick comm template parity spec, phase 2b+3 plans, unified missing-info, questionnaire-metric parity, coach tile consolidation, send confirmation |
| schools | 3 | Distance-from-home design, personal fit signals (design+plan), visited card real visits |
| general | 2 | Profile completeness canonical spec, cross-platform video links design |
| ui | 1 | Web parity public profile socials |
| onboarding | 1 | Canonical positions parity spec |

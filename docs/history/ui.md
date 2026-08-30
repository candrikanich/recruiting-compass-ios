# UI History

## 2026-08-19 — Web Parity Public Profile Socials
Web parity spec: add Social section (twitter/instagram/tiktok/facebook) to public profile page, matching iOS implementation. No DB migration needed.

## 2026-08-10 — Player-profile tab reorg (iOS + web)
Regrouped player-profile fields by purpose — Contact/Privacy/Social → Basics, High School → Academics — added `core_courses` + phone/email inputs, and collapsed web's duplicate phone/email.

## 2026-03-10 — Design-system token consolidation
Established the brand palette + BadgeColor enum, migrated all model color properties, fixed the PriorityTier mismatch, added skeleton/shimmer components, and wrote the docs/design/ spec files.

## 2026-03-06 — Branded error pages
AppError enum + config, full-screen AppErrorView, SessionExpiredSheet, ErrorStateView → InlineErrorView rename. Design + implementation, with tests.

## 2026-03-06 — Player-details redesign
Replaced the single-scroll PlayerDetailsView with a 4-tab guided profile (auto-save, completeness card, sport-conditional fields, position chips).

## 2026-03-06 — Settings completion badges
Complete/Incomplete pill badges on Home Location, Player Details, and School Preferences settings rows via SettingsViewModel.

# General History

## 2026-08-10 — iOS Public Profile tab
Editor + native preview card + per-coach "Send Profile" tracking, wrapping the web `/api/player/profile` API (models, service, VM, slug validation, header colors).

## 2026-08-08 — Video links (canonical table, web + iOS)
Canonical `public.video_links` adopted everywhere: web Phase B (CRUD API, suggestion rules, CTAs, settings editor, health cron, template vars, packet/profile) and iOS Phase C (VideoLink model + Supabase service, player-only editor max 5 with health badge, action-item video CTAs, film-link comms template vars). Shipped.

## 2026-08-08 — Dashboard action-item CTA buttons
Per-type CTA buttons + Learn More modal, urgency sort, and parent-preview ungating (SuggestionHelpContent ported from web).

## 2026-03-17 — Notifications system build
Cross-platform notifications: the `notifications` row is the single source of truth, cron Edge Functions INSERT, and an existing Postgres trigger fires push. Foundational push function + trigger + migration landed; canonical spec retained separately (SPEC_notifications_system.md).

## 2026-02 — Phase 6 Events (list + detail + create)
Events List (calendar grid + list, month nav, delete, date-range filter, sort), Event Detail (view/edit/delete/mark-attended), and Create Event (nav integration + detail view). Verification docs confirmed shipped. Gotcha: PBXFileSystemSynchronizedRootGroup.

## 2026-02 — Phase 6 Document Viewer
Fullscreen modal (video/image/PDF/fallback), share/download, collection navigation, a11y. Compliance-assessed and implemented.

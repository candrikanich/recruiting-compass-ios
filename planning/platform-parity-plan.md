# Platform Parity Plan — The Recruiting Compass

**Created:** 2026-08-29
**Scope:** Web (Nuxt/Vue) <-> iOS (SwiftUI) feature gaps in both directions
**Excludes:** Admin Panel (web-only by design), Biometrics/Haptics (iOS-only by design), Weekly Email Digest (server-side cron, iOS has toggle)

---

## Verified Gap Inventory

### Web has, iOS missing

| # | Feature | User Value | Effort | Notes |
|---|---------|-----------|--------|-------|
| 1 | **Recommendation Letters** | High | Medium | Status workflow (not_requested→requested→received→submitted), deadline urgency, filters. New feature module. |
| 2 | **Advanced Search** | High | Large | Cross-entity search (schools/coaches/interactions/metrics) + saved searches. Requires new search service + UI. |
| 3 | **Deadlines Tracker** | High | Medium | Centralized cross-entity deadline view + dashboard widget. Offer deadlines + timeline deadlines already exist on iOS but scattered. |
| 4 | **School Recommendations (AI)** | Medium | Medium | NCAA-catalog ranked suggestions with add/dismiss. iOS has College Scorecard enrichment but not the recommendation engine. Web API exists (`/api/schools/recommendations.get`). |
| 5 | **School Map Widget (Dashboard)** | Medium | Small | iOS has MapKit on school detail. Need a dashboard-level map of all schools color-coded by status. MapKit is available. |
| 6 | **Reports Page (unified)** | Medium | Large | iOS has per-feature exports (Analytics CSV/PDF, Performance PDF/CSV, Events CSV). Missing: unified date-range reports page with multi-format export. |
| 7 | **Data Export (GDPR Art. 20)** | High | Medium | iOS has account deletion (30-day grace). Missing: ZIP download of all user data. Web API exists (`/api/user/export.post`). |
| 8 | **Coach Export** | Low | Small | Bulk CSV export from coaches list. Web has `useCoachExport`. |
| 9 | **School Export** | Low | Small | Bulk CSV export from schools list. Web has `useSchoolExport`. |
| 10 | **Dashboard widgets: Schools by Size, Contact Frequency, Upcoming Deadlines** | Low | Small each | 3 additional dashboard widgets web has. Deadlines widget blocked by #3. |

### iOS has, Web missing or partial

| # | Feature | User Value | Effort | Notes |
|---|---------|-----------|--------|-------|
| 11 | **Performance PDF Report** | Medium | Medium | iOS has `PerformancePDFGenerator` — detailed PDF of metrics/trends. Web ExportButton offers generic PDF but not a dedicated performance report. |
| 12 | **Public Profile PDF** | Low | Small | iOS has `PublicProfilePDFRenderer`. Web has no equivalent. |
| 13 | **Per-school Map on Detail** | Low | Small | iOS shows MapKit on school detail. Web has dashboard map (Leaflet) but not per-school detail map. |
| 14 | **Realtime Activity Feed** | Medium | Medium | iOS uses Supabase Realtime subscriptions for live updates. Web likely uses polling or static fetch. |

### Already at parity (verified)

- Activity Feed: Both platforms have it (iOS has realtime, web may poll — see #14)
- About + Feedback: Both present
- Offer Comparison: Both present (`OfferComparisonSheet` / `OfferComparison.vue`)
- Account Deletion: Both present (30-day grace period)
- QR Code: Both present (iOS CoreImage, web `qrcode` npm)
- Communication Templates: Both present
- Dashboard widget reorder/customize: Both present

---

## Prioritized Implementation Phases

### Phase 1 — High-Value, Quick Wins (2-3 weeks)

**Rationale:** Ship features users actively need with existing backend support.

#### 1a. Data Export (GDPR) → iOS
- **Value:** High — regulatory compliance, user trust
- **Effort:** Small-Medium — web API already exists (`/api/user/export.post`)
- **Work:** Add "Export My Data" button in Settings/Profile, call existing API, handle ZIP download via share sheet
- **Dependencies:** None (API exists)

#### 1b. School Map Widget → iOS Dashboard
- **Value:** Medium — geographic visualization is a top-requested dashboard feature
- **Effort:** Small — MapKit available, school data already loaded, dashboard widget system exists
- **Work:** New `SchoolMapWidget` using MapKit with color-coded pins by status, add to widget registry
- **Dependencies:** None

#### 1c. Per-school Map → Web Detail
- **Value:** Low — minor gap
- **Effort:** Small — Leaflet already used for dashboard map
- **Work:** Add map section to school detail page using existing Leaflet setup
- **Dependencies:** None

### Phase 2 — Core Feature Gaps (3-4 weeks)

**Rationale:** Features that fill real workflow gaps for recruiting families.

#### 2a. Deadlines Tracker → iOS
- **Value:** High — centralized deadline management across offers, tasks, applications
- **Effort:** Medium — new feature module, but API routes exist (`/api/deadlines/*`)
- **Work:** New `Deadlines` feature module (list view + add/edit + dashboard widget), aggregate from offers + timeline + custom deadlines
- **Dependencies:** None (API exists)
- **Parity note:** Also add `UpcomingDeadlines` dashboard widget to iOS widget registry

#### 2b. Recommendation Letters → iOS
- **Value:** High — critical for college application workflow
- **Effort:** Medium — new feature module with status workflow
- **Work:** New `Recommendations` feature module: list with status badges, add form, status transitions, deadline tracking, filter/sort
- **Dependencies:** DB tables likely exist (web uses them). Verify schema.
- **DB check needed:** Confirm `recommendation_letters` (or similar) table exists and has RLS policies

#### 2c. School Recommendations → iOS
- **Value:** Medium — helps discovery, differentiates the product
- **Effort:** Medium — web API exists (`/api/schools/recommendations.get`), need iOS presentation
- **Work:** New `RecommendedSchools` component/section, call existing API, add/dismiss actions, cache results
- **Dependencies:** Web API must be deployed

### Phase 3 — Search and Reporting (4-6 weeks)

**Rationale:** Larger features that require significant new UI and logic.

#### 3a. Advanced Search → iOS
- **Value:** High — users with 50+ schools/coaches need cross-entity search
- **Effort:** Large — new search service, cross-entity result types, saved searches with persistence
- **Work:**
  - Search service hitting existing web API or direct Supabase queries
  - Unified result list with entity-type sections (schools, coaches, interactions, metrics)
  - Saved search CRUD (name, query, entity types)
  - Search accessible from tab bar or global shortcut
- **Dependencies:** Decide whether to use web API proxy or direct Supabase queries
- **Architecture decision:** Clean architecture (like Schools) recommended given complexity

#### 3b. Unified Reports Page → iOS
- **Value:** Medium — iOS already has per-feature exports; a unified page adds convenience
- **Effort:** Large — aggregate data from multiple features, multi-format export
- **Work:**
  - Reports feature module with date-range picker + quick presets
  - Aggregate data from schools, coaches, interactions, events, offers
  - Export via share sheet (CSV, PDF)
  - Reuse existing `MetricsExportService` and `PerformancePDFGenerator` patterns
- **Dependencies:** None, but benefits from Phase 2 features being complete

### Phase 4 — Polish and Minor Gaps (2 weeks)

**Rationale:** Small improvements that complete the parity picture.

#### 4a. Coach Export + School Export → iOS
- **Value:** Low — convenience for power users
- **Effort:** Small each — add export button to list views, generate CSV via share sheet
- **Work:** Add export action to CoachesListView and SchoolsListView toolbars

#### 4b. Dashboard widgets (Schools by Size, Contact Frequency) → iOS
- **Value:** Low — nice-to-have dashboard variety
- **Effort:** Small each — follow existing widget pattern
- **Work:** Two new widgets registered in dashboard widget system

#### 4c. Performance PDF Report → Web
- **Value:** Medium — iOS has a polished PDF; web should match
- **Effort:** Medium — server-side PDF generation or client-side with jsPDF
- **Work:** Add dedicated "Performance Report" export option alongside existing ExportButton

#### 4d. Realtime Activity Feed → Web
- **Value:** Medium — live updates improve engagement
- **Effort:** Medium — add Supabase Realtime subscription to activity feed page
- **Work:** Subscribe to relevant tables via Supabase Realtime channel, merge live events into feed

---

## Summary Timeline

| Phase | Duration | Items | Key Deliverable |
|-------|----------|-------|-----------------|
| **Phase 1** | 2-3 weeks | GDPR export, School Map Widget, Per-school map | Quick wins, compliance |
| **Phase 2** | 3-4 weeks | Deadlines, Rec Letters, School Recs | Core workflow gaps filled |
| **Phase 3** | 4-6 weeks | Advanced Search, Unified Reports | Power-user features |
| **Phase 4** | 2 weeks | Exports, widgets, Performance PDF, Realtime | Polish and completeness |

**Total estimated:** 11-15 weeks for full parity (excluding admin panel, biometrics, haptics, email digest cron)

---

## Architecture Notes

- **New iOS features** should follow the Schools clean architecture pattern (Domain/Data/Presentation/DI) for any medium+ complexity feature (Search, Deadlines, Recommendations, Rec Letters)
- **Small features** (map widget, exports) can use the existing MVVM pattern
- **Web API reuse:** Several iOS gaps have existing web API routes — prefer calling those over duplicating logic, but evaluate latency and offline needs
- **Dashboard widgets:** iOS has a mature widget registry with drag-reorder; new widgets plug in via the existing pattern
- **Testing:** TDD for all new feature modules; accessibility labels required per project standards

## Open Questions

1. **Search architecture:** Should iOS Advanced Search query via web API proxy or direct Supabase? Direct is faster but duplicates query logic; API proxy is DRY but adds latency.
2. **Recommendation Letters schema:** Need to verify the DB table structure before iOS implementation.
3. **School Recommendations algorithm:** Is the web recommendation logic in the API route self-contained, or does it depend on web-only utilities?
4. **Reports scope:** Should iOS unified reports match web exactly, or is per-feature export sufficient given mobile UX constraints?

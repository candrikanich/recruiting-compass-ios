# iOS History

## 2026-03-15 — SwiftUI modernization
Replaced custom code duplicating built-in SwiftUI/Foundation APIs and dropped UIKit deps: iOS 18 Tab API, `@Entry` macro, `sensoryFeedback`, `RelativeDateTimeFormatter`, Swift Charts. All tasks done.

## Phase 5: Parent Preview Mode — COMPLETE (2026)
Implemented full family management system with parent preview mode and athlete switching. Created `FamilyMember` model, `FamilyManaging` protocol, `FamilyManager` singleton, `ParentPreviewBanner`, and `AthleteSelector` components. Dashboard now scopes data to the selected athlete, with parents entering preview mode via athlete selection and exiting via the banner dismiss button.

## Phase 4: Charts, Events, Activity Feed — COMPLETE (2026)
Added Swift Charts-based `InteractionTrendsChart`, `UpcomingEventsWidget`, `RecentActivityFeed`, and `PerformanceMetricsWidget` to the dashboard. ViewModel now fetches events, activities, performance metrics, and interaction trends in parallel. All widgets include empty state handling, relative date formatting, and VoiceOver-friendly accessibility elements.

## Phase 2: Core Dashboard UI — COMPLETE (2026)
Built the dashboard UI with a 6-card `StatCard` grid (coaches, schools, interactions, offers, accepted rate, A-tier), animated loading skeletons, empty state with compass icon, pull-to-refresh, and personalized greeting header. Fixed `MainActor` isolation in the service layer and added `Color(hex:)` support to `AppColors`.

## Phase 1: Data Foundation — COMPLETE (2026)
Established the iOS data layer for the dashboard feature: 11 `Codable`/`Identifiable`/`Sendable` models (School, Coach, Interaction, Offer, Event, PerformanceMetric, Activity, QuickTask, Suggestion, InteractionTrend, DashboardStats), `DashboardManaging` protocol with Supabase implementation, and `UserDefaultsTaskStorage` for local quick tasks. Project uses Xcode 15+ `FileSystemSynchronizedRootGroup` — no manual pbxproj edits needed.

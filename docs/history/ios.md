# iOS History

## 2026-09-09 — Turnstile captcha support (login/signup/password-reset)
Wired Cloudflare Turnstile into iOS auth: a hidden `WKWebView`-backed `TurnstileTokenProvider` singleton runs an invisible widget and bridges tokens to Swift; `LoginViewModel`/`SignupViewModel`/`ForgotPasswordViewModel` now fetch a fresh single-use token and thread `captchaToken` through `AuthManager`/`SupabaseManager` into the supabase-swift SDK, fixing "captcha protection: request disallowed" rejections.

## 2026-09-09 — Inbound-draft review: coach email prefill + school-creation entry point
Closed two gaps in the "Review Coach Email" inbound-draft form (iOS PR #128, issue #125, web parity #737/#675): the add-coach sheet now prefills the sender's name/email from the draft, and a new self-contained `AddSchoolSheet` lets the reviewer create a missing school without losing in-progress edits — both wired through the existing `AddInteractionViewModel` so no state round-trips a navigation boundary.

## 2026-08-25 — Coach detail redesign (insights, alerts, analytics, tags)
Rebuilt the iOS coach detail screen to match the Figma frame: a `CoachInsights` value type (ported from web `useCoachInsights`) drives overdue/channel-preference alert banners, ringed KPI stat cards, a colored direct-channels grid, an outreach analytics gauge, and new `tags`/`source` fields with a persistence-backed tags card and profile-meta card. Also added a social-DM return-confirmation flow (iOS divergence from web, which fires on open).

## 2026-08-23/24 — Sport-aware NCAA recruiting calendar + Timeline Guidance parity
Replaced the baseball-only hard-coded recruiting calendar with a sport-, gender-, and division-aware system: an optional `gender` profile field, a byte-identical `RecruitingCalendar` registry (21 calendar keys, all NCAA 2026-27 D1 calendars + D2/Other fallback) ported from web, and a resolver wired into the dashboard widget. Brought the web Timeline guidance sidebar to iOS (`Tasks | Guidance` segmented control with 5 panels: What Matters Now, Upcoming Milestones, Recruiting Calendar, Common Worries, What Not to Stress), then merged the duplicate milestone renders into one shared rich list and added real SAT/ACT/FAFSA milestones, per-section collapse, and What-Matters tap-through. Session closed and device-QA passed 2026-08-24.

## 2026-08-21 — Multi-sport performance metrics registry
Replaced the closed 8-key baseball/softball `MetricType` enum with a registry-backed struct (`MetricRegistry`/`MetricDef`/`Format`) covering all 17 sports, sport-filtered metric pickers, an `other`-with-custom-name field, and registry-driven labels in the communication-templates resolver — zero data migration, byte-identical with the web `metricDefs`/`sportMetrics` registry.

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

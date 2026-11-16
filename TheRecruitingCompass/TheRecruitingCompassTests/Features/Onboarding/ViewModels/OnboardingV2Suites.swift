import Testing

/// Every suite that checks analytics through `AnalyticsHarness` (or runs code that emits events) lives under this
/// one serialized parent. The harness swaps the global `Analytics.transport`, so suites running in parallel would
/// record each other's events (this made `completeOnboarding_reportsPlayerRoleAndSchoolCount` flaky on main).
@Suite(.serialized)
enum OnboardingV2Suites {}

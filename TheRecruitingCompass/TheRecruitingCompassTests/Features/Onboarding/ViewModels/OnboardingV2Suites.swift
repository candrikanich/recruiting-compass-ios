import Testing

/// The Swift Testing suites that use `AnalyticsHarness` live under this one serialized parent. The harness swaps
/// the global `Analytics.transport`, so Swift Testing suites running in parallel would record each other's events
/// (this made `completeOnboarding_reportsPlayerRoleAndSchoolCount` flaky on main). XCTest classes are not under it:
/// they run one at a time, and not alongside the Swift Testing suites.
@Suite(.serialized)
enum OnboardingV2Suites {}

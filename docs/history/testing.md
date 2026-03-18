# Testing History

## E2E Test Architecture Decision (2026-02-07)
Playwright cannot test iOS Simulator UIs. Two-layer testing strategy adopted: (1) XCUITest for full user journeys in Simulator (signup, login, navigation flows), (2) `@playwright/test` as API test runner only (no browser) for Supabase Auth API — signup, email verification, session management, family codes. Implemented in `TheRecruitingCompassUITests/E2E/` and `e2e-api-tests/`.

## E2E Test Coverage — SchoolDetail, Preferences, AddCoach (2026)
Comprehensive E2E tests implemented across these features. Key helpers: `TestHelpers.swift` with mock auth injection, `XCUIApplication` extensions for common gestures. All tests pass against real Simulator. Preferences E2E: full settings read/write cycle, a11y announcements verified.

## Test Infrastructure Issues Resolved (2026)
`@MainActor` ViewModel teardown crash in `UIHostingController` tests fixed with `nonisolated deinit {}` pattern (see CODE_PATTERNS). `UserDefaults.synchronize()` required after writes in test isolation. `MockEventsService`, `MockAuthManager`, `MockSchoolsService` all follow chainable `shouldThrow` + return value pattern.

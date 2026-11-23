import XCTest
@testable import TheRecruitingCompass

final class EmailVerificationBannerVisibilityTests: XCTestCase {
  nonisolated deinit {}

  private func visible(
    verified: Bool = false,
    dismissed: Bool = false,
    awaits: Bool = true,
    loaded: Bool = true,
    locked: Bool = false
  ) -> Bool {
    EmailVerificationBannerVisibility.isVisible(
      isVerified: verified, isDismissed: dismissed,
      guardian: awaits ? (loaded: loaded, locked: locked) : nil)
  }

  func testHiddenWhileGuardianConsentPending() {
    XCTAssertFalse(visible(loaded: true, locked: true))
  }

  func testShownOnceConsentLands() {
    XCTAssertTrue(visible(loaded: true, locked: false))
  }

  func testHeldBackUntilGuardianStatusLoaded() {
    XCTAssertFalse(visible(loaded: false, locked: false))
  }

  func testNotLoadedAndLockedStaysHidden() {
    XCTAssertFalse(visible(loaded: false, locked: true))
  }

  func testNonAthleteIsNotHeldBackByGuardianState() {
    XCTAssertTrue(visible(awaits: false, loaded: false, locked: false))
    XCTAssertTrue(visible(awaits: false, loaded: true, locked: true))
  }

  func testVerifiedEmailNeverShows() {
    XCTAssertFalse(visible(verified: true))
    XCTAssertFalse(visible(verified: true, awaits: false))
  }

  func testDismissedNeverShows() {
    XCTAssertFalse(visible(dismissed: true))
    XCTAssertFalse(visible(dismissed: true, awaits: false))
  }

  // MARK: - View model wiring

  @MainActor
  private func makeModels(
    verified: Bool = false, locked: Bool = false, guardianFails: Bool = false, refresh: Bool = true
  ) async -> (EmailVerificationBannerViewModel, GuardianStatusViewModel) {
    let auth = MockAuthManager()
    auth.setMockSession(Session(
      accessToken: "t", tokenType: "bearer", expiresIn: 3600,
      expiresAt: Int(Date().timeIntervalSince1970) + 3600, refreshToken: "r",
      user: User(id: "u1", email: "p@example.com", emailConfirmedAt: verified ? "2026-01-01T00:00:00Z" : nil,
                 fullName: "P", createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z",
                 role: .player, dateOfBirth: nil)))
    auth.user = auth.session?.user
    let service = MockGuardianService()
    service.mockStatus = GuardianStatus(
      locked: locked, guardianEmailMasked: nil, expiresAt: nil, status: locked ? "pending" : "claimed")
    service.shouldThrowFetchStatusError = guardianFails
    let guardian = GuardianStatusViewModel(guardianService: service, authManager: auth)
    if refresh { await guardian.refresh() }
    return (EmailVerificationBannerViewModel(authManager: auth), guardian)
  }

  @MainActor
  func testViewModelHidesWhileConsentPending() async {
    let (banner, guardian) = await makeModels(locked: true)
    XCTAssertFalse(banner.isVisible(guardian: guardian))
  }

  @MainActor
  func testViewModelShowsAfterConsentLands() async {
    let (banner, guardian) = await makeModels(locked: false)
    XCTAssertTrue(banner.isVisible(guardian: guardian))
  }

  @MainActor
  func testViewModelHoldsBackBeforeGuardianLoads() async {
    let (banner, guardian) = await makeModels(refresh: false)
    XCTAssertFalse(banner.isVisible(guardian: guardian))
  }

  @MainActor
  func testViewModelShowsWhenGuardianLookupFails() async {
    let (banner, guardian) = await makeModels(guardianFails: true)
    XCTAssertTrue(banner.isVisible(guardian: guardian))
  }

  @MainActor
  func testViewModelShowsWithoutGuardianLookup() async {
    let (banner, _) = await makeModels(locked: true, refresh: false)
    XCTAssertTrue(banner.isVisible(guardian: nil))
  }

  @MainActor
  func testViewModelHidesWhenVerifiedOrDismissed() async {
    let (verified, guardianA) = await makeModels(verified: true)
    XCTAssertFalse(verified.isVisible(guardian: guardianA))
    XCTAssertFalse(verified.isVisible(guardian: nil))
    let (dismissed, guardianB) = await makeModels()
    dismissed.isDismissed = true
    XCTAssertFalse(dismissed.isVisible(guardian: guardianB))
  }

  // MARK: - Athlete-only guardian selection

  private func member(role: String) -> FamilyMember {
    FamilyMember(id: "m1", userId: "u1", familyUnitId: "f1", role: role, addedAt: nil, user: nil)
  }

  @MainActor
  func testAthleteWaitsOnTheGuardianLookup() async {
    let (_, lookup) = await makeModels(refresh: false)
    let selected = EmailVerificationBannerVisibility.guardian(for: member(role: "player"), lookup: lookup)
    XCTAssertTrue(selected === lookup)
  }

  @MainActor
  func testParentCoachAndMissingMemberNeverWaitOnTheGuardianLookup() async {
    let (_, lookup) = await makeModels(locked: true, refresh: false)
    for current in [member(role: "parent"), member(role: "coach"), nil] {
      XCTAssertNil(EmailVerificationBannerVisibility.guardian(for: current, lookup: lookup))
    }
  }

  @MainActor
  func testParentSeesVerifyPromptEvenThoughNoGuardianLookupEverRuns() async {
    let (banner, lookup) = await makeModels(locked: true, refresh: false)
    let selected = EmailVerificationBannerVisibility.guardian(for: member(role: "parent"), lookup: lookup)
    XCTAssertTrue(banner.isVisible(guardian: selected))
  }

  @MainActor
  func testBannerPassesItsGuardianLookupThrough() async {
    let (banner, lookup) = await makeModels(locked: true)
    XCTAssertFalse(EmailVerificationBanner(viewModel: banner, guardian: lookup).isShown)
    XCTAssertTrue(EmailVerificationBanner(viewModel: banner, guardian: nil).isShown)
  }

  // MARK: - Cancelled lookup

  @MainActor
  func testCancelledGuardianLookupDoesNotCountAsLoaded() async {
    let auth = MockAuthManager()
    auth.setMockSession(Session(
      accessToken: "t", tokenType: "bearer", expiresIn: 3600,
      expiresAt: Int(Date().timeIntervalSince1970) + 3600, refreshToken: "r",
      user: User(id: "u1", email: "p@example.com", emailConfirmedAt: nil, fullName: "P",
                 createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z",
                 role: .player, dateOfBirth: nil)))
    auth.user = auth.session?.user
    let service = MockGuardianService()
    service.shouldThrowFetchStatusError = true
    service.mockErrorToThrow = URLError(.cancelled)
    let lookup = GuardianStatusViewModel(guardianService: service, authManager: auth)
    let task = Task { await lookup.refresh() }
    task.cancel()
    await task.value
    XCTAssertFalse(lookup.hasLoaded)
    XCTAssertFalse(EmailVerificationBannerViewModel(authManager: auth).isVisible(guardian: lookup))
  }
}
